#include "dart_bindings.h"

#include <functional>
#include <iostream>
#include <string.h>
#include <thread>

#include <dart_api.h>
#include <dart_dll.h>
#include <dart_tools_api.h>
#include <godot/gdextension_interface.h>

#include "dart_script_instance.h"
#include "dart_vtable_wrapper.h"
#include "gde_wrapper.h"
#include "godot_string_wrappers.h"

void GodotDartBindings::thread_callback(GodotDartBindings *bindings) {
  bindings->thread_main();
}

/* Binding callbacks -- Used for Dart defined types and Variants */

static void *__binding_create_callback(void *p_token, void *p_instance) {
  return nullptr;
}

static void __binding_free_callback(void *p_token, void *p_instance, void *p_binding) {
}

static GDExtensionBool __binding_reference_callback(void *p_token, void *p_instance, GDExtensionBool p_reference) {
  return true;
}

static constexpr GDExtensionInstanceBindingCallbacks __binding_callbacks = {
    __binding_create_callback,
    __binding_free_callback,
    __binding_reference_callback,
};

/* Binding callbacks used for Engine types */

static void *__engine_binding_create_callback(void *p_token, void *p_instance) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings || p_instance == nullptr) {
    return nullptr;
  }

  void *ret_obj;
  bindings->execute_on_dart_thread([&] {
    Dart_PersistentHandle persistent_type = reinterpret_cast<Dart_PersistentHandle>(p_token);
    Dart_Handle dart_type = Dart_HandleFromPersistent(persistent_type);

    Dart_Handle dart_pointer = bindings->new_dart_void_pointer(p_instance);
    Dart_Handle args[1] = {dart_pointer};
    DART_CHECK(new_obj, Dart_New(dart_type, Dart_NewStringFromCString("withNonNullOwner"), 1, args),
               "Error creating bindings");
    Dart_PersistentHandle persist_new_obj = Dart_NewPersistentHandle(new_obj);

    ret_obj = reinterpret_cast<void *>(persist_new_obj);
  });

  return ret_obj;
}

static void __engine_binding_free_callback(void *ptoken, void *p_instance, void *p_binding) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    return;
  }

  bindings->execute_on_dart_thread([&] {
    Dart_PersistentHandle persistent = reinterpret_cast<Dart_PersistentHandle>(p_instance);
    Dart_Handle obj = Dart_HandleFromPersistent(persistent);
    if (!Dart_IsNull(obj)) {
      Dart_Invoke(obj, Dart_NewStringFromCString("detachOwner"), 0, nullptr);
      Dart_DeletePersistentHandle(persistent);
    }
  });
}

static GDExtensionBool __engine_binding_reference_callback(void *p_token, void *p_instance,
                                                           GDExtensionBool p_reference) {
  return true;
}

static constexpr GDExtensionInstanceBindingCallbacks __enging_binding_callbacks = {
    __engine_binding_create_callback,
    __engine_binding_free_callback,
    __engine_binding_reference_callback,
};

struct MethodInfo {
  std::string method_name;
  TypeInfo return_type;
  std::vector<TypeInfo> arguments;
  MethodFlags method_flags;
};

GodotDartBindings *GodotDartBindings::_instance = nullptr;
Dart_NativeFunction native_resolver(Dart_Handle name, int num_of_arguments, bool *auto_setup_scope);

GodotDartBindings::~GodotDartBindings() {
  _instance = nullptr;
}

bool GodotDartBindings::initialize(const char *script_path, const char *package_config) {
  dart_vtable_wrapper::init_virtual_thunks();

  DartDll_Initialize();

  _isolate = DartDll_LoadScript(script_path, package_config);
  if (_isolate == nullptr) {
    GD_PRINT_ERROR("GodotDart: Initialization Error (Failed to load script)");
    return false;
  }

  Dart_EnterIsolate(_isolate);
  Dart_EnterScope();

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
    Dart_Handle native_bindings_library_name = Dart_NewStringFromCString("package:godot_dart/src/core/core_types.dart");
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
    DART_CHECK_RET(void_pointer, Dart_GetNonNullableType(library, Dart_NewStringFromCString("Pointer"), 1, &type_args),
                   false, "Error getting Pointer<Void> type");
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
        Dart_NewInteger((int64_t)wrapper->gde()),
        Dart_NewInteger((int64_t)wrapper->lib()),
        Dart_NewInteger(((int64_t)&__enging_binding_callbacks)),
    };
    DART_CHECK_RET(result, Dart_Invoke(godot_dart_library, Dart_NewStringFromCString("_registerGodot"), 3, args), false,
                   "Error calling '_registerGodot'");
  }

  // And call the main function from the user supplied library
  {
    Dart_Handle library = Dart_RootLibrary();
    Dart_Handle mainFunctionName = Dart_NewStringFromCString("main");
    DART_CHECK_RET(result, Dart_Invoke(library, mainFunctionName, 0, nullptr), false, "Error calling 'main'");
  }

  Dart_ExitScope();

  // Create a thread for doing Dart work
  Dart_ExitIsolate();
  _dart_thread = new std::thread(GodotDartBindings::thread_callback, this);

  return true;
}

void GodotDartBindings::shutdown() {
  _stopRequested = true;
  execute_on_dart_thread([]() {});

  // Unset Dart thread. All future execution should now happen on this thread.
  _dart_thread->join();
  delete _dart_thread;
  _dart_thread = nullptr;

  Dart_EnterIsolate(_isolate);
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

  // Don't actually shut down. Godot still has some cleanup to do. 😡
  //Dart_ShutdownIsolate();
  //DartDll_Shutdown();
}

void GodotDartBindings::thread_main() {

  Dart_EnterIsolate(_isolate);

  while (!_stopRequested) {
    _work_semaphore.acquire();
    
    _pendingWork();
    _pendingWork = []() {};

    _done_semaphore.release();
  }

  Dart_ExitIsolate();
}

void GodotDartBindings::execute_on_dart_thread(std::function<void()> work) {
  if (_dart_thread == nullptr || std::this_thread::get_id() == _dart_thread->get_id()) {
    work();
    return;
  }

  _work_lock.lock();

  _pendingWork = work;
  _work_semaphore.release();
  _done_semaphore.acquire();
  
  _work_lock.unlock();
}

Dart_Handle GodotDartBindings::new_dart_void_pointer(void *ptr) {
  Dart_Handle dart_int = Dart_NewIntegerFromUint64(reinterpret_cast<uint64_t>(ptr));
  Dart_Handle args[1] = {dart_int};

  return Dart_New(_void_pointer_pointer_type, Dart_NewStringFromCString("fromAddress"), 1, args);
}

void GodotDartBindings::bind_method(const TypeInfo &bind_type, const char *method_name, const TypeInfo &ret_type_info,
                                    const std::vector<TypeInfo> &arg_list, MethodFlags method_flags) {
  MethodInfo *info = new MethodInfo();
  info->method_name = method_name;
  info->return_type = ret_type_info;
  info->arguments = arg_list;
  info->method_flags = method_flags;

  GDEWrapper *gde = GDEWrapper::instance();

  uint8_t gd_empty_string[GD_STRING_NAME_MAX_SIZE];
  GDE->string_new_with_utf8_chars(&gd_empty_string, "");

  GDExtensionPropertyInfo ret_info = {
      ret_type_info.variant_type,
      ret_type_info.type_name,
      gd_empty_string,
      0, // Hint - String
      gd_empty_string,
      6, // Usage - PROPERTY_USAGE_DEFAULT,
  };

  // Parameters / Metadata
  GDExtensionPropertyInfo *arg_info = new GDExtensionPropertyInfo[arg_list.size()];
  GDExtensionClassMethodArgumentMetadata *arg_meta_info = new GDExtensionClassMethodArgumentMetadata[arg_list.size()];
  for (size_t i = 0; i < arg_list.size(); ++i) {
    arg_info[i].class_name = arg_list[i].type_name;
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
      arg_list.size(),
      arg_info,
      arg_meta_info,
      0,
      nullptr,
  };

  GDE->classdb_register_extension_class_method(gde->lib(), bind_type.type_name, &method_info);

  delete[] arg_info;
  delete[] arg_meta_info;
}

void GodotDartBindings::add_property(const TypeInfo &bind_type, const char *property_name,
                                     GDExtensionPropertyInfo *prop_info) {
  TypeInfo property_type_info = {
      prop_info->class_name,
      nullptr,
      prop_info->type,
      nullptr,
  };
  std::vector<TypeInfo> getter_args;
  std::vector<TypeInfo> setter_args;
  setter_args.push_back(property_type_info);

  bind_method(bind_type, property_name, property_type_info, getter_args, MethodFlags::PropertyGetter);
  bind_method(bind_type, property_name, TypeInfo(), setter_args, MethodFlags::PropertySetter);

  std::string property_getter_name("get__");
  property_getter_name.append(property_name);
  std::string property_setter_name("set__");
  property_setter_name.append(property_name);

  GDStringName gd_getter(property_getter_name.c_str());
  GDStringName gd_setter(property_setter_name.c_str());

  GDEWrapper *gde = GDEWrapper::instance();
  GDE->classdb_register_extension_class_property(gde->lib(), bind_type.type_name, prop_info, gd_setter._native_ptr(),
                                                 gd_getter._native_ptr());
}

void *get_opaque_address(Dart_Handle variant_handle) {
  // TODO: Look for a better way convert the variant.
  Dart_Handle opaque = Dart_GetField(variant_handle, Dart_NewStringFromCString("_opaque"));
  if (Dart_IsError(opaque)) {
    GD_PRINT_ERROR(Dart_GetError(opaque));
    return nullptr;
  }
  Dart_Handle address = Dart_GetField(opaque, Dart_NewStringFromCString("address"));
  if (Dart_IsError(address)) {
    GD_PRINT_ERROR(Dart_GetError(address));
    return nullptr;
  }
  uint64_t variantDataPtr = 0;
  Dart_IntegerToUint64(address, &variantDataPtr);

  return reinterpret_cast<void *>(variantDataPtr);
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
    type_info->binding_callbacks = nullptr;
  } else {
    type_info->binding_callbacks = &__enging_binding_callbacks;
  }

  Dart_ExitScope();
}

/* Static Callbacks from Godot */

void GodotDartBindings::bind_call(void *method_userdata, GDExtensionClassInstancePtr instance,
                                  const GDExtensionConstVariantPtr *args, GDExtensionInt argument_count,
                                  GDExtensionVariantPtr r_return, GDExtensionCallError *r_error) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    // oooff
    return;
  }
  // TODO: This needs to be redone with the new way that DartScripInstance is doing it. I changed
  // `convertFromVariant` to take a "bindingToken" instead of a binding callback and never changed
  // `_variantsToDart` to match. `_variantsToDart` now correctly takes a binding token.

  //bindings->execute_on_dart_thread([&]() {
  //  Dart_EnterScope();

  //  Dart_PersistentHandle persist_handle = reinterpret_cast<Dart_PersistentHandle>(instance);
  //  Dart_Handle dart_instance = Dart_HandleFromPersistent(persist_handle);

  //  MethodInfo *method_info = reinterpret_cast<MethodInfo *>(method_userdata);
  //  Dart_Handle dart_method_name = Dart_NewStringFromCString(method_info->method_name.c_str());

  //  Dart_Handle *dart_args = nullptr;
  //  if (method_info->arguments.size() > 0) {
  //    // First convert to Dart values
  //    // Get all the bindings callbacks for the requested parameters
  //    Dart_Handle dart_bindings_list =
  //        Dart_NewListOfTypeFilled(bindings->_void_pointer_optional_type, Dart_Null(), method_info->arguments.size());
  //    for (size_t i = 0; i < method_info->arguments.size(); ++i) {
  //      const TypeInfo &arg_info = method_info->arguments[i];
  //      if (arg_info.binding_callbacks != nullptr) {
  //        Dart_Handle callbacks_address = Dart_NewInteger(reinterpret_cast<intptr_t>(args));
  //        Dart_Handle callbacks_ptr = Dart_New(Dart_HandleFromPersistent(bindings->_void_pointer_pointer_type),
  //                                             Dart_NewStringFromCString("fromAddress"), 1, &callbacks_address);
  //        Dart_ListSetAt(dart_bindings_list, i, callbacks_ptr);
  //      }
  //    }

  //    Dart_Handle args_address = Dart_NewInteger(reinterpret_cast<intptr_t>(args));
  //    Dart_Handle convert_args[3]{
  //        Dart_New(Dart_HandleFromPersistent(bindings->_void_pointer_pointer_type),
  //                 Dart_NewStringFromCString("fromAddress"), 1, &args_address),
  //        Dart_NewInteger(method_info->arguments.size()),
  //        dart_bindings_list,
  //    };
  //    if (Dart_IsError(convert_args[0])) {
  //      GD_PRINT_ERROR("GodotDart: Error creating parameters: ");
  //      GD_PRINT_ERROR(Dart_GetError(convert_args[0]));

  //      Dart_ExitScope();
  //      return;
  //    }

  //    DART_CHECK(dart_arg_list,
  //               Dart_Invoke(bindings->_native_library, Dart_NewStringFromCString("_variantsToDart"), 3, convert_args),
  //               "Error converting parameters from Variants");

  //    dart_args = new Dart_Handle[method_info->arguments.size()];
  //    for (size_t i = 0; i < method_info->arguments.size(); ++i) {
  //      dart_args[i] = Dart_ListGetAt(dart_arg_list, i);
  //    }
  //  }

  //  Dart_Handle result = Dart_Null();
  //  if (method_info->method_flags == MethodFlags::None) {
  //    result = Dart_Invoke(dart_instance, dart_method_name, method_info->arguments.size(), dart_args);
  //    if (Dart_IsError(result)) {
  //      GD_PRINT_ERROR("GodotDart: Error calling function: ");
  //      GD_PRINT_ERROR(Dart_GetError(result));
  //    }
  //  } else if (method_info->method_flags == MethodFlags::PropertyGetter) {
  //    result = Dart_GetField(dart_instance, dart_method_name);
  //    if (Dart_IsError(result)) {
  //      GD_PRINT_ERROR("GodotDart: Error calling getter: ");
  //      GD_PRINT_ERROR(Dart_GetError(result));
  //    }
  //  } else if (method_info->method_flags == MethodFlags::PropertySetter) {
  //    result = Dart_SetField(dart_instance, dart_method_name, dart_args[0]);
  //    if (Dart_IsError(result)) {
  //      GD_PRINT_ERROR("GodotDart: Error calling setter: ");
  //      GD_PRINT_ERROR(Dart_GetError(result));
  //    }
  //  }

  //  if (!Dart_IsError(result)) {
  //    // Call back into Dart to convert to Variant. This may get moved back into C at some point but
  //    // the logic and type checking is easier in Dart.
  //    Dart_Handle native_library = Dart_HandleFromPersistent(bindings->_native_library);
  //    Dart_Handle args[] = {result};
  //    Dart_Handle variant_result = Dart_Invoke(native_library, Dart_NewStringFromCString("_convertToVariant"), 1, args);
  //    if (Dart_IsError(variant_result)) {
  //      GD_PRINT_ERROR("GodotDart: Error converting return to variant: ");
  //      GD_PRINT_ERROR(Dart_GetError(result));
  //    } else {
  //      void *variantDataPtr = get_opaque_address(variant_result);
  //      if (variantDataPtr) {
  //        GDE->variant_new_copy(r_return, reinterpret_cast<GDExtensionConstVariantPtr>(variantDataPtr));
  //      }
  //    }
  //  }

  //  if (dart_args != nullptr) {
  //    delete[] dart_args;
  //  }

  //  Dart_ExitScope();
  //});
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

    // Not implemented yet (haven't come across an instance of it yet?)

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
    Dart_EnterScope();

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

    Dart_ExitScope();
  });

  return reinterpret_cast<GDExtensionObjectPtr>(real_address);
}

void GodotDartBindings::class_free_instance(void *p_userdata, GDExtensionClassInstancePtr p_instance) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    // oooff
    return;
  }

  bindings->execute_on_dart_thread([&]() {
    Dart_EnterScope();

    Dart_PersistentHandle persistent = reinterpret_cast<Dart_PersistentHandle>(p_instance);
    Dart_Handle obj = Dart_HandleFromPersistent(persistent);
    Dart_Handle ret = Dart_Invoke(obj, Dart_NewStringFromCString("detachOwner"), 0, nullptr);
    if (Dart_IsError(ret)) {
      GD_PRINT_ERROR("GodotDart: Error detaching owner during instance free: ");
      GD_PRINT_ERROR(Dart_GetError(ret));
    }
    Dart_DeletePersistentHandle(persistent);

    Dart_ExitScope();
  });
}

GDExtensionClassCallVirtual GodotDartBindings::get_virtual_func(void *p_userdata,
                                                                GDExtensionConstStringNamePtr p_name) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    // oooff
    return nullptr;
  }

  GDExtensionClassCallVirtual func = nullptr;
  bindings->execute_on_dart_thread([&]() {
    Dart_EnterScope();

    Dart_Handle type = Dart_HandleFromPersistent(reinterpret_cast<Dart_PersistentHandle>(p_userdata));

    DART_CHECK(vtable, Dart_GetField(type, Dart_NewStringFromCString("vTable")), "Error finding typeInfo on object");
    if (Dart_IsNull(vtable)) {
      Dart_ExitScope();
      return;
    }

    // TODO: Maybe we can use StringNames directly instead of converting to Dart strings?
    const GDStringName *gd_name = reinterpret_cast<const GDStringName *>(p_name);
    Dart_Handle dart_string = gd_name->to_dart();

    DART_CHECK(vtable_item, Dart_MapGetAt(vtable, dart_string), "Error looking up vtable item");
    if (Dart_IsNull(vtable_item)) {
      Dart_ExitScope();
      return;
    }

    Dart_Handle dart_address = Dart_GetField(vtable_item, Dart_NewStringFromCString("address"));

    uint64_t address = 0;
    Dart_IntegerToUint64(dart_address, &address);

    func = dart_vtable_wrapper::get_wrapped_virtual(reinterpret_cast<GDExtensionClassCallVirtual>(address));

    Dart_ExitScope();
  });

  return func;
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
  Dart_Handle type_info = Dart_GetNativeArgument(args, 2);

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

  GDExtensionClassCreationInfo info = {0};
  info.class_userdata = (void *)Dart_NewPersistentHandle(type_arg);
  info.create_instance_func = GodotDartBindings::class_create_instance;
  info.free_instance_func = GodotDartBindings::class_free_instance;
  info.get_virtual_func = GodotDartBindings::get_virtual_func;

  GDE->classdb_register_extension_class(GDEWrapper::instance()->lib(), sn_name, sn_parent, &info);
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

  intptr_t arg_length = 0;
  Dart_ListLength(d_argument_list, &arg_length);

  std::vector<TypeInfo> argument_list;
  argument_list.reserve(arg_length);
  for (intptr_t i = 0; i < arg_length; ++i) {
    Dart_Handle d_arg = Dart_ListGetAt(d_argument_list, i);
    TypeInfo arg;

    type_info_from_dart(&arg, d_arg);
    argument_list.push_back(arg);
  }

  bindings->bind_method(bind_type_info, method_name, return_type_info, argument_list, MethodFlags::None);
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

  const char *property_name = nullptr;
  Dart_StringToCString(Dart_GetNativeArgument(args, 2), &property_name);

  GDExtensionPropertyInfo prop_info = {};
  Dart_Handle dart_info = Dart_GetNativeArgument(args, 3);
  {
    DART_CHECK(d_type, Dart_GetField(dart_info, Dart_NewStringFromCString("type")), "Error getting type property");
    DART_CHECK(enum_value, Dart_GetField(d_type, Dart_NewStringFromCString("value")), "Error getting type value");
    int64_t type_value;
    Dart_IntegerToInt64(enum_value, &type_value);
    prop_info.type = GDExtensionVariantType(type_value);
  }
  Dart_Handle name_prop = Dart_GetField(dart_info, Dart_NewStringFromCString("name"));
  GDStringName gd_name(name_prop);
  prop_info.name = gd_name._native_ptr();

  Dart_Handle class_name_prop = Dart_GetField(dart_info, Dart_NewStringFromCString("className"));
  GDStringName gd_class_name(class_name_prop);
  prop_info.class_name = gd_class_name._native_ptr();

  {
    DART_CHECK(hint, Dart_GetField(dart_info, Dart_NewStringFromCString("hint")), "Error getting hint property");
    DART_CHECK(enum_value, Dart_GetField(hint, Dart_NewStringFromCString("value")), "Error getting hint value");
    uint64_t hint_value;
    Dart_IntegerToUint64(enum_value, &hint_value);
    prop_info.hint = uint32_t(hint_value);
  }

  Dart_Handle hint_string_prop = Dart_GetField(dart_info, Dart_NewStringFromCString("hintString"));
  GDString gd_hint_string(hint_string_prop);
  prop_info.hint_string = gd_hint_string._native_ptr();

  {
    DART_CHECK(dart_flags, Dart_GetField(dart_info, Dart_NewStringFromCString("flags")), "Error getting flagsproperty");
    uint64_t flags;
    Dart_IntegerToUint64(dart_flags, &flags);
    prop_info.usage = uint32_t(flags);
  }

  bindings->add_property(bind_type_info, property_name, &prop_info);
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
  void *token = gde->lib();
  Dart_Handle bindings_token = Dart_GetNativeArgument(args, 2);
  const GDExtensionInstanceBindingCallbacks *bindings_callbacks = &__binding_callbacks;
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
    bindings_callbacks = &__enging_binding_callbacks;
  }

  Dart_PersistentHandle dart_persistent = (Dart_PersistentHandle)GDE->object_get_instance_binding(
      reinterpret_cast<GDExtensionObjectPtr>(object_ptr), token, bindings_callbacks);
  if (dart_persistent == nullptr) {
    Dart_SetReturnValue(args, Dart_Null());
  } else {
    Dart_Handle obj = Dart_HandleFromPersistent(dart_persistent);
    if (Dart_IsError(obj)) {
      GD_PRINT_ERROR(Dart_GetError(obj));
      Dart_ThrowException(Dart_NewStringFromCString(Dart_GetError(address)));
      return;
    }
    Dart_SetReturnValue(args, obj);
  }
}

void dart_object_post_initialize(Dart_NativeArguments args) {
  Dart_Handle dart_self = Dart_GetNativeArgument(args, 0);
  Dart_Handle d_class_type_info = Dart_GetField(dart_self, Dart_NewStringFromCString("typeInfo"));
  if (Dart_IsError(d_class_type_info)) {
    GD_PRINT_ERROR("GodotDart: Error finding typeInfo on object: ");
    GD_PRINT_ERROR(Dart_GetError(d_class_type_info));
  }

  TypeInfo class_type_info;
  type_info_from_dart(&class_type_info, d_class_type_info);

  Dart_Handle owner = Dart_GetField(dart_self, Dart_NewStringFromCString("nativePtr"));
  if (Dart_IsError(owner)) {
    GD_PRINT_ERROR("GodotDart: Error finding owner member for object: ");
    GD_PRINT_ERROR(Dart_GetError(owner));
  }

  Dart_Handle owner_address = Dart_GetField(owner, Dart_NewStringFromCString("address"));
  if (Dart_IsError(owner_address)) {
    GD_PRINT_ERROR("GodotDart: Error getting address for object: ");
    GD_PRINT_ERROR(Dart_GetError(owner_address));
  }

  Dart_PersistentHandle persistent_handle = Dart_NewPersistentHandle(dart_self);
  GDEWrapper *gde = GDEWrapper::instance();

  uint64_t real_address = 0;
  Dart_IntegerToUint64(owner_address, &real_address);

  GDE->object_set_instance(reinterpret_cast<GDExtensionObjectPtr>(real_address), class_type_info.type_name,
                           reinterpret_cast<GDExtensionClassInstancePtr>(persistent_handle));
  GDE->object_set_instance_binding(reinterpret_cast<GDExtensionObjectPtr>(real_address), gde->lib(), persistent_handle,
                                   &__binding_callbacks);
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
  } else if (0 == strcmp(c_name, "ExtensionType::postInitialize")) {
    *auto_setup_scope = true;
    ret = dart_object_post_initialize;
  }

  Dart_ExitScope();
  return ret;
}

// C calls from Dart
extern "C" {

GDE_EXPORT void variant_copy(void *dest, void *src, int size) {
  memcpy(dest, src, size);
}

GDE_EXPORT void finalize_extension_object(GDExtensionObjectPtr extention_object) {
  if (extention_object == nullptr) {
    return;
  }

  GDE->object_destroy(extention_object);
}

GDE_EXPORT void *create_script_instance(Dart_Handle type, Dart_Handle script, void *godot_object) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings || godot_object == nullptr) {
    return nullptr;
  }

  Dart_Handle dart_pointer = bindings->new_dart_void_pointer(godot_object);
  Dart_Handle args[1] = {dart_pointer};
  DART_CHECK_RET(dart_object, Dart_New(type, Dart_NewStringFromCString("withNonNullOwner"), 1, args), nullptr,
                 "Error creating bindings", );

  DartScriptInstance *script_instance = new DartScriptInstance(dart_object, script, godot_object);
  GDExtensionScriptInstancePtr godot_script_instance =
      GDE->script_instance_create(DartScriptInstance::get_script_instance_info(),
                                  reinterpret_cast<GDExtensionScriptInstanceDataPtr>(script_instance));

  return godot_script_instance;
}

GDE_EXPORT void perform_frame_maintenance() {
  Dart_EnterScope();

  uint64_t currentTime = Dart_TimelineGetMicros();
  Dart_NotifyIdle(currentTime + 1000); // Idle for 1 ms... increase when we get to use once a frame.

  Dart_Handle result = Dart_WaitForEvent(1);
  if (Dart_IsError(result)) {
    GD_PRINT_ERROR("GodotDart: Error calling `Dart_WaitForEvent`");
    GD_PRINT_ERROR(Dart_GetError(result));
  }

  Dart_ExitScope();
}
}