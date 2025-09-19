/// This file contains the C functions that Dart will call into.
/// The Dart bindings for these are contained in dart_binding_c_interface.dart
#include <dart_api.h>

#include "dart_bindings.h"
#include "dart_helpers.h"
#include "gde_wrapper.h"
#include "godot_string_wrappers.h"
#include "script/dart_script_instance.h"
#include "script/dart_script_language.h"

/* Static Functions From Dart */
extern "C" {

GDE_EXPORT void dart_print(Dart_Handle d_string) {
  const char *cstring;
  DART_CHECK(result, Dart_StringToCString(d_string, &cstring), "Error getting printable string.");

  __print(cstring);
}

GDE_EXPORT void bind_class(Dart_Handle type_info) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    Dart_ThrowException(Dart_NewStringFromCString("GodotDart has been shutdown!"));
    return;
  }

  Dart_Handle dstr_class_name = Dart_NewStringFromCString("className");

  // className is a StringName and we can get its opaque addresses
  Dart_Handle name = Dart_GetField(type_info, dstr_class_name);
  void *sn_name = get_object_address(name);
  if (sn_name == nullptr) {
    return;
  }

  DART_CHECK(parent_type_info, Dart_GetField(type_info, Dart_NewStringFromCString("parentTypeInfo")), "Failed getting parent type info");
  DART_CHECK(parent_type_name, Dart_GetField(parent_type_info, Dart_NewStringFromCString("className")), "Failed getting parent class name");
  void *sn_parent = get_object_address(parent_type_name);
  if (sn_parent == nullptr) {
    return;
  }

  GDExtensionClassCreationInfo2 info = {0};
  info.is_exposed = true;
  info.class_userdata = (void *)Dart_NewPersistentHandle(type_info);
  info.create_instance_func = GodotDartBindings::class_create_instance;
  info.free_instance_func = GodotDartBindings::class_free_instance;
  info.get_virtual_call_data_func = GodotDartBindings::get_virtual_call_data;
  info.call_virtual_with_data_func = GodotDartBindings::call_virtual_func;
  // This is handled by instance bindings, not by the type info. See __engine_binding_reference_callback
  //info.reference_func = GodotDartBindings::reference;
  //info.unreference_func = GodotDartBindings::unreference;

  gde_classdb_register_extension_class2(GDEWrapper::instance()->get_library_ptr(), sn_name, sn_parent, &info);
}

GDE_EXPORT void bind_method(Dart_Handle dart_type_info, Dart_Handle method_info) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    Dart_ThrowException(Dart_NewStringFromCString("GodotDart has been shutdown!"));
    return;
  }

  bindings->bind_method(dart_type_info, method_info);
}

GDE_EXPORT void add_property(Dart_Handle d_bind_type_info, Dart_Handle d_property_info) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    Dart_ThrowException(Dart_NewStringFromCString("GodotDart has been shutdown!"));
    return;
  }

  // TODO: Add property
  /*TypeInfo bind_type_info;
  type_info_from_dart(&bind_type_info, d_bind_type_info);

  bindings->add_property(bind_type_info, d_property_info);*/
}

GDE_EXPORT Dart_Handle gd_string_to_dart_string(void *string_ptr) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    Dart_ThrowException(Dart_NewStringFromCString("GodotDart has been shutdown!"));
    return Dart_Null();
  }

  if (!string_ptr) {
    return Dart_Null();
  }

  const godot::String *gd_string = reinterpret_cast<godot::String *>(string_ptr);

  return to_dart_string(*gd_string);
}

GDE_EXPORT Dart_Handle gd_object_to_dart_object(void *object_ptr) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    Dart_ThrowException(Dart_NewStringFromCString("GodotDart has been shutdown!"));
    return Dart_Null();
  }

  if (object_ptr == 0) {
    return Dart_Null();
  }

  DartBlockScope scope;

  GDEWrapper *gde = GDEWrapper::instance();
  GDExtensionScriptInstanceDataPtr script_instance = gde_object_get_script_instance(
      reinterpret_cast<GDExtensionObjectPtr>(object_ptr), DartScriptLanguage::instance()->_owner);
  if (script_instance) {
    Dart_Handle obj = reinterpret_cast<DartScriptInstance *>(script_instance)->get_dart_object();
    return obj;
  }

  DartGodotInstanceBinding *binding = (DartGodotInstanceBinding *)gde_object_get_instance_binding(
      reinterpret_cast<GDExtensionObjectPtr>(object_ptr), bindings,
      &DartGodotInstanceBinding::engine_binding_callbacks);
  if (binding == nullptr) {
    return Dart_Null();
  }

  Dart_Handle obj = binding->get_dart_object();
  if (Dart_IsError(obj)) {
    GD_PRINT_ERROR(Dart_GetError(obj));
    Dart_ThrowException(Dart_NewStringFromCString(Dart_GetError(obj)));
    return Dart_Null();
  }
  return obj;
}

GDE_EXPORT void set_type_resolver(Dart_Handle resolver) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    Dart_ThrowException(Dart_NewStringFromCString("GodotDart has been shutdown!"));
    return;
  }

  bindings->set_type_resolver(resolver);

  DartScriptLanguage *script_language = DartScriptLanguage::instance();
  if (!script_language) {
    Dart_ThrowException(Dart_NewStringFromCString("GodotDart has been shutdown!"));
    return;
  }

  script_language->attach_type_resolver(resolver);
}

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

  DART_CHECK(class_name, Dart_GetField(d_class_type_info, Dart_NewStringFromCString("className")),
             "Failed to get className!");

  const GDExtensionInstanceBindingCallbacks *callbacks = &DartGodotInstanceBinding::engine_binding_callbacks;
  DartGodotInstanceBinding *binding =
      (DartGodotInstanceBinding *)gde_object_get_instance_binding(godot_object, bindings, callbacks);
  if (!binding->is_initialized()) {
    binding->initialize(dart_object, is_refcounted);
  }

  if (!is_godot_defined) {
    gde_object_set_instance(godot_object, get_object_address(class_name), binding);
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

GDE_EXPORT void call_dart_signal(void *callable_userdata, const GDExtensionConstVariantPtr *p_args,
                                 GDExtensionInt p_argument_count, GDExtensionVariantPtr r_return,
                                 GDExtensionCallError *r_error) {
  GodotDartBindings *bindings = GodotDartBindings::instance();

  bindings->execute_on_dart_thread([&] {
    DartBlockScope scope;

    Dart_Handle signal = Dart_HandleFromPersistent((Dart_PersistentHandle)callable_userdata);
    Dart_Handle convert_args[] = {Dart_NewInteger(int64_t(p_args)), Dart_NewInteger(p_argument_count)};
    DART_CHECK(
        signal_args,
        Dart_Invoke(bindings->_native_library, Dart_NewStringFromCString("_variantsToDartVariants"), 2, convert_args));    

    Dart_Handle args[] = {signal_args};
    Dart_Handle result = Dart_Invoke(signal, Dart_NewStringFromCString("call"), 1, args);
    if (Dart_IsError(result)) {
      GD_PRINT_ERROR("GodotDart: Error performing signal call: ");
      GD_PRINT_ERROR(Dart_GetError(result));
      *r_error = GDExtensionCallError{
          GDEXTENSION_CALL_ERROR_INVALID_METHOD,
          0,
          0,
      };
    } else {
      *r_error = GDExtensionCallError{GDEXTENSION_CALL_OK, 0, 0};
    }
  });
}

GDExtensionInt get_signal_argument_count(void *callable_userdata, GDExtensionBool *r_is_valid) {
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

void free_dart_signal(void *callable_userdata) {
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
  DART_CHECK_RET(dart_callable,
                 bindings->new_object_copy(Dart_NewStringFromCString("Callable"), callable._native_ptr()), Dart_Null(),
                 "Could not create Dart Callable.");

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
