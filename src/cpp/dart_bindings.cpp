#include "dart_bindings.h"

#include <functional>
#include <iostream>
#include <string.h>
#include <thread>

#include <dart_api.h>
#include <dart_dll.h>
#include <dart_tools_api.h>

#include <gdextension_interface.h>
#include <godot_cpp/classes/editor_file_system.hpp>
#include <godot_cpp/classes/editor_interface.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/string_name.hpp>

#include "dart_helpers.h"
#include "dart_instance_binding.h"
#include "gde_dart_converters.h"
#include "gde_wrapper.h"
#include "ref_counted_wrapper.h"
#include "script/dart_script_instance.h"
#include "script/dart_script_language.h"

void dart_message_notify_callback(Dart_Isolate isolate);

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

    Dart_Handle godot_native_package_name =
        Dart_NewStringFromCString("package:godot_dart/src/core/godot_dart_native_bridge.dart");
    DART_CHECK_RET(godot_native_library, Dart_LookupLibrary(godot_native_package_name), false,
                   "Could not find godot_dart_native_bridge.dart");
    _native_library = Dart_NewPersistentHandle(godot_native_library);

    // Setup some types we need frequently
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
      };
      DART_CHECK_RET(result, Dart_Invoke(godot_dart_library, Dart_NewStringFromCString("_registerGodot"), 1, args),
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

  Dart_DeletePersistentHandle(_native_library);
  Dart_DeletePersistentHandle(_godot_dart_library);

  DartDll_DrainMicrotaskQueue();
  Dart_ExitScope();
  //Dart_ExitIsolate();

  _is_stopping = true;
  Dart_ShutdownIsolate();
  DartDll_Shutdown();
  _instance = nullptr;
}

void GodotDartBindings::set_type_resolver(Dart_Handle type_resolver) {
  _type_resolver = Dart_NewPersistentHandle(type_resolver);
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

void GodotDartBindings::bind_method(Dart_Handle dart_type_info, Dart_Handle dart_method_info) {
  DartBlockScope scope;

  GDEWrapper *gde = GDEWrapper::instance();

  // Class name
  DART_CHECK(dart_class_name, Dart_GetField(dart_type_info, Dart_NewStringFromCString("className")),
             "Failed to get className from TypeInfo");
  godot::StringName class_name = *(godot::StringName *)get_object_address(dart_class_name);

  GDExtensionClassMethodInfo method_info;
  method_info.call_func = GodotDartBindings::bind_call;
  method_info.ptrcall_func = GodotDartBindings::ptr_call;
  method_info.method_flags = GDEXTENSION_METHOD_FLAGS_DEFAULT; // TODO:
  method_info.method_userdata = Dart_NewPersistentHandle(dart_method_info);

  // Method name
  DART_CHECK(dart_method_name, Dart_GetField(dart_method_info, Dart_NewStringFromCString("name")),
             "Failed to get method name");
  godot::StringName gd_method_name = create_godot_string_name(dart_method_name);
  method_info.name = gd_method_name._native_ptr();

  // Return info
  DART_CHECK(dart_ret_info, Dart_GetField(dart_method_info, Dart_NewStringFromCString("returnInfo")),
             "Failed to get returnInfo");
  GDExtensionPropertyInfo ret_info;
  gde_property_info_from_dart(dart_ret_info, &ret_info);
  method_info.has_return_value = !Dart_IsNull(dart_ret_info);
  method_info.return_value_info = &ret_info;
  method_info.return_value_metadata = GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE;

  // Parameters / Metadata
  DART_CHECK(dart_arg_list, Dart_GetField(dart_method_info, Dart_NewStringFromCString("args")),
             "Failed to get args from MethodInfo");

  int arg_count = gde_arg_list_from_dart(dart_arg_list, &method_info.arguments_info, &method_info.arguments_metadata);
  method_info.argument_count = arg_count;

  uint32_t flags = GDEXTENSION_METHOD_FLAG_NORMAL;

  // TODO: Default Arguments
  method_info.default_arguments = nullptr;
  method_info.default_argument_count = 0;

  // TODO: Pass in virtual flag
  //if (method_name[0] == '_') {
  //  flags |= GDEXTENSION_METHOD_FLAG_VIRTUAL;
  //}

  //// Add getter / setter prefix if needed
  //std::string full_method_name(method_name);
  //switch (method_flags) {
  //case MethodFlags::None:
  //  break;
  //case MethodFlags::PropertyGetter:
  //  full_method_name.insert(0, "get__");
  //  break;
  //case MethodFlags::PropertySetter:
  //  full_method_name.insert(0, "set__");
  //  break;
  //default:
  //  break;
  //}

  gde_classdb_register_extension_class_method(gde->get_library_ptr(), class_name._native_ptr(), &method_info);

  gde_free_arg_list(method_info.arguments_info, arg_count);
  delete[] method_info.arguments_metadata;
}

Dart_Handle GodotDartBindings::get_dart_type_info(Dart_Handle type_name) {
  DART_CHECK_RET(type_resolver, Dart_HandleFromPersistent(_type_resolver), Dart_Null(), "Failed to get type resolver");

  Dart_Handle args[] = {
      type_name,
  };

  DART_CHECK_RET(type_info, Dart_Invoke(type_resolver, Dart_NewStringFromCString("getTypeInfoByName"), 1, args),
                 Dart_Null(), "Failed to get type info for type name");

  return type_info;
}

Dart_Handle GodotDartBindings::new_dart_object(Dart_Handle type_name) {
  DART_CHECK_RET(type_resolver, Dart_HandleFromPersistent(_type_resolver), Dart_Null(), "Failed to get type resolver");

  Dart_Handle args[] = {
      type_name,
  };

  DART_CHECK_RET(dart_object, Dart_Invoke(type_resolver, Dart_NewStringFromCString("constructObjectDefault"), 1, args),
                 Dart_Null(), "Failed to construct object");

  return dart_object;
}

Dart_Handle GodotDartBindings::new_godot_owned_object(Dart_Handle type, void *ptr) {
  DART_CHECK_RET(type_resolver, Dart_HandleFromPersistent(_type_resolver), Dart_Null(), "Failed to get type resolver");

  Dart_Handle args[] = {type, Dart_NewInteger(int64_t(ptr))};

  DART_CHECK_RET(dart_object,
                 Dart_Invoke(type_resolver, Dart_NewStringFromCString("constructFromGodotObject"), 2, args),
                 Dart_Null(), "Failed to construct object");

  return dart_object;
}

Dart_Handle GodotDartBindings::new_object_copy(Dart_Handle type_name, GDExtensionConstObjectPtr ptr) {
  DART_CHECK_RET(type_resolver, Dart_HandleFromPersistent(_type_resolver), Dart_Null(), "Failed to get type resolver");

  Dart_Handle args[] = {type_name, Dart_NewInteger(int64_t(ptr))};

  DART_CHECK_RET(dart_object, Dart_Invoke(type_resolver, Dart_NewStringFromCString("constructObjectCopy"), 2, args),
                 Dart_Null(), "Failed to construct object");

  return dart_object;
}

//void GodotDartBindings::add_property(Dart_Handle bind_type, Dart_Handle dart_prop_info) {
//
//  GDExtensionPropertyInfo prop_info = {};
//
//  DART_CHECK(dart_type_info, Dart_GetField(dart_prop_info, Dart_NewStringFromCString("typeInfo")),
//             "Error getting typeInfo property");
//  DART_CHECK(dart_variant_value, Dart_GetField(dart_type_info, Dart_NewStringFromCString("variantType")),
//             "Error getting variant type");
//
//  int64_t type_value;
//  Dart_IntegerToInt64(dart_variant_value, &type_value);
//  prop_info.type = GDExtensionVariantType(type_value);
//
//  Dart_Handle name_prop = Dart_GetField(dart_prop_info, Dart_NewStringFromCString("name"));
//  godot::StringName gd_name = create_godot_string_name(name_prop);
//  prop_info.name = gd_name._native_ptr();
//
//  Dart_Handle class_name_prop = Dart_GetField(dart_type_info, Dart_NewStringFromCString("className"));
//  void *gd_class_name = get_object_address(class_name_prop);
//  prop_info.class_name = reinterpret_cast<GDExtensionStringNamePtr>(gd_class_name);
//
//  {
//    DART_CHECK(hint, Dart_GetField(dart_prop_info, Dart_NewStringFromCString("hint")), "Error getting hint property");
//    DART_CHECK(enum_value, Dart_GetField(hint, Dart_NewStringFromCString("value")), "Error getting hint value");
//    uint64_t hint_value;
//    Dart_IntegerToUint64(enum_value, &hint_value);
//    prop_info.hint = uint32_t(hint_value);
//  }
//
//  Dart_Handle hint_string_prop = Dart_GetField(dart_prop_info, Dart_NewStringFromCString("hintString"));
//  godot::String gd_hint_string = create_godot_string(hint_string_prop);
//  prop_info.hint_string = gd_hint_string._native_ptr();
//
//  {
//    DART_CHECK(dart_flags, Dart_GetField(dart_prop_info, Dart_NewStringFromCString("flags")),
//               "Error getting flagsproperty");
//    uint64_t flags;
//    Dart_IntegerToUint64(dart_flags, &flags);
//    prop_info.usage = uint32_t(flags);
//  }
//
//  TypeInfo property_type_info = {
//      prop_info.class_name,
//      nullptr,
//      prop_info.type,
//      nullptr,
//  };
//
//  const char *property_name = nullptr;
//  Dart_StringToCString(name_prop, &property_name);
//
//  Dart_Handle type_info_type = Dart_InstanceGetType(dart_type_info);
//  Dart_Handle getter_args = Dart_NewListOfTypeFilled(type_info_type, Dart_Null(), 0);
//  Dart_Handle setter_args = Dart_NewListOfTypeFilled(type_info_type, dart_type_info, 1);
//
//  bind_method(bind_type, property_name, property_type_info, getter_args, MethodFlags::PropertyGetter);
//  bind_method(bind_type, property_name, TypeInfo(), setter_args, MethodFlags::PropertySetter);
//
//  std::string property_getter_name("get__");
//  property_getter_name.append(property_name);
//  std::string property_setter_name("set__");
//  property_setter_name.append(property_name);
//
//  godot::StringName gd_getter(property_getter_name.c_str());
//  godot::StringName gd_setter(property_setter_name.c_str());
//
//  GDEWrapper *gde = GDEWrapper::instance();
//  gde_classdb_register_extension_class_property(gde->get_library_ptr(), bind_type.type_name, &prop_info,
//                                                gd_setter._native_ptr(), gd_getter._native_ptr());
//}

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

    Dart_Handle dart_method_info = Dart_HandleFromPersistent(reinterpret_cast<Dart_PersistentHandle>(method_userdata));

    Dart_Handle dart_args[] = {
        dart_instance,
        dart_method_info,
        Dart_NewInteger(int64_t(args)),
        Dart_NewInteger(int64_t(argument_count)),
        Dart_NewInteger(int64_t(r_return)),
    };
    DART_CHECK(type_resolver, Dart_HandleFromPersistent(gde->_type_resolver), "Failed to get typeResolver");
    DART_CHECK(result, Dart_Invoke(type_resolver, Dart_NewStringFromCString("invokeMethodVariantCall"), 5, dart_args),
               "Dart invoke failed");
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

    Dart_Handle type_info = Dart_HandleFromPersistent(reinterpret_cast<Dart_PersistentHandle>(p_userdata));
    DART_CHECK(constructor_tearoff, Dart_GetField(type_info, Dart_NewStringFromCString("constructObjectDefault")),
               "Failed to get default constructor tearoff");

    DART_CHECK(new_object, Dart_InvokeClosure(constructor_tearoff, 0, nullptr), "Error creating object");
    DART_CHECK(owner_address, Dart_GetField(new_object, Dart_NewStringFromCString("nativePointerAddress")),
               "Error finding owner member for object");

    Dart_IntegerToUint64(owner_address, &real_address);
  });

  return reinterpret_cast<GDExtensionObjectPtr>(real_address);
}

void GodotDartBindings::class_free_instance(void *p_userdata, GDExtensionClassInstancePtr p_instance) {
  // Instance is properly freed by engine binding callbacks
}

void *GodotDartBindings::get_virtual_call_data(void *p_userdata, GDExtensionConstStringNamePtr p_name) {
  GodotDartBindings *gde = GodotDartBindings::instance();
  if (!gde) {
    // oooff
    return nullptr;
  }

  void *user_data = nullptr;
  gde->execute_on_dart_thread([&]() {
    DartBlockScope scope;

    Dart_Handle type_info = Dart_HandleFromPersistent(reinterpret_cast<Dart_PersistentHandle>(p_userdata));

    // TODO: Maybe we can use StringNames directly instead of converting to Dart strings?
    const godot::StringName *gd_name = reinterpret_cast<const godot::StringName *>(p_name);
    Dart_Handle dart_method_name = to_dart_string(*gd_name);

    DART_CHECK(type_resolver, Dart_HandleFromPersistent(gde->_type_resolver), "Failed to get typeResolver");
    Dart_Handle args[] = {
        type_info,
        dart_method_name,
    };
    DART_CHECK(virtual_method_info,
               Dart_Invoke(type_resolver, Dart_NewStringFromCString("findVirtualFunction"), 2, args),
               "Failed to find virtual method info");
    if (Dart_IsNull(virtual_method_info)) {
      return;
    }

    user_data = Dart_NewPersistentHandle(virtual_method_info);
  });

  return user_data;
}

void GodotDartBindings::call_virtual_func(void *p_instance, GDExtensionConstStringNamePtr p_name, void *p_userdata,
                                          const GDExtensionConstTypePtr *p_args, GDExtensionTypePtr r_ret) {
  GodotDartBindings *gde = GodotDartBindings::instance();
  if (!gde) {
    // oooff
    return;
  }

  gde->execute_on_dart_thread([&]() {
    DartBlockScope scope;

    DartGodotInstanceBinding *binding = reinterpret_cast<DartGodotInstanceBinding *>(instance);
    Dart_Handle dart_instance = binding->get_dart_object();

    Dart_Handle dart_method_info = Dart_HandleFromPersistent(reinterpret_cast<Dart_PersistentHandle>(p_userdata));

    Dart_Handle dart_args[] = {
        dart_instance,
        dart_method_info,
        Dart_NewInteger(int64_t(p_args)),
        Dart_NewInteger(int64_t(r_ret)),
    };
    DART_CHECK(type_resolver, Dart_HandleFromPersistent(gde->_type_resolver), "Failed to get typeResolver");
    DART_CHECK(result, Dart_Invoke(type_resolver, Dart_NewStringFromCString("invokeMethodPtrCall"), 4, dart_args),
               "Dart invoke failed");
  });
}

void dart_message_notify_callback(Dart_Isolate isolate) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    return;
  }

  // TODO: Does this need to be thread safe?
  bindings->_pending_messages++;
}
