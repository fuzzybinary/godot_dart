﻿#include "dart_bindings.h"

#include <functional>
#include <iostream>
#include <string.h>
#include <thread>

#include <dart_api.h>
#include <dart_dll.h>
#include <dart_tools_api.h>

#include <gdextension_interface.h>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/classes/editor_file_system.hpp>
#include <godot_cpp/classes/editor_interface.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/string_name.hpp>

#include "dart_helpers.h"
#include "dart_instance_binding.h"
#include "gde_dart_converters.h"
#include "gde_wrapper.h"
#include "ref_counted_wrapper.h"
#include "script/dart_script_instance.h"
#include "script/dart_script_language.h"

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

  // Capture the current isolate before it even exists
  _isolate_current_thread = std::this_thread::get_id();
  _isolate = DartDll_LoadScript(script_path, package_config);
  if (_isolate == nullptr) {
    GD_PRINT_ERROR("GodotDart: Initialization Error (Failed to load script)");
    _isolate_current_thread = std::thread::id();
    return false;
  }

  Dart_EnterIsolate(_isolate);
  {
    DartBlockScope scope;

    Dart_SetMessageNotifyCallback(dart_message_notify_callback);

    Dart_Handle godot_dart_package_name = Dart_NewStringFromCString("package:godot_dart/godot_dart.dart");
    DART_CHECK_RET(godot_dart_library, Dart_LookupLibrary(godot_dart_package_name), false,
                   "GodotDart: Initialization Error (Could not find the `godot_dart` "
                   "package)");
    _godot_dart_library = Dart_NewPersistentHandle(godot_dart_library);

    // Find the Engine classes library. This is needed to lookup engine types
    {
      Dart_Handle engine_classes_package_name =
          Dart_NewStringFromCString("package:godot_dart/src/gen/engine_classes.dart");
      DART_CHECK_RET(engine_classes_library, Dart_LookupLibrary(engine_classes_package_name), false,
                     "GodotDart: Initialization Error (Could not find the `engine_classes.dart` "
                     "package)");
      _engine_classes_library = Dart_NewPersistentHandle(engine_classes_library);
    }

    // Find the Variant / builting classes library. This is needed to lookup variant types
    {
      Dart_Handle builtin_classes_package_name =
          Dart_NewStringFromCString("package:godot_dart/src/gen/builtins.dart");
      DART_CHECK_RET(variant_library, Dart_LookupLibrary(builtin_classes_package_name), false,
                     "GodotDart: Initialization Error (Could not find the `builtins.dart` "
                     "package)");
      _variant_classes_library = Dart_NewPersistentHandle(variant_library);
    }

    // Find the DartBindings "library" (just the file) and set us as the native callback handler
    {
      Dart_Handle native_bindings_library_name =
          Dart_NewStringFromCString("package:godot_dart/src/core/godot_dart_native_bindings.dart");
      DART_CHECK_RET(library, Dart_LookupLibrary(native_bindings_library_name), false,
                     "Error finding godot_dart_native_bindings.dart");
      _native_library = Dart_NewPersistentHandle(library);
      Dart_SetNativeResolver(library, native_resolver, nullptr);
    }

    // Find the CoreTypes "library" (just the file) and set us as the native callback handler
    {
      Dart_Handle core_bindings_library_name = Dart_NewStringFromCString("package:godot_dart/src/core/core_types.dart");
      DART_CHECK_RET(library, Dart_LookupLibrary(core_bindings_library_name), false, "Error finding core_types.dart");
      Dart_SetNativeResolver(library, native_resolver, nullptr);
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

    {
      DART_CHECK_RET(core_library,
                     Dart_LookupLibrary(Dart_NewStringFromCString("package:godot_dart/src/variant/variant.dart")),
                     false, "Error getting variant library");
      DART_CHECK_RET(variant, Dart_GetNonNullableType(core_library, Dart_NewStringFromCString("Variant"), 0, nullptr),
                     false, "Error getting Variant type");
      _variant_type = Dart_NewPersistentHandle(variant);
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
        GD_PRINT_ERROR("GodotDart: Error setting print closure");
        GD_PRINT_ERROR(Dart_GetError(result));
      }
    }

    // Everything should be prepared, register Dart with Godot
    {
      GDEWrapper *wrapper = GDEWrapper::instance();
      Dart_Handle args[] = {
          Dart_NewInteger((int64_t)this),
          Dart_NewInteger(((int64_t)&DartGodotInstanceBinding::engine_binding_callbacks)),
      };
      DART_CHECK_RET(result, Dart_Invoke(godot_dart_library, Dart_NewStringFromCString("_registerGodot"), 2, args),
                     false, "Error calling '_registerGodot'");
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

  _fully_initialized = true;

  return true;
}

void GodotDartBindings::reload_code() {
  if (_is_reloading) {
    return;
  }

  _is_reloading = true;
  execute_on_dart_thread([&] {
    DartBlockScope scope;

    Dart_Handle godot_dart_library = Dart_HandleFromPersistent(_godot_dart_library);
    Dart_Handle result = Dart_Invoke(godot_dart_library, Dart_NewStringFromCString("_reloadCode"), 0, nullptr);
    if (Dart_IsError(result)) {
      GD_PRINT_WARNING("GodotDart: Error performing Dart hot reload:");
      GD_PRINT_WARNING(Dart_GetError(result));
    }
  });
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
  Dart_DeletePersistentHandle(_native_library);

  DartDll_DrainMicrotaskQueue();
  Dart_ExitScope();
  //Dart_ExitIsolate();

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

Dart_Handle GodotDartBindings::new_dart_void_pointer(const void *ptr) {
  Dart_Handle dart_int = Dart_NewIntegerFromUint64(reinterpret_cast<uint64_t>(ptr));
  Dart_Handle args[1] = {dart_int};

  return Dart_New(_void_pointer_pointer_type, Dart_NewStringFromCString("fromAddress"), 1, args);
}

void GodotDartBindings::perform_frame_maintanance() {
  if (!_fully_initialized) {
    // This can happen in the early moments of initialization where the DartScriptLanguage is ready
    // but the bindings aren't quite ready yet.
    return;
  }

  execute_on_dart_thread([&] {
    Dart_EnterScope();

    DartDll_DrainMicrotaskQueue();
    while (_pending_messages > 0) {
      DART_CHECK(err, Dart_HandleMessage(), "Failure handling dart message");
      _pending_messages--;
    }

    // Back with a current isolate, let's take care of any pending ref count changes,
    // which we couldn't do while the finalizer was running.
    perform_pending_ref_changes();

    // If we're reloading, check to see if we're done.
    if (_is_reloading) {
      Dart_Handle root_library = Dart_HandleFromPersistent(_godot_dart_library);
      DART_CHECK(dart_is_reloading, Dart_GetField(root_library, Dart_NewStringFromCString("_isReloading")),
                 "Failed to get _isReloading");
      Dart_BooleanValue(dart_is_reloading, &_is_reloading);
      if (!_is_reloading) {
        DartScriptLanguage::instance()->did_finish_hot_reload();
      }
    }

    uint64_t currentTime = Dart_TimelineGetMicros();
    Dart_NotifyIdle(currentTime + 1000); // Idle for 1 ms... maybe more

    Dart_ExitScope();
  });
}

void GodotDartBindings::add_pending_ref_change(DartGodotInstanceBinding *bindings) {
  _pending_ref_changes.insert(bindings);
}

void GodotDartBindings::remove_pending_ref_change(DartGodotInstanceBinding *binding) {
  _pending_ref_changes.erase(binding);
}

void GodotDartBindings::perform_pending_ref_changes() {
  for (auto binding : _pending_ref_changes) {
    RefCountedWrapper ref_counted(binding->get_godot_object());
    int ref_count = ref_counted.get_reference_count();
    if (ref_count > 1 && binding->is_weak()) {
      execute_on_dart_thread([&] { binding->convert_to_strong(); });
    } else if (ref_count == 1 && !binding->is_weak()) {
      execute_on_dart_thread([&] { binding->convert_to_weak(); });
    }
  }
  _pending_ref_changes.clear();
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
  for (intptr_t i = 0; i < args_length; ++i) {
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

  uint32_t flags = GDEXTENSION_METHOD_FLAG_NORMAL;
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

  godot::StringName gd_method_name(full_method_name.c_str());
  GDExtensionClassMethodInfo method_info = {
      gd_method_name._native_ptr(),
      info,
      GodotDartBindings::bind_call,
      GodotDartBindings::ptr_call,
      flags,
      ret_type_info.variant_type != GDEXTENSION_VARIANT_TYPE_NIL,
      &ret_info,
      GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE,
      static_cast<uint32_t>(args_length),
      arg_info,
      arg_meta_info,
      0,
      nullptr,
  };

  gde_classdb_register_extension_class_method(gde->get_library_ptr(), bind_type.type_name, &method_info);

  delete[] arg_info;
  delete[] arg_meta_info;
}

Dart_Handle GodotDartBindings::find_dart_type(Dart_Handle type_name) {
  DartBlockScope scope;

  uint8_t *c_type_name = nullptr;
  intptr_t length = 0;
  Dart_StringToUTF8(type_name, &c_type_name, &length);
  if (0 == strncmp(reinterpret_cast<const char *>(c_type_name), "Object", length)) {
    type_name = Dart_NewStringFromCString("GodotObject");
  }

  // Check engine classes first:
  DART_CHECK_RET(engine_classes_library, Dart_HandleFromPersistent(_engine_classes_library), Dart_Null(),
                 "Error getting engine class library.")

  Dart_Handle type = Dart_GetNonNullableType(engine_classes_library, type_name, 0, nullptr);
  if (!Dart_IsError(type)) {
    return type;
  }

  DART_CHECK_RET(variant_library, Dart_HandleFromPersistent(_variant_classes_library), Dart_Null(),
                 "Error getting variant library.")
  type = Dart_GetNonNullableType(variant_library, type_name, 0, nullptr);
  if (!Dart_IsError(type)) {
    return type;
  }

  GD_PRINT_ERROR("GodotDart: Could not find a needed type!");    

  return Dart_Null();
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
  godot::StringName gd_name = create_godot_string_name(name_prop);
  prop_info.name = gd_name._native_ptr();

  Dart_Handle class_name_prop = Dart_GetField(dart_type_info, Dart_NewStringFromCString("className"));
  void *gd_class_name = get_object_address(class_name_prop);
  prop_info.class_name = reinterpret_cast<GDExtensionStringNamePtr>(gd_class_name);

  {
    DART_CHECK(hint, Dart_GetField(dart_prop_info, Dart_NewStringFromCString("hint")), "Error getting hint property");
    DART_CHECK(enum_value, Dart_GetField(hint, Dart_NewStringFromCString("value")), "Error getting hint value");
    uint64_t hint_value;
    Dart_IntegerToUint64(enum_value, &hint_value);
    prop_info.hint = uint32_t(hint_value);
  }

  Dart_Handle hint_string_prop = Dart_GetField(dart_prop_info, Dart_NewStringFromCString("hintString"));
  godot::String gd_hint_string = create_godot_string(hint_string_prop);
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

  godot::StringName gd_getter(property_getter_name.c_str());
  godot::StringName gd_setter(property_setter_name.c_str());

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
      Dart_Handle variant_type = Dart_HandleFromPersistent(gde->_variant_type);
      Dart_Handle args[] = {result};
      Dart_Handle variant_result = Dart_New(variant_type, Dart_Null(), 1, args);
      if (Dart_IsError(variant_result)) {
        GD_PRINT_ERROR("GodotDart: Error converting return to variant: ");
        GD_PRINT_ERROR(Dart_GetError(variant_result));
      } else {
        void *variantDataPtr = get_object_address(variant_result);
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
    const godot::StringName *gd_name = reinterpret_cast<const godot::StringName *>(p_name);
    Dart_Handle dart_string = to_dart_string(*gd_name);

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

  __print_verbose(cstring);
}

void bind_class(Dart_NativeArguments args) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    Dart_ThrowException(Dart_NewStringFromCString("GodotDart has been shutdown!"));
    return;
  }

  Dart_Handle type_arg = Dart_GetNativeArgument(args, 1);

  Dart_Handle dstr_s_type_info = Dart_NewStringFromCString("sTypeInfo");
  Dart_Handle dstr_class_name = Dart_NewStringFromCString("className");
  DART_CHECK(type_info, Dart_GetField(type_arg, dstr_s_type_info), "Missing sTypeInfo when trying to bind class!");

  // className is a StringNames and we can get its opaque addresses
  Dart_Handle name = Dart_GetField(type_info, dstr_class_name);

  void *sn_name = get_object_address(name);
  if (sn_name == nullptr) {
    return;
  }

  Dart_Handle parent_type = Dart_GetField(type_info, Dart_NewStringFromCString("parentType"));
  if (Dart_IsNull(parent_type)) {
    Dart_ThrowException(Dart_NewStringFromCString("Passed null reference for parentType in bindClass."));
    return;
  }

  DART_CHECK(parent_type_info, Dart_GetField(parent_type, dstr_s_type_info), "Failed getting parentType typeInfo");
  DART_CHECK(parent_class_name, Dart_GetField(parent_type_info, dstr_class_name), "Failed getting parentType name");

  void *sn_parent = get_object_address(parent_class_name);
  if (sn_parent == nullptr) {
    return;
  }

  GDExtensionClassCreationInfo2 info = {0};
  info.is_exposed = true;
  info.class_userdata = (void *)Dart_NewPersistentHandle(type_arg);
  info.create_instance_func = GodotDartBindings::class_create_instance;
  info.free_instance_func = GodotDartBindings::class_free_instance;
  info.get_virtual_call_data_func = GodotDartBindings::get_virtual_call_data;
  info.call_virtual_with_data_func = GodotDartBindings::call_virtual_func;
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
  const godot::String *gd_string = reinterpret_cast<godot::String *>(get_object_address(dart_gd_string));

  Dart_Handle dart_string = to_dart_string(*gd_string);

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
  GDExtensionScriptInstanceDataPtr script_instance = gde_object_get_script_instance(
      reinterpret_cast<GDExtensionObjectPtr>(object_ptr), DartScriptLanguage::instance()->_owner);
  if (script_instance) {
    Dart_Handle obj = reinterpret_cast<DartScriptInstance *>(script_instance)->get_dart_object();
    Dart_SetReturnValue(args, obj);
    return;
  }

  DartGodotInstanceBinding *binding = (DartGodotInstanceBinding *)gde_object_get_instance_binding(
      reinterpret_cast<GDExtensionObjectPtr>(object_ptr), bindings,
      &DartGodotInstanceBinding::engine_binding_callbacks);
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

void attach_type_resolver(Dart_NativeArguments args) {
  DartScriptLanguage *script_language = DartScriptLanguage::instance();
  if (!script_language) {
    Dart_ThrowException(Dart_NewStringFromCString("GodotDart has been shutdown!"));
    return;
  }

  Dart_Handle resolver = Dart_GetNativeArgument(args, 1);
  script_language->attach_type_resolver(resolver);
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
  } else if (0 == strcmp(c_name, "GodotDartNativeBindings::attachTypeResolver")) {
    ret = attach_type_resolver;
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
  Dart_Handle parent_type = Dart_GetField(dart_type_info, Dart_NewStringFromCString("parentType"));
  Dart_Handle variant_type = Dart_GetField(dart_type_info, Dart_NewStringFromCString("variantType"));

  type_info->type_name = get_object_address(class_name);
  type_info->parent_type = parent_type;

  int64_t temp;
  Dart_IntegerToInt64(variant_type, &temp);
  type_info->variant_type = static_cast<GDExtensionVariantType>(temp);
  type_info->binding_callbacks = &DartGodotInstanceBinding::engine_binding_callbacks;

  Dart_ExitScope();
}

// C calls from Dart

extern "C" {

GDE_EXPORT void tie_dart_to_native(Dart_Handle dart_object, GDExtensionObjectPtr godot_object, bool is_refcounted,
                                   bool is_godot_defined) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
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
  DartGodotInstanceBinding *binding =
      (DartGodotInstanceBinding *)gde_object_get_instance_binding(godot_object, bindings, callbacks);
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

GDE_EXPORT GDExtensionScriptInstanceDataPtr get_script_instance(GDExtensionConstObjectPtr godot_object) {
  DartScriptLanguage *script_language = DartScriptLanguage::instance();
  if (script_language == nullptr) {
    return nullptr;
  }

  return gde_object_get_script_instance(godot_object, script_language->_owner);
}

void call_dart_signal(void* callable_userdata, const GDExtensionConstVariantPtr *p_args, GDExtensionInt p_argument_count, GDExtensionVariantPtr r_return, GDExtensionCallError *r_error) {
  GodotDartBindings *bindings = GodotDartBindings::instance();

  bindings->execute_on_dart_thread([&] {
    DartBlockScope scope;

    Dart_Handle signal = Dart_HandleFromPersistent((Dart_PersistentHandle)callable_userdata);
    // Create List<Variant> from the variants we're given
    Dart_Handle variant_type = Dart_HandleFromPersistent(bindings->_variant_type);
    Dart_Handle null_variant = Dart_New(variant_type, Dart_Null(), 0, nullptr);
    Dart_Handle signal_args = Dart_NewListOfTypeFilled(variant_type, null_variant, p_argument_count);
    {

      Dart_Handle variant_constructor_name = Dart_NewStringFromCString("fromVariantPtr");
      Dart_Handle args[] = {
        Dart_Null()
      };

      for(int i = 0; i < p_argument_count; ++i) {
        GDExtensionConstVariantPtr variant_ptr = p_args[i];
        args[0] = bindings->new_dart_void_pointer(variant_ptr);
        Dart_Handle variant_arg = Dart_New(variant_type, variant_constructor_name, 1, args);
        Dart_ListSetAt(signal_args, i, variant_arg);
      }
    }
    
    Dart_Handle args[] = {
      signal_args
    };
    Dart_Handle result = Dart_Invoke(signal, Dart_NewStringFromCString("call"), 1, args);
    if (Dart_IsError(result)) {
      GD_PRINT_ERROR("GodotDart: Error performing signal call: ");
      GD_PRINT_ERROR(Dart_GetError(result));
      *r_error = GDExtensionCallError{
        GDEXTENSION_CALL_ERROR_INVALID_METHOD,
        0, 0,
      };
    } else {
      *r_error = GDExtensionCallError{
        GDEXTENSION_CALL_OK, 0, 0
      };
    }
  });
}

GDExtensionInt get_signal_argument_count(void* callable_userdata, GDExtensionBool* r_is_valid) {
  GodotDartBindings *bindings = GodotDartBindings::instance();

  int64_t arg_count;
  bindings->execute_on_dart_thread([&] {
    DartBlockScope scope;
    Dart_Handle signal = Dart_HandleFromPersistent((Dart_PersistentHandle)callable_userdata);
    
    Dart_Handle arg_count_h = Dart_GetField(signal, Dart_NewStringFromCString("arguments"));
    Dart_IntegerToInt64(arg_count_h, &arg_count);
  });

  return arg_count;
}

void free_dart_signal(void* callable_userdata) {
  GodotDartBindings *bindings = GodotDartBindings::instance();

  bindings->execute_on_dart_thread([&] {
    DartBlockScope scope;

    Dart_Handle signal = Dart_HandleFromPersistent((Dart_PersistentHandle)callable_userdata);
    Dart_Invoke(signal, Dart_NewStringFromCString("clear"), 0, nullptr);    
    
    Dart_DeletePersistentHandle((Dart_PersistentHandle)callable_userdata);
  });
}

GDE_EXPORT Dart_Handle create_signal_callable(Dart_Handle signal_callable, GDObjectInstanceID target) {
  GDEWrapper *gde = GDEWrapper::instance();
  
  GDExtensionCallableCustomInfo2 info = {};
  info.callable_userdata = Dart_NewPersistentHandle(signal_callable);
  info.token = gde->get_library_ptr();
  info.object_id = target;
  info.call_func = call_dart_signal;  
  info.get_argument_count_func = get_signal_argument_count;

  godot::Callable callable;
  godot::internal::gdextension_interface_callable_custom_create2(callable._native_ptr(), &info);

  GodotDartBindings *bindings = GodotDartBindings::instance();
  DART_CHECK_RET(callable_type, bindings->find_dart_type(Dart_NewStringFromCString("Callable")), Dart_Null(), "Could not find Callable type!");

  Dart_Handle callable_opaque_ptr = bindings->new_dart_void_pointer(callable._native_ptr());
  Dart_Handle args[] {
    callable_opaque_ptr,
  };
  DART_CHECK_RET(dart_callable, Dart_New(callable_type, Dart_NewStringFromCString("copyPtr"), 1, args), Dart_Null(), "Could not create Dart Callable.");

  return dart_callable;
}

GDE_EXPORT void finalize_variant(GDExtensionVariantPtr variant) {
  if (variant == nullptr) {
    return;
  }

  gde_variant_destroy(variant);
  gde_mem_free(variant);
}

GDE_EXPORT void finalize_builtin_object(uint8_t *builtin_object_info) {
  if (builtin_object_info == nullptr) {
    return;
  }

  GDExtensionPtrDestructor *destructor = reinterpret_cast<GDExtensionPtrDestructor *>(builtin_object_info);
  void *opaque = builtin_object_info + sizeof(GDExtensionPtrDestructor);
  if (*destructor != nullptr) {
    (*destructor)(opaque);
  }
  gde_mem_free(builtin_object_info);
}

GDE_EXPORT void finalize_extension_object(GDExtensionObjectPtr extention_object) {
  if (extention_object == nullptr) {
    return;
  }

  gde_object_destroy(extention_object);
}

GDE_EXPORT Dart_Handle object_from_script_instance(DartScriptInstance *script_instance) {
  if (!script_instance) {
    return Dart_Null();
  }

  DART_CHECK_RET(dart_object, script_instance->get_dart_object(), Dart_Null(),
                 "Failed to get object from persistent handle");

  return dart_object;
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