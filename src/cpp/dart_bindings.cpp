#include "dart_bindings.h"

#include <iostream>
#include <string.h>

#include <dart_api.h>
#include <dart_dll.h>
#include <godot/gdextension_interface.h>

#include "gde_wrapper.h"

#define GDE GDEWrapper::instance()->gde()

/* Binding callbacks (not sure what these are for?) */

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

struct MethodInfo {
  std::string method_name;
  TypeInfo return_type;
  std::vector<TypeInfo> arguments;
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
      // Retrain for future calls to convert variants
      _native_library = Dart_NewPersistentHandle(library);
      Dart_SetNativeResolver(library, native_resolver, nullptr);
    }
  }

  // Setup some types we need frequently
  {
    Dart_Handle library = Dart_LookupLibrary(Dart_NewStringFromCString("dart:ffi"));
    if (Dart_IsError(library)) {
      GD_PRINT_ERROR("GodotDart: Error getting ffi library: ");
      GD_PRINT_ERROR(Dart_GetError(library));

      return false;
    }
    Dart_Handle dart_void = Dart_GetNonNullableType(library, Dart_NewStringFromCString("Void"), 0, nullptr);
    if (Dart_IsError(dart_void)) {
      GD_PRINT_ERROR("GodotDart: Error getting Void type: ");
      GD_PRINT_ERROR(Dart_GetError(dart_void));

      return false;
    }
    Dart_Handle type_args = Dart_NewList(1);
    if (Dart_IsError(type_args)) {
      GD_PRINT_ERROR("GodotDart: Could not create arg list ");
      GD_PRINT_ERROR(Dart_GetError(type_args));

      return false;
    }
    Dart_ListSetAt(type_args, 0, dart_void);
    Dart_Handle void_pointer = Dart_GetNonNullableType(library, Dart_NewStringFromCString("Pointer"), 1, &type_args);
    if (Dart_IsError(void_pointer)) {
      GD_PRINT_ERROR("GodotDart: Error getting Pointer<Void> type: ");
      GD_PRINT_ERROR(Dart_GetError(void_pointer));

      return false;
    }
    _void_pointer_type = Dart_NewPersistentHandle(void_pointer);

    Dart_Handle type_args_2 = Dart_NewList(1);
    Dart_ListSetAt(type_args_2, 0, void_pointer);
    Dart_Handle pointer_to_pointer =
        Dart_GetNonNullableType(library, Dart_NewStringFromCString("Pointer"), 1, &type_args_2);
    if (Dart_IsError(pointer_to_pointer)) {
      GD_PRINT_ERROR("GodotDart: Error getting Pointer<Pointer<Void>> type: ");
      GD_PRINT_ERROR(Dart_GetError(pointer_to_pointer));

      return false;
    }
    _void_pointer_pointer_type = Dart_NewPersistentHandle(pointer_to_pointer);
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

void GodotDartBindings::bind_method(const TypeInfo &bind_type, const char *method_name, const TypeInfo &ret_type_info,
                                    const std::vector<TypeInfo> &arg_list) {
  MethodInfo *info = new MethodInfo();
  info->method_name = method_name;
  info->return_type = ret_type_info;
  info->arguments = arg_list;

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
    arg_info[i].name = gd_empty_string, arg_info[i].usage = 6,

    // TODO - actually need this to specify int / double size
        arg_meta_info[i] = GDEXTENSION_METHOD_ARGUMENT_METADATA_NONE;
  }

  uint8_t gd_method_name[GD_STRING_NAME_MAX_SIZE];
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

  type_info->type_name = get_opaque_address(class_name);
  if (Dart_IsNull(parent_class)) {
    type_info->parent_name = nullptr;
  } else {
    type_info->parent_name = get_opaque_address(parent_class);
  }
  int64_t temp;
  Dart_IntegerToInt64(variant_type, &temp);
  type_info->variant_type = static_cast<GDExtensionVariantType>(temp);

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

  Dart_EnterScope();

  Dart_PersistentHandle persist_handle = reinterpret_cast<Dart_PersistentHandle>(instance);
  Dart_Handle dart_instance = Dart_HandleFromPersistent(persist_handle);

  MethodInfo *method_info = reinterpret_cast<MethodInfo *>(method_userdata);
  Dart_Handle dart_method_name = Dart_NewStringFromCString(method_info->method_name.c_str());

  Dart_Handle *dart_args = nullptr;
  if (method_info->arguments.size() > 0) {
    // First convert to Dart values
    Dart_Handle args_address = Dart_NewInteger(reinterpret_cast<intptr_t>(args));
    Dart_Handle convert_args[2]{
        Dart_New(Dart_HandleFromPersistent(bindings->_void_pointer_pointer_type),
                 Dart_NewStringFromCString("fromAddress"), 1, &args_address),
        Dart_NewInteger(method_info->arguments.size()),
    };
    if (Dart_IsError(convert_args[0])) {
      GD_PRINT_ERROR("GodotDart: Error creating parameters: ");
      GD_PRINT_ERROR(Dart_GetError(convert_args[0]));

      Dart_ExitScope();
      return;
    }
    Dart_Handle dart_arg_list =
        Dart_Invoke(bindings->_native_library, Dart_NewStringFromCString("_variantsToDart"), 2, convert_args);
    if (Dart_IsError(dart_arg_list)) {
      GD_PRINT_ERROR("GodotDart: Error converting parameters from Variants: ");
      GD_PRINT_ERROR(Dart_GetError(dart_arg_list));

      Dart_ExitScope();
      return;
    }

    dart_args = new Dart_Handle[method_info->arguments.size()];
    for (size_t i = 0; i < method_info->arguments.size(); ++i) {
      dart_args[i] = Dart_ListGetAt(dart_arg_list, i);
    }
  }

  Dart_Handle result = Dart_Invoke(dart_instance, dart_method_name, method_info->arguments.size(), dart_args);
  if (Dart_IsError(result)) {
    GD_PRINT_ERROR("GodotDart: Error calling function: ");
    GD_PRINT_ERROR(Dart_GetError(result));
  } else {
    // Call back into Dart to convert to Variant. This may get moved back into C at some point but
    // the logic and type checking is easier in Dart.
    Dart_Handle native_library = Dart_HandleFromPersistent(bindings->_native_library);
    Dart_Handle args[] = {result};
    Dart_Handle variant_result = Dart_Invoke(native_library, Dart_NewStringFromCString("_convertToVariant"), 1, args);
    if (Dart_IsError(variant_result)) {
      GD_PRINT_ERROR("GodotDart: Error converting return to variant: ");
      GD_PRINT_ERROR(Dart_GetError(result));
    } else {
      void *variantDataPtr = get_opaque_address(variant_result);
      if (variantDataPtr) {
        GDE->variant_new_copy(r_return, reinterpret_cast<GDExtensionConstVariantPtr>(variantDataPtr));
      }
    }
  }

  if (dart_args != nullptr) {
    delete[] dart_args;
  }

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

  // Not implemented yet (haven't come across an instance of it yet?)

  Dart_ExitScope();
}

GDExtensionObjectPtr GodotDartBindings::class_create_instance(void *p_userdata) {
  Dart_EnterScope();

  Dart_Handle type = Dart_HandleFromPersistent(reinterpret_cast<Dart_PersistentHandle>(p_userdata));

  Dart_Handle d_class_type_info = Dart_GetField(type, Dart_NewStringFromCString("typeInfo"));
  if (Dart_IsError(d_class_type_info)) {
    GD_PRINT_ERROR("GodotDart: Error finding typeInfo on object: ");
    GD_PRINT_ERROR(Dart_GetError(d_class_type_info));
    Dart_ExitScope();
    return nullptr;
  }
  TypeInfo class_type_info;
  type_info_from_dart(&class_type_info, d_class_type_info);

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

  GDEWrapper *gde = GDEWrapper::instance();

  uint64_t real_address = 0;
  Dart_IntegerToUint64(owner_address, &real_address);
  Dart_PersistentHandle persistent_handle = Dart_NewPersistentHandle(new_object);
  // TODO: This is serving as "_postInitialize" from th cpp example, but is only being used for Dart created
  // types at the moment. Need to generalize to allow Engine types (which shouldn't call object_set_instance)
  GDE->object_set_instance(reinterpret_cast<GDExtensionObjectPtr>(real_address), class_type_info.type_name,
                           reinterpret_cast<GDExtensionClassInstancePtr>(persistent_handle));
  GDE->object_set_instance_binding(reinterpret_cast<GDExtensionObjectPtr>(real_address), gde->lib(), persistent_handle,
                                   &__binding_callbacks);

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

  bindings->bind_method(bind_type_info, method_name, return_type_info, argument_list);
}

void gd_string_to_dart_string(Dart_NativeArguments args) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    Dart_ThrowException(Dart_NewStringFromCString("GodotDart has been shutdown!"));
    return;
  }

  Dart_Handle dart_gd_string = Dart_GetNativeArgument(args, 1);
  GDExtensionConstStringPtr gd_string = get_opaque_address(dart_gd_string);

  char16_t length = GDE->string_to_utf16_chars(gd_string, nullptr, 0);
  char16_t *temp = (char16_t *)_alloca(sizeof(char16_t) * length);
  GDE->string_to_utf16_chars(gd_string, temp, length);
  temp[length] = 0;

  Dart_Handle dart_string = Dart_NewStringFromUTF16((uint16_t *)temp, length);
  if (Dart_IsError(dart_string)) {
    Dart_ThrowException(Dart_NewStringFromCString(Dart_GetError(dart_string)));
    return;
  }

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

  GDEWrapper *gde = GDEWrapper::instance();

  // TODO: What's up with instance_binding?
  Dart_PersistentHandle dart_persistent = (Dart_PersistentHandle)GDE->object_get_instance_binding(
      reinterpret_cast<GDExtensionObjectPtr>(object_ptr), gde->lib(), &__binding_callbacks);
  if (dart_persistent == nullptr) {
    Dart_SetReturnValue(args, Dart_Null());
  } else {
    Dart_SetReturnValue(args, Dart_HandleFromPersistent(dart_persistent));
  }
}

Dart_NativeFunction native_resolver(Dart_Handle name, int num_of_arguments, bool *auto_setup_scope) {
  Dart_EnterScope();

  const char *c_name = nullptr;
  Dart_StringToCString(name, &c_name);

  Dart_NativeFunction ret = nullptr;

  if (0 == strcmp(c_name, "GodotDartNativeBindings::bindMethod")) {
    *auto_setup_scope = true;
    ret = bind_method;
  } else if (0 == strcmp(c_name, "GodotDartNativeBindings::bindClass")) {
    *auto_setup_scope = true;
    ret = bind_class;
  } else if (0 == strcmp(c_name, "GodotDartNativeBindings::gdStringToString")) {
    *auto_setup_scope = true;
    ret = gd_string_to_dart_string;
  } else if (0 == strcmp(c_name, "GodotDartNativeBindings::gdObjectToDartObject")) {
    *auto_setup_scope = true;
    ret = gd_object_to_dart_object;
  }

  Dart_ExitScope();
  return ret;
}