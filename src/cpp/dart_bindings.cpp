#include "dart_bindings.h"

#include <functional>
#include <iostream>
#include <string.h>
#include <thread>

#include <dart_api.h>
#include <dart_dll.h>
#include <dart_tools_api.h>
#include <godot/gdextension_interface.h>

#include "dart_godot_binding.h"
#include "dart_helpers.h"
#include "dart_script_instance.h"
#include "gde_dart_converters.h"
#include "gde_wrapper.h"
#include "godot_string_wrappers.h"
#include "ref_counted_wrapper.h"

// Forward declarations for Dart callbacks and helpers
Dart_NativeFunction native_resolver(Dart_Handle name, int num_of_arguments, bool *auto_setup_scope);
void dart_message_notify_callback(Dart_Isolate isolate);
void type_info_from_dart(TypeInfo *type_info, Dart_Handle dart_type_info);

struct MethodInfo {
  std::string method_name;
  TypeInfo return_type;
  Dart_PersistentHandle args_list;
  MethodFlags method_flags;
};

GodotDartBindings *GodotDartBindings::_instance = nullptr;

GodotDartBindings::~GodotDartBindings() {
  _instance = nullptr;
}

bool GodotDartBindings::initialize(const char *script_path, const char *package_config) {
  DartDllConfig config;
  if (GDEWrapper::instance()->is_editor_hint()) {
    config.service_port = 6222;
  }
  DartDll_Initialize(config);

  _isolate = DartDll_LoadScript(script_path, package_config);
  if (_isolate == nullptr) {
    GD_PRINT_ERROR("GodotDart: Initialization Error (Failed to load script)");
    return false;
  }

  _isolate_current_thread = std::this_thread::get_id();
  Dart_EnterIsolate(_isolate);
  {
    DartBlockScope scope;

    Dart_SetMessageNotifyCallback(dart_message_notify_callback);

    Dart_Handle godot_dart_package_name = Dart_NewStringFromCString("package:godot_dart/godot_dart.dart");
    Dart_Handle godot_dart_library = Dart_LookupLibrary(godot_dart_package_name);
    if (Dart_IsError(godot_dart_library)) {
      GD_PRINT_ERROR("GodotDart: Initialization Error (Could not find the `godot_dart` "
                     "package)");
      return false;
    } else {
      _godot_dart_library = Dart_NewPersistentHandle(godot_dart_library);
    }

    // Find the DartBindings "library" (just the file) and set us as the native callback handler
    {
      Dart_Handle native_bindings_library_name =
          Dart_NewStringFromCString("package:godot_dart/src/core/godot_dart_native_bindings.dart");
      Dart_Handle library = Dart_LookupLibrary(native_bindings_library_name);
      if (!Dart_IsError(library)) {
        // Retrain for future calls to convert variants
        _native_library = Dart_NewPersistentHandle(library);
        Dart_SetNativeResolver(library, native_resolver, nullptr);
      }
    }

    // Find the DartBindings "library" (just the file) and set us as the native callback handler
    {
      Dart_Handle native_bindings_library_name =
          Dart_NewStringFromCString("package:godot_dart/src/core/core_types.dart");
      Dart_Handle library = Dart_LookupLibrary(native_bindings_library_name);
      if (!Dart_IsError(library)) {
        // Retrain for future calls to convert variants
        _core_types_library = Dart_NewPersistentHandle(library);
        Dart_SetNativeResolver(library, native_resolver, nullptr);
      }
    }

    // Setup some types we need frequently
    {
      DART_CHECK_RET(library, Dart_LookupLibrary(Dart_NewStringFromCString("dart:ffi")), false,
                     "Error getting ffi library");
      DART_CHECK_RET(dart_void, Dart_GetNonNullableType(library, Dart_NewStringFromCString("Void"), 0, nullptr), false,
                     "Error getting void type");
      DART_CHECK_RET(type_args, Dart_NewList(1), false, "Could not create arg list");

      Dart_ListSetAt(type_args, 0, dart_void);
      DART_CHECK_RET(void_pointer,
                     Dart_GetNonNullableType(library, Dart_NewStringFromCString("Pointer"), 1, &type_args), false,
                     "Error getting Pointer<Void> type");
      _void_pointer_type = Dart_NewPersistentHandle(void_pointer);

      Dart_Handle optional_void_pointer =
          Dart_GetNullableType(library, Dart_NewStringFromCString("Pointer"), 1, &type_args);
      if (Dart_IsError(void_pointer)) {
        GD_PRINT_ERROR("GodotDart: Error getting Pointer<Void>? type: ");
        GD_PRINT_ERROR(Dart_GetError(optional_void_pointer));

        return false;
      }
      _void_pointer_optional_type = Dart_NewPersistentHandle(optional_void_pointer);

      Dart_Handle type_args_2 = Dart_NewList(1);
      Dart_ListSetAt(type_args_2, 0, void_pointer);
      DART_CHECK_RET(pointer_to_pointer,
                     Dart_GetNonNullableType(library, Dart_NewStringFromCString("Pointer"), 1, &type_args_2), false,
                     "Error getting Pointer<Pointer<Void> type");
      _void_pointer_pointer_type = Dart_NewPersistentHandle(pointer_to_pointer);
    }

    // All set up, setup the instance
    _instance = this;

    // Replace Dart's print function to send info to Godot instead
    Dart_Handle url = Dart_NewStringFromCString("dart:_internal");
    Dart_Handle internal_lib = Dart_LookupLibrary(url);
    if (!Dart_IsError(internal_lib)) {
      Dart_Handle print = Dart_Invoke(godot_dart_library, Dart_NewStringFromCString("_getPrintClosure"), 0, NULL);
      Dart_Handle result = Dart_SetField(internal_lib, Dart_NewStringFromCString("_printClosure"), print);
      if (Dart_IsError(result)) {
        GD_PRINT_WARNING("GodotDart: Error setting print closure");
        GD_PRINT_WARNING(Dart_GetError(result));
      }
    }

    // Everything should be prepared, register Dart with Godot
    {
      GDEWrapper *wrapper = GDEWrapper::instance();
      Dart_Handle args[] = {
          Dart_NewInteger((int64_t)wrapper->get_library_ptr()),
          Dart_NewInteger(((int64_t)&DartGodotInstanceBinding::engine_binding_callbacks)),
      };
      DART_CHECK_RET(result, Dart_Invoke(godot_dart_library, Dart_NewStringFromCString("_registerGodot"), 2, args),
                     false, "Error calling '_registerGodot'");

      // Get the language pointer from the result:
      _dart_language = get_object_address(result);
    }

    // And call the main function from the user supplied library
    {
      Dart_Handle library = Dart_RootLibrary();
      Dart_Handle mainFunctionName = Dart_NewStringFromCString("main");
      DART_CHECK_RET(result, Dart_Invoke(library, mainFunctionName, 0, nullptr), false, "Error calling 'main'");
    }
  }

  Dart_ExitIsolate();
  _isolate_current_thread = std::thread::id();

  return true;
}

void GodotDartBindings::shutdown() {
  Dart_EnterIsolate(_isolate);
  _isolate_current_thread = std::this_thread::get_id();

  Dart_EnterScope();

  Dart_Handle godot_dart_library = Dart_HandleFromPersistent(_godot_dart_library);

  GDEWrapper *wrapper = GDEWrapper::instance();
  Dart_Handle result = Dart_Invoke(godot_dart_library, Dart_NewStringFromCString("_unregisterGodot"), 0, nullptr);
  if (Dart_IsError(result)) {
    GD_PRINT_ERROR("GodotDart: Error calling `_unregisterGodot`");
    GD_PRINT_ERROR(Dart_GetError(result));
  }

  Dart_DeletePersistentHandle(_godot_dart_library);
  Dart_DeletePersistentHandle(_core_types_library);
  Dart_DeletePersistentHandle(_native_library);

  DartDll_DrainMicrotaskQueue();
  Dart_ExitScope();
  //Dart_ExitIsolate();

  // Don't actually shut down. Godot still has some cleanup to do. 😡
  _is_stopping = true;
  Dart_ShutdownIsolate();
  DartDll_Shutdown();
  _instance = nullptr;
}

void GodotDartBindings::execute_on_dart_thread(std::function<void()> work) {
  std::thread::id current_thread_id = std::this_thread::get_id();
  if (_isolate_current_thread == current_thread_id) {
    work();
    return;
  }

  _work_lock.lock();
  _isolate_current_thread = std::this_thread::get_id();
  Dart_EnterIsolate(_isolate);
  work();

  Dart_ExitIsolate();
  _isolate_current_thread = std::thread::id();
  _work_lock.unlock();
}

Dart_Handle GodotDartBindings::new_dart_void_pointer(void *ptr) {
  Dart_Handle dart_int = Dart_NewIntegerFromUint64(reinterpret_cast<uint64_t>(ptr));
  Dart_Handle args[1] = {dart_int};

  return Dart_New(_void_pointer_pointer_type, Dart_NewStringFromCString("fromAddress"), 1, args);
}

void GodotDartBindings::bind_method(const TypeInfo &bind_type, const char *method_name, const TypeInfo &ret_type_info,
                                    Dart_Handle args_list, MethodFlags method_flags) {
  MethodInfo *info = new MethodInfo();
  info->method_name = method_name;
  info->return_type = ret_type_info;
  info->args_list = Dart_NewPersistentHandle(args_list);
  info->method_flags = method_flags;

  GDEWrapper *gde = GDEWrapper::instance();

  uint8_t gd_empty_string[GD_STRING_NAME_MAX_SIZE];
  gde_string_new_with_utf8_chars(&gd_empty_string, "");

  GDExtensionPropertyInfo ret_info = {
      ret_type_info.variant_type,
      ret_type_info.type_name,
      gd_empty_string,
      0, // Hint - String
      gd_empty_string,
      6, // Usage - PROPERTY_USAGE_DEFAULT,
  };

  // Parameters / Metadata
  intptr_t args_length = 0;
  Dart_ListLength(args_list, &args_length);

  GDExtensionPropertyInfo *arg_info = new GDExtensionPropertyInfo[args_length];
  GDExtensionClassMethodArgumentMetadata *arg_meta_info = new GDExtensionClassMethodArgumentMetadata[args_length];
  for (size_t i = 0; i < args_length; ++i) {
    Dart_Handle arg_type_info = Dart_ListGetAt(args_list, i);
    TypeInfo c_type_info;
    type_info_from_dart(&c_type_info, arg_type_info);
    arg_info[i].class_name = c_type_info.type_name;
    arg_info[i].hint = 0;
    arg_info[i].hint_string = gd_empty_string;
    arg_info[i].name = gd_empty_string;
    arg_info[i].usage = 6;

    // TODO - actually need this to specify int / double size
    arg_meta_info[i] = GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE;
  }

  int flags = GDEXTENSION_METHOD_FLAG_NORMAL;
  // TODO: Pass in virtual flag
  if (method_name[0] == '_') {
    flags |= GDEXTENSION_METHOD_FLAG_VIRTUAL;
  }

  // Add getter / setter prefix if needed
  std::string full_method_name(method_name);
  switch (method_flags) {
  case MethodFlags::None:
    break;
  case MethodFlags::PropertyGetter:
    full_method_name.insert(0, "get__");
    break;
  case MethodFlags::PropertySetter:
    full_method_name.insert(0, "set__");
    break;
  default:
    break;
  }

  GDStringName gd_method_name(full_method_name.c_str());
  GDExtensionClassMethodInfo method_info = {
      gd_method_name._native_ptr(),
      info,
      GodotDartBindings::bind_call,
      GodotDartBindings::ptr_call,
      flags,
      ret_type_info.variant_type != GDEXTENSION_VARIANT_TYPE_NIL,
      &ret_info,
      GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE,
      args_length,
      arg_info,
      arg_meta_info,
      0,
      nullptr,
  };

  gde_classdb_register_extension_class_method(gde->get_library_ptr(), bind_type.type_name, &method_info);

  delete[] arg_info;
  delete[] arg_meta_info;
}

void GodotDartBindings::add_property(const TypeInfo &bind_type, Dart_Handle dart_prop_info) {

  GDExtensionPropertyInfo prop_info = {};

  DART_CHECK(dart_type_info, Dart_GetField(dart_prop_info, Dart_NewStringFromCString("typeInfo")),
             "Error getting typeInfo property");
  DART_CHECK(dart_variant_value, Dart_GetField(dart_type_info, Dart_NewStringFromCString("variantType")),
             "Error getting variant type");

  int64_t type_value;
  Dart_IntegerToInt64(dart_variant_value, &type_value);
  prop_info.type = GDExtensionVariantType(type_value);

  Dart_Handle name_prop = Dart_GetField(dart_prop_info, Dart_NewStringFromCString("name"));
  GDStringName gd_name(name_prop);
  prop_info.name = gd_name._native_ptr();

  Dart_Handle class_name_prop = Dart_GetField(dart_type_info, Dart_NewStringFromCString("className"));
  void *gd_class_name = get_opaque_address(class_name_prop);
  prop_info.class_name = reinterpret_cast<GDExtensionStringNamePtr>(gd_class_name);

  {
    DART_CHECK(hint, Dart_GetField(dart_prop_info, Dart_NewStringFromCString("hint")), "Error getting hint property");
    DART_CHECK(enum_value, Dart_GetField(hint, Dart_NewStringFromCString("value")), "Error getting hint value");
    uint64_t hint_value;
    Dart_IntegerToUint64(enum_value, &hint_value);
    prop_info.hint = uint32_t(hint_value);
  }

  Dart_Handle hint_string_prop = Dart_GetField(dart_prop_info, Dart_NewStringFromCString("hintString"));
  GDString gd_hint_string(hint_string_prop);
  prop_info.hint_string = gd_hint_string._native_ptr();

  {
    DART_CHECK(dart_flags, Dart_GetField(dart_prop_info, Dart_NewStringFromCString("flags")),
               "Error getting flagsproperty");
    uint64_t flags;
    Dart_IntegerToUint64(dart_flags, &flags);
    prop_info.usage = uint32_t(flags);
  }

  TypeInfo property_type_info = {
      prop_info.class_name,
      nullptr,
      prop_info.type,
      nullptr,
  };

  const char *property_name = nullptr;
  Dart_StringToCString(name_prop, &property_name);

  Dart_Handle type_info_type = Dart_InstanceGetType(dart_type_info);
  Dart_Handle getter_args = Dart_NewListOfTypeFilled(type_info_type, Dart_Null(), 0);
  Dart_Handle setter_args = Dart_NewListOfTypeFilled(type_info_type, dart_type_info, 1);

  bind_method(bind_type, property_name, property_type_info, getter_args, MethodFlags::PropertyGetter);
  bind_method(bind_type, property_name, TypeInfo(), setter_args, MethodFlags::PropertySetter);

  std::string property_getter_name("get__");
  property_getter_name.append(property_name);
  std::string property_setter_name("set__");
  property_setter_name.append(property_name);

  GDStringName gd_getter(property_getter_name.c_str());
  GDStringName gd_setter(property_setter_name.c_str());

  GDEWrapper *gde = GDEWrapper::instance();
  gde_classdb_register_extension_class_property(gde->get_library_ptr(), bind_type.type_name, &prop_info,
                                                gd_setter._native_ptr(), gd_getter._native_ptr());
}

/* Static Callbacks from Godot */

void GodotDartBindings::bind_call(void *method_userdata, GDExtensionClassInstancePtr instance,
                                  const GDExtensionConstVariantPtr *args, GDExtensionInt argument_count,
                                  GDExtensionVariantPtr r_return, GDExtensionCallError *r_error) {
  GodotDartBindings *gde = GodotDartBindings::instance();
  if (!gde) {
    // oooff
    return;
  }
  gde->execute_on_dart_thread([&]() {
    DartBlockScope scope;

    DartGodotInstanceBinding *binding = reinterpret_cast<DartGodotInstanceBinding *>(instance);
    Dart_Handle dart_instance = binding->get_dart_object();

    MethodInfo *method_info = reinterpret_cast<MethodInfo *>(method_userdata);
    Dart_Handle dart_method_name = Dart_NewStringFromCString(method_info->method_name.c_str());

    Dart_Handle args_list = Dart_HandleFromPersistent(method_info->args_list);

    intptr_t arg_count = 0;
    Dart_ListLength(args_list, &arg_count);

    Dart_Handle *dart_args = nullptr;
    if (arg_count > 0) {
      dart_args = new Dart_Handle[arg_count];

      Dart_Handle args_address = Dart_NewInteger(reinterpret_cast<intptr_t>(args));
      Dart_Handle convert_args[3]{
          Dart_New(Dart_HandleFromPersistent(gde->_void_pointer_pointer_type), Dart_NewStringFromCString("fromAddress"),
                   1, &args_address),
          Dart_NewInteger(arg_count),
          args_list,
      };
      DART_CHECK(dart_converted_arg_list,
                 Dart_Invoke(gde->_native_library, Dart_NewStringFromCString("_variantsToDart"), 3, convert_args),
                 "Error converting parameters from Variants");

      for (intptr_t i = 0; i < arg_count; ++i) {
        dart_args[i] = Dart_ListGetAt(dart_converted_arg_list, i);
      }
    }

    Dart_Handle result = Dart_Null();
    if (method_info->method_flags == MethodFlags::None) {
      result = Dart_Invoke(dart_instance, dart_method_name, arg_count, dart_args);
      if (Dart_IsError(result)) {
        GD_PRINT_ERROR("GodotDart: Error calling function: ");
        GD_PRINT_ERROR(Dart_GetError(result));
      }
    } else if (method_info->method_flags == MethodFlags::PropertyGetter) {
      result = Dart_GetField(dart_instance, dart_method_name);
      if (Dart_IsError(result)) {
        GD_PRINT_ERROR("GodotDart: Error calling getter: ");
        GD_PRINT_ERROR(Dart_GetError(result));
      }
    } else if (method_info->method_flags == MethodFlags::PropertySetter) {
      result = Dart_SetField(dart_instance, dart_method_name, dart_args[0]);
      if (Dart_IsError(result)) {
        GD_PRINT_ERROR("GodotDart: Error calling setter: ");
        GD_PRINT_ERROR(Dart_GetError(result));
      }
    }

    if (!Dart_IsError(result)) {
      // Call back into Dart to convert to Variant. This may get moved back into C at some point but
      // the logic and type checking is easier in Dart.
      Dart_Handle native_library = Dart_HandleFromPersistent(gde->_native_library);
      Dart_Handle args[] = {result};
      Dart_Handle variant_result = Dart_Invoke(native_library, Dart_NewStringFromCString("_convertToVariant"), 1, args);
      if (Dart_IsError(variant_result)) {
        GD_PRINT_ERROR("GodotDart: Error converting return to variant: ");
        GD_PRINT_ERROR(Dart_GetError(result));
      } else {
        void *variantDataPtr = get_opaque_address(variant_result);
        if (variantDataPtr) {
          gde_variant_new_copy(r_return, reinterpret_cast<GDExtensionConstVariantPtr>(variantDataPtr));
        }
      }
    }

    if (dart_args != nullptr) {
      delete[] dart_args;
    }
  });
}

void GodotDartBindings::ptr_call(void *method_userdata, GDExtensionClassInstancePtr instance,
                                 const GDExtensionConstVariantPtr *args, GDExtensionVariantPtr r_return) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    // oooff
    return;
  }

  bindings->execute_on_dart_thread([&]() {
    Dart_EnterScope();

    assert(false);

    Dart_ExitScope();
  });
}

GDExtensionObjectPtr GodotDartBindings::class_create_instance(void *p_userdata) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    // oooff
    return nullptr;
  }

  uint64_t real_address = 0;
  bindings->execute_on_dart_thread([&]() {
    DartBlockScope scope;

    Dart_Handle type = Dart_HandleFromPersistent(reinterpret_cast<Dart_PersistentHandle>(p_userdata));

    DART_CHECK(d_class_type_info, Dart_GetField(type, Dart_NewStringFromCString("sTypeInfo")),
               "Error finding typeInfo on object");
    TypeInfo class_type_info;
    type_info_from_dart(&class_type_info, d_class_type_info);

    DART_CHECK(new_object, Dart_New(type, Dart_Null(), 0, nullptr), "Error creating object");
    DART_CHECK(owner, Dart_GetField(new_object, Dart_NewStringFromCString("nativePtr")),
               "Error finding owner member for object");
    DART_CHECK(owner_address, Dart_GetField(owner, Dart_NewStringFromCString("address")),
               "Error getting address for object");

    Dart_IntegerToUint64(owner_address, &real_address);
  });

  return reinterpret_cast<GDExtensionObjectPtr>(real_address);
}

void GodotDartBindings::class_free_instance(void *p_userdata, GDExtensionClassInstancePtr p_instance) {
  // Instance is properly freed by engine binding callbacks
}

void *GodotDartBindings::get_virtual_call_data(void *p_userdata, GDExtensionConstStringNamePtr p_name) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    // oooff
    return nullptr;
  }

  void *user_data = nullptr;
  bindings->execute_on_dart_thread([&]() {
    DartBlockScope scope;

    Dart_Handle type = Dart_HandleFromPersistent(reinterpret_cast<Dart_PersistentHandle>(p_userdata));

    DART_CHECK(typeInfo, Dart_GetField(type, Dart_NewStringFromCString("sTypeInfo")),
               "Error finding sTypeInfo on Type");
    DART_CHECK(vtable, Dart_GetField(typeInfo, Dart_NewStringFromCString("vTable")),
               "Error finding vTable from TypeInfo");
    if (Dart_IsNull(vtable)) {
      return;
    }

    // TODO: Maybe we can use StringNames directly instead of converting to Dart strings?
    const GDStringName *gd_name = reinterpret_cast<const GDStringName *>(p_name);
    Dart_Handle dart_string = gd_name->to_dart();

    DART_CHECK(vtable_item, Dart_MapGetAt(vtable, dart_string), "Error looking up vtable item");
    if (Dart_IsNull(vtable_item)) {
      return;
    }

    Dart_Handle dart_address = Dart_GetField(vtable_item, Dart_NewStringFromCString("address"));

    uint64_t address = 0;
    Dart_IntegerToUint64(dart_address, &address);

    user_data = (void *)address;
  });

  return user_data;
}

void GodotDartBindings::call_virtual_func(void *p_instance, GDExtensionConstStringNamePtr p_name, void *p_userdata,
                                          const GDExtensionConstTypePtr *p_args, GDExtensionTypePtr r_ret) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    // oooff
    return;
  }

  bindings->execute_on_dart_thread([&]() {
    DartBlockScope scope;

    GDExtensionClassCallVirtual dart_call = (GDExtensionClassCallVirtual)p_userdata;
    dart_call(p_instance, p_args, r_ret);
  });
}

/* Static Functions From Dart */

void dart_print(Dart_NativeArguments args) {
  const char *cstring;
  Dart_Handle arg = Dart_GetNativeArgument(args, 1);
  DART_CHECK(result, Dart_StringToCString(arg, &cstring), "Error getting printable string.");

  // TODO - Find a nice way to log
  GD_PRINT_WARNING(cstring);
}

void bind_class(Dart_NativeArguments args) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    Dart_ThrowException(Dart_NewStringFromCString("GodotDart has been shutdown!"));
    return;
  }

  Dart_Handle type_arg = Dart_GetNativeArgument(args, 1);

  DART_CHECK(type_info, Dart_GetField(type_arg, Dart_NewStringFromCString("sTypeInfo")),
             "Missing sTypeInfo when trying to bind class!");

  // Name and Parent are StringNames and we can get their opaque addresses
  Dart_Handle name = Dart_GetField(type_info, Dart_NewStringFromCString("className"));
  Dart_Handle parent = Dart_GetField(type_info, Dart_NewStringFromCString("parentClass"));
  if (Dart_IsNull(parent)) {
    Dart_ThrowException(Dart_NewStringFromCString("Passed null reference for parent in bindClass."));
    return;
  }

  void *sn_name = get_opaque_address(name);
  if (sn_name == nullptr) {
    return;
  }
  void *sn_parent = get_opaque_address(parent);
  if (sn_parent == nullptr) {
    return;
  }

  GDExtensionClassCreationInfo2 info = {0};
  info.is_exposed = true;
  info.class_userdata = (void *)Dart_NewPersistentHandle(type_arg);
  info.create_instance_func = GodotDartBindings::class_create_instance;
  info.free_instance_func = GodotDartBindings::class_free_instance;
  info.get_virtual_call_data_func = GodotDartBindings::get_virtual_call_data;
  info.call_virtual_func = GodotDartBindings::call_virtual_func;
  //info.reference_func = GodotDartBindings::reference;
  //info.unreference_func = GodotDartBindings::unreference;

  gde_classdb_register_extension_class2(GDEWrapper::instance()->get_library_ptr(), sn_name, sn_parent, &info);
}

void bind_method(Dart_NativeArguments args) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    Dart_ThrowException(Dart_NewStringFromCString("GodotDart has been shutdown!"));
    return;
  }

  Dart_Handle d_bind_type_info = Dart_GetNativeArgument(args, 1);

  const char *method_name = nullptr;
  Dart_StringToCString(Dart_GetNativeArgument(args, 2), &method_name);

  Dart_Handle d_return_type_info = Dart_GetNativeArgument(args, 3);
  Dart_Handle d_argument_list = Dart_GetNativeArgument(args, 4);

  TypeInfo bind_type_info;
  type_info_from_dart(&bind_type_info, d_bind_type_info);

  TypeInfo return_type_info;
  type_info_from_dart(&return_type_info, d_return_type_info);

  bindings->bind_method(bind_type_info, method_name, return_type_info, d_argument_list, MethodFlags::None);
}

void add_property(Dart_NativeArguments args) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    Dart_ThrowException(Dart_NewStringFromCString("GodotDart has been shutdown!"));
    return;
  }

  Dart_Handle d_bind_type_info = Dart_GetNativeArgument(args, 1);
  TypeInfo bind_type_info;
  type_info_from_dart(&bind_type_info, d_bind_type_info);

  Dart_Handle property_info = Dart_GetNativeArgument(args, 2);

  bindings->add_property(bind_type_info, property_info);
}

void gd_string_to_dart_string(Dart_NativeArguments args) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    Dart_ThrowException(Dart_NewStringFromCString("GodotDart has been shutdown!"));
    return;
  }

  Dart_Handle dart_gd_string = Dart_GetNativeArgument(args, 1);
  const GDString *gd_string = reinterpret_cast<GDString *>(get_opaque_address(dart_gd_string));

  Dart_Handle dart_string = gd_string->to_dart();

  Dart_SetReturnValue(args, dart_string);
}

void gd_object_to_dart_object(Dart_NativeArguments args) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    Dart_ThrowException(Dart_NewStringFromCString("GodotDart has been shutdown!"));
    return;
  }

  Dart_Handle dart_gd_object = Dart_GetNativeArgument(args, 1);
  Dart_Handle address = Dart_GetField(dart_gd_object, Dart_NewStringFromCString("address"));
  if (Dart_IsError(address)) {
    GD_PRINT_ERROR(Dart_GetError(address));
    Dart_ThrowException(Dart_NewStringFromCString(Dart_GetError(address)));
    return;
  }
  uint64_t object_ptr = 0;
  Dart_IntegerToUint64(address, &object_ptr);
  if (object_ptr == 0) {
    Dart_SetReturnValue(args, Dart_Null());
    return;
  }

  GDEWrapper *gde = GDEWrapper::instance();
  // Defaults for non-engine classes
  void *token = gde->get_library_ptr();
  const GDExtensionInstanceBindingCallbacks *bindings_callbacks = &DartGodotInstanceBinding::engine_binding_callbacks;

  Dart_Handle bindings_token = Dart_GetNativeArgument(args, 2);
  if (!Dart_IsNull(bindings_token)) {
    address = Dart_GetField(bindings_token, Dart_NewStringFromCString("address"));
    if (Dart_IsError(address)) {
      GD_PRINT_ERROR(Dart_GetError(address));
      Dart_ThrowException(Dart_NewStringFromCString(Dart_GetError(address)));
      return;
    }
    uint64_t token_int = 0;
    Dart_IntegerToUint64(address, &token_int);
    token = (void *)token_int;
    bindings_callbacks = &DartGodotInstanceBinding::engine_binding_callbacks;
  }

  DartGodotInstanceBinding *binding = (DartGodotInstanceBinding *)gde_object_get_instance_binding(
      reinterpret_cast<GDExtensionObjectPtr>(object_ptr), token, bindings_callbacks);
  if (binding == nullptr) {
    Dart_SetReturnValue(args, Dart_Null());
  } else {
    Dart_Handle obj = binding->get_dart_object();
    if (Dart_IsError(obj)) {
      GD_PRINT_ERROR(Dart_GetError(obj));
      Dart_ThrowException(Dart_NewStringFromCString(Dart_GetError(obj)));
      return;
    }
    Dart_SetReturnValue(args, obj);
  }
}

void get_godot_type_info(Dart_NativeArguments args) {
  Dart_Handle dart_type = Dart_GetNativeArgument(args, 1);
  Dart_Handle type_info = Dart_GetField(dart_type, Dart_NewStringFromCString("sTypeInfo"));
  if (Dart_IsError(type_info)) {
    GD_PRINT_ERROR(Dart_GetError(type_info));
    Dart_ThrowException(Dart_NewStringFromCString(Dart_GetError(type_info)));
    return;
  }

  Dart_SetReturnValue(args, type_info);
}

void get_godot_script_info(Dart_NativeArguments args) {
  Dart_Handle dart_type = Dart_GetNativeArgument(args, 1);
  Dart_Handle type_info = Dart_GetField(dart_type, Dart_NewStringFromCString("sTypeInfo"));
  Dart_Handle script_info = Dart_GetField(type_info, Dart_NewStringFromCString("scriptInfo"));
  if (Dart_IsError(script_info)) {
    GD_PRINT_ERROR(Dart_GetError(script_info));
    Dart_ThrowException(Dart_NewStringFromCString(Dart_GetError(script_info)));
    return;
  }

  Dart_SetReturnValue(args, script_info);
}

Dart_NativeFunction native_resolver(Dart_Handle name, int num_of_arguments, bool *auto_setup_scope) {
  Dart_EnterScope();

  const char *c_name = nullptr;
  Dart_StringToCString(name, &c_name);

  Dart_NativeFunction ret = nullptr;

  if (0 == strcmp(c_name, "GodotDartNativeBindings::print")) {
    *auto_setup_scope = true;
    ret = dart_print;
  } else if (0 == strcmp(c_name, "GodotDartNativeBindings::bindMethod")) {
    *auto_setup_scope = true;
    ret = bind_method;
  } else if (0 == strcmp(c_name, "GodotDartNativeBindings::bindClass")) {
    *auto_setup_scope = true;
    ret = bind_class;
  } else if (0 == strcmp(c_name, "GodotDartNativeBindings::addProperty")) {
    ret = add_property;
  } else if (0 == strcmp(c_name, "GodotDartNativeBindings::gdStringToString")) {
    *auto_setup_scope = true;
    ret = gd_string_to_dart_string;
  } else if (0 == strcmp(c_name, "GodotDartNativeBindings::gdObjectToDartObject")) {
    *auto_setup_scope = true;
    ret = gd_object_to_dart_object;
  } else if (0 == strcmp(c_name, "GodotDartNativeBindings::getGodotTypeInfo")) {
    *auto_setup_scope = true;
    ret = get_godot_type_info;
  } else if (0 == strcmp(c_name, "GodotDartNativeBindings::getGodotScriptInfo")) {
    *auto_setup_scope = true;
    ret = get_godot_script_info;
  }

  Dart_ExitScope();
  return ret;
}

void dart_message_notify_callback(Dart_Isolate isolate) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    return;
  }

  // TODO: Does this need to be thread safe?
  bindings->_pending_messages++;
}

void type_info_from_dart(TypeInfo *type_info, Dart_Handle dart_type_info) {
  Dart_EnterScope();

  Dart_Handle class_name = Dart_GetField(dart_type_info, Dart_NewStringFromCString("className"));
  Dart_Handle parent_class = Dart_GetField(dart_type_info, Dart_NewStringFromCString("parentClass"));
  Dart_Handle variant_type = Dart_GetField(dart_type_info, Dart_NewStringFromCString("variantType"));
  Dart_Handle binding_token = Dart_GetField(dart_type_info, Dart_NewStringFromCString("bindingToken"));

  type_info->type_name = get_opaque_address(class_name);
  if (Dart_IsNull(parent_class)) {
    type_info->parent_name = nullptr;
  } else {
    type_info->parent_name = get_opaque_address(parent_class);
  }
  int64_t temp;
  Dart_IntegerToInt64(variant_type, &temp);
  type_info->variant_type = static_cast<GDExtensionVariantType>(temp);
  if (Dart_IsNull(binding_token)) {
    type_info->binding_token = nullptr;
    type_info->binding_callbacks = nullptr;
  } else {
    Dart_Handle dart_address = Dart_GetField(binding_token, Dart_NewStringFromCString("address"));

    uint64_t address = 0;
    Dart_IntegerToUint64(dart_address, &address);

    type_info->binding_token = (void *)address;
    type_info->binding_callbacks = &DartGodotInstanceBinding::engine_binding_callbacks;
  }

  Dart_ExitScope();
}

// C calls from Dart

extern "C" {

GDE_EXPORT void tie_dart_to_native(Dart_Handle dart_object, GDExtensionObjectPtr godot_object, bool is_refcounted,
                                   bool is_godot_defined) {
  DartBlockScope scope;

  Dart_Handle d_class_type_info = Dart_GetField(dart_object, Dart_NewStringFromCString("typeInfo"));
  if (Dart_IsError(d_class_type_info)) {
    GD_PRINT_ERROR("GodotDart: Error finding typeInfo on object: ");
    GD_PRINT_ERROR(Dart_GetError(d_class_type_info));
    return;
  }

  TypeInfo class_type_info;
  type_info_from_dart(&class_type_info, d_class_type_info);

  const GDExtensionInstanceBindingCallbacks *callbacks = &DartGodotInstanceBinding::engine_binding_callbacks;
  DartGodotInstanceBinding *binding = (DartGodotInstanceBinding *)gde_object_get_instance_binding(
      godot_object, class_type_info.binding_token, callbacks);
  if (!binding->is_initialized()) {
    binding->initialize(dart_object, is_refcounted);
  }

  if (!is_godot_defined) {
    gde_object_set_instance(godot_object, class_type_info.type_name, binding);
  }
}

GDE_EXPORT Dart_Handle dart_object_from_instance_binding(GDExtensionClassInstancePtr godot_instance) {
  DartGodotInstanceBinding *binding = reinterpret_cast<DartGodotInstanceBinding *>(godot_instance);
  Dart_Handle obj = Dart_Null();
  if (binding != nullptr) {
    obj = binding->get_dart_object();
  }

  return obj;
}

GDE_EXPORT void variant_copy(void *dest, void *src, int size) {
  memcpy(dest, src, size);
}

GDE_EXPORT void finalize_extension_object(GDExtensionObjectPtr extention_object) {
  if (extention_object == nullptr) {
    return;
  }

  gde_object_destroy(extention_object);
}

GDE_EXPORT void *create_script_instance(Dart_Handle type, Dart_Handle script, void *godot_object, bool is_placeholder, bool is_refcounted) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings || godot_object == nullptr) {
    return nullptr;
  }

  Dart_Handle dart_pointer = bindings->new_dart_void_pointer(godot_object);
  Dart_Handle args[1] = {dart_pointer};
  DART_CHECK_RET(dart_object, Dart_New(type, Dart_NewStringFromCString("withNonNullOwner"), 1, args), nullptr,
                 "Error creating bindings");

  DartScriptInstance *script_instance =
      new DartScriptInstance(dart_object, script, godot_object, is_placeholder, is_refcounted);
  GDExtensionScriptInstancePtr godot_script_instance =
      gde_script_instance_create2(DartScriptInstance::get_script_instance_info(),
                                  reinterpret_cast<GDExtensionScriptInstanceDataPtr>(script_instance));

  return godot_script_instance;
}

GDE_EXPORT Dart_Handle object_from_script_instance(DartScriptInstance *script_instance) {
  if (!script_instance) {
    return Dart_Null();
  }

  DART_CHECK_RET(dart_object, script_instance->get_dart_object(), Dart_Null(),
                 "Failed to get object from persistent handle");

  return dart_object;
}

GDE_EXPORT void perform_frame_maintenance() {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    return;
  }
  Dart_EnterScope();

  uint64_t currentTime = Dart_TimelineGetMicros();
  Dart_NotifyIdle(currentTime + 1000); // Idle for 1 ms... maybe more

  DartDll_DrainMicrotaskQueue();
  while (bindings->_pending_messages > 0) {
    DART_CHECK(err, Dart_HandleMessage(), "Failure handling dart message");
    bindings->_pending_messages--;
  }

  Dart_ExitScope();
}

GDE_EXPORT void *safe_new_persistent_handle(Dart_Handle handle) {
  Dart_EnterScope();

  if (Dart_IsNull(handle)) {
    GD_PRINT_ERROR("GodotDart: `null` is not a valid value to pass to newPersistentHandle!");
    Dart_ExitScope();
    return nullptr;
  }

  Dart_PersistentHandle result = Dart_NewPersistentHandle(handle);
  if (Dart_IsError(result)) {
    GD_PRINT_ERROR("GodotDart: Error calling `Dart_WaitForEvent`");
    GD_PRINT_ERROR(Dart_GetError(result));
    Dart_ExitScope();
    return nullptr;
  }

  Dart_ExitScope();

  return (void *)result;
}
}