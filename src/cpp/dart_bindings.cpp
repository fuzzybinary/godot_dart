#include "dart_bindings.h"

#include <iostream>
#include <string.h>

#include <dart_api.h>
#include <dart_dll.h>
#include <godot/gdextension_interface.h>

#include "gde_wrapper.h"

#define GDE GDEWrapper::instance()->gde()

struct MethodInfo {
  std::string method_name;
};

GodotDartBindings *GodotDartBindings::_instance = nullptr;
Dart_NativeFunction native_resolver(Dart_Handle name, int num_of_arguments, bool *auto_setup_scope);

bool GodotDartBindings::initialize(const char *script_path, const char *package_config) {
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
  }

  {
    GDEWrapper *wrapper = GDEWrapper::instance();
    Dart_Handle args[] = {Dart_NewInteger((int64_t)wrapper->gde()), Dart_NewInteger((int64_t)wrapper->lib())};
    Dart_Handle result = Dart_Invoke(godot_dart_library, Dart_NewStringFromCString("_registerGodot"), 2, args);
    if (Dart_IsError(result)) {
      GD_PRINT_ERROR("GodotDart: Error calling `_registerGodot`");
      GD_PRINT_ERROR(Dart_GetError(result));
      return false;
    }
  }

  // Find the DartBindings "library" (just the file) and set us as the native callback handler
  {
    Dart_Handle native_bindings_library_name =
        Dart_NewStringFromCString("package:godot_dart/src/core/godot_dart_native_bindings.dart");
    Dart_Handle library = Dart_LookupLibrary(native_bindings_library_name);
    if (!Dart_IsError(library)) {
      Dart_SetNativeResolver(library, native_resolver, nullptr);
    }
  }

  // All set up, setup the instance
  _instance = this;

  {
    Dart_Handle library = Dart_RootLibrary();
    Dart_Handle mainFunctionName = Dart_NewStringFromCString("main");
    Dart_Handle result = Dart_Invoke(library, mainFunctionName, 0, nullptr);
    if (Dart_IsError(result)) {
      GD_PRINT_ERROR("GodotDart: Error calling `main`");
      GD_PRINT_ERROR(Dart_GetError(result));
      return false;
    }
  }

  Dart_ExitScope();

  return true;
}

void GodotDartBindings::shutdown() {
  DartDll_DrainMicrotaskQueue();
  Dart_ShutdownIsolate();
  DartDll_Shutdown();

  _instance = nullptr;
}

void GodotDartBindings::set_instance(GDExtensionObjectPtr gd_object, GDExtensionConstStringNamePtr classname,
                                     Dart_Handle instance) {
  // Persist the handle, as Godot will be holding onto it.
  Dart_PersistentHandle persist = Dart_NewPersistentHandle(instance);
  GDE->object_set_instance(gd_object, classname, persist);
}

void GodotDartBindings::bind_method(const char *classname, const char *method_name) {
  // TODO: How do we pass types to this?
  MethodInfo *info = new MethodInfo();
  info->method_name = method_name;

  GDEWrapper *gde = GDEWrapper::instance();
  uint8_t gd_ret_class_name[GD_STRING_NAME_MAX_SIZE];
  uint8_t gd_ret_name[GD_STRING_NAME_MAX_SIZE];
  gde->gd_string_name_new(&gd_ret_class_name, "String");
  gde->gd_string_name_new(&gd_ret_name, "");

  uint8_t gd_empty_string[GD_STRING_NAME_MAX_SIZE];
  GDE->string_new_with_utf8_chars(&gd_empty_string, "");
  GDExtensionPropertyInfo ret_info = {
      GDEXTENSION_VARIANT_TYPE_STRING,
      gd_ret_class_name,
      gd_ret_name,
      0, // Hint - String
      gd_empty_string,
      6, // Usage - PROPERTY_USAGE_DEFAULT,
  };

  uint8_t gd_class_name[GD_STRING_NAME_MAX_SIZE];
  uint8_t gd_method_name[GD_STRING_NAME_MAX_SIZE];
  gde->gd_string_name_new(&gd_class_name, classname);
  gde->gd_string_name_new(&gd_method_name, method_name);
  GDExtensionClassMethodInfo method_info = {
      gd_method_name,
      info,
      GodotDartBindings::bind_call,
      GodotDartBindings::ptr_call,
      GDEXTENSION_METHOD_FLAGS_DEFAULT,
      true, /* has return value */
      &ret_info,
      GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE,
      0,
      nullptr,
      nullptr,
      0,
      nullptr,
  };

  GDE->classdb_register_extension_class_method(gde->lib(), gd_class_name, &method_info);
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

/* Static Callbacks from Godot */

void GodotDartBindings::bind_call(void *method_userdata, GDExtensionClassInstancePtr instance,
                                  const GDExtensionConstVariantPtr *args, GDExtensionInt argument_count,
                                  GDExtensionVariantPtr r_return, GDExtensionCallError *r_error) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    // oooff
    return;
  }

  Dart_EnterScope();

  Dart_PersistentHandle persist_handle = reinterpret_cast<Dart_PersistentHandle>(instance);
  Dart_Handle dart_instance = Dart_HandleFromPersistent(persist_handle);

  MethodInfo *method_info = reinterpret_cast<MethodInfo *>(method_userdata);
  Dart_Handle dart_method_name = Dart_NewStringFromCString(method_info->method_name.c_str());

  Dart_Handle handle = Dart_Invoke(dart_instance, dart_method_name, 0, nullptr);
  if (Dart_IsError(handle)) {
    GD_PRINT_ERROR("GodotDart: Error calling function: ");
    GD_PRINT_ERROR(Dart_GetError(handle));
  } else {
    void *variantDataPtr = get_opaque_address(handle);
    if (variantDataPtr) {
      GDE->variant_new_copy(r_return, reinterpret_cast<GDExtensionConstVariantPtr>(variantDataPtr));
    }
  }

fail:

  Dart_ExitScope();
}

void GodotDartBindings::ptr_call(void *method_userdata, GDExtensionClassInstancePtr instance,
                                 const GDExtensionConstVariantPtr *args, GDExtensionVariantPtr r_return) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    // oooff
    return;
  }

  Dart_EnterScope();

  Dart_PersistentHandle persist_handle = reinterpret_cast<Dart_PersistentHandle>(instance);
  Dart_Handle dart_instance = Dart_HandleFromPersistent(persist_handle);

  MethodInfo *method_info = reinterpret_cast<MethodInfo *>(method_userdata);
  Dart_Handle dart_method_name = Dart_NewStringFromCString(method_info->method_name.c_str());

  Dart_Handle handle = Dart_Invoke(dart_instance, dart_method_name, 0, nullptr);
  if (Dart_IsError(handle)) {
    GD_PRINT_ERROR("GodotDart: Error calling function: ");
    GD_PRINT_ERROR(Dart_GetError(handle));
  } else {
    // Assume it's a string, for now.
    const char *retval = nullptr;
    Dart_StringToCString(handle, &retval);

    uint8_t ret_string[GD_STRING_NAME_MAX_SIZE];
    GDE->string_new_with_utf8_chars(ret_string, retval);
    // NOT SAFE -- I'm assuming I know that this is an 8 byte copy :(
    memcpy(r_return, ret_string, GD_STRING_NAME_MAX_SIZE);
  }

  Dart_ExitScope();
}

GDExtensionObjectPtr GodotDartBindings::class_create_instance(void *p_userdata) {
  Dart_EnterScope();

  Dart_Handle type = Dart_HandleFromPersistent(reinterpret_cast<Dart_PersistentHandle>(p_userdata));

  Dart_Handle class_name = Dart_GetField(type, Dart_NewStringFromCString("className"));
  if (Dart_IsError(class_name)) {
    GD_PRINT_ERROR("GodotDart: Error finding class name on object: ");
    GD_PRINT_ERROR(Dart_GetError(class_name));
    Dart_ExitScope();
    return nullptr;
  }
  void *opaque_class_name = get_opaque_address(class_name);

  Dart_Handle new_object = Dart_New(type, Dart_Null(), 0, nullptr);
  if (Dart_IsError(new_object)) {
    GD_PRINT_ERROR("GodotDart: Error creating object: ");
    GD_PRINT_ERROR(Dart_GetError(new_object));
    Dart_ExitScope();
    return nullptr;
  }

  Dart_Handle owner = Dart_GetField(new_object, Dart_NewStringFromCString("owner"));
  if (Dart_IsError(owner)) {
    GD_PRINT_ERROR("GodotDart: Error finding owner member for object: ");
    GD_PRINT_ERROR(Dart_GetError(owner));
    Dart_ExitScope();
    return nullptr;
  }

  Dart_Handle owner_address = Dart_GetField(owner, Dart_NewStringFromCString("address"));
  if (Dart_IsError(owner_address)) {
    GD_PRINT_ERROR("GodotDart: Error getting address for object: ");
    GD_PRINT_ERROR(Dart_GetError(owner_address));
    Dart_ExitScope();
    return nullptr;
  }

  uint64_t real_address = 0;
  Dart_IntegerToUint64(owner_address, &real_address);
  Dart_PersistentHandle persistent_handle = Dart_NewPersistentHandle(new_object);
  GDE->object_set_instance(reinterpret_cast<GDExtensionObjectPtr>(real_address), opaque_class_name,
                           reinterpret_cast<GDExtensionClassInstancePtr>(persistent_handle));

  Dart_ExitScope();

  return reinterpret_cast<GDExtensionObjectPtr>(real_address);
}

void GodotDartBindings::class_free_instance(void *p_userdata, GDExtensionClassInstancePtr p_instance) {
  Dart_DeletePersistentHandle(reinterpret_cast<Dart_PersistentHandle>(p_instance));
}

/* Static Functions From Dart */

void bind_class(Dart_NativeArguments args) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    Dart_ThrowException(Dart_NewStringFromCString("GodotDart has been shutdown!"));
    return;
  }

  Dart_Handle type_arg = Dart_GetNativeArgument(args, 1);
  Dart_Handle name = Dart_GetNativeArgument(args, 2);
  Dart_Handle parent = Dart_GetNativeArgument(args, 3);

  // Name and Parent are StringNames and we can get their opaque addresses
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

  GDE->classdb_register_extension_class(GDEWrapper::instance()->lib(), sn_name, sn_parent, &info);
}

void bind_method(Dart_NativeArguments args) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    Dart_ThrowException(Dart_NewStringFromCString("GodotDart has been shutdown!"));
    return;
  }

  const char *class_name = nullptr;
  const char *method_name = nullptr;
  Dart_StringToCString(Dart_GetNativeArgument(args, 1), &class_name);
  Dart_StringToCString(Dart_GetNativeArgument(args, 2), &method_name);

  bindings->bind_method(class_name, method_name);
}

Dart_NativeFunction native_resolver(Dart_Handle name, int num_of_arguments, bool *auto_setup_scope) {
  Dart_EnterScope();

  const char *c_name = nullptr;
  Dart_StringToCString(name, &c_name);

  if (0 == strcmp(c_name, "GodotDartNativeBindings::bindMethod")) {
    *auto_setup_scope = true;
    return bind_method;
  } else if (0 == strcmp(c_name, "GodotDartNativeBindings::bindClass")) {
    *auto_setup_scope = true;
    return bind_class;
  }

  return nullptr;
}