#include "dart_script_instance.h"

#include <dart_api.h>

#include "dart_bindings.h"
#include "gde_wrapper.h"

DartScriptInstance::DartScriptInstance(Dart_Handle for_object, Dart_Handle script, GDExtensionObjectPtr owner)
  : _godot_script_obj(nullptr) {
  _dart_object = Dart_NewPersistentHandle(for_object);
  _dart_script = Dart_NewPersistentHandle(script);
  _owner = owner;
}

DartScriptInstance::~DartScriptInstance() {
  GodotDartBindings* gde = GodotDartBindings::instance();
  if (gde != nullptr) {
    gde->execute_on_dart_thread([&] {
      Dart_DeletePersistentHandle(_dart_object);
      Dart_DeletePersistentHandle(_dart_script);
    });
  }
}

bool DartScriptInstance::set(const GDStringName &p_name, GDExtensionConstVariantPtr p_value) {
  return false;
}

bool DartScriptInstance::get(const GDStringName &p_name, GDExtensionTypePtr r_ret) {
  return false;
}

const GDExtensionPropertyInfo *DartScriptInstance::get_property_list(uint32_t *r_count) {
  *r_count = 0;
  return nullptr;
}

void DartScriptInstance::free_property_list(const GDExtensionPropertyInfo *p_list) {
}

GDExtensionVariantType DartScriptInstance::get_property_type(const GDStringName &p_name, GDExtensionBool *r_is_valid) {
  return GDExtensionVariantType();
}

GDExtensionBool DartScriptInstance::property_can_revert(const GDStringName &p_name) {
  return false;
}

GDExtensionBool DartScriptInstance::property_get_revert(const GDStringName &p_name, GDExtensionVariantPtr r_ret) {
  return false;
}

GDExtensionObjectPtr DartScriptInstance::get_owner() {
  return _owner;
}

void DartScriptInstance::get_property_state(GDExtensionScriptInstancePropertyStateAdd p_add_func, void *p_userdata) {
}

const GDExtensionMethodInfo *DartScriptInstance::get_method_list(uint32_t *r_count) {
  return nullptr;
}

void DartScriptInstance::free_method_list(const GDExtensionMethodInfo *p_list) {
}

GDExtensionBool DartScriptInstance::has_method(const GDStringName &p_name) {
  GodotDartBindings *gde = GodotDartBindings::instance();
  if (gde == nullptr) {
    return false;
  }

  bool hasMethod = false;
  gde->execute_on_dart_thread([&] {
    Dart_EnterScope();

    Dart_Handle dart_obj = Dart_HandleFromPersistent(_dart_object);

    Dart_Handle method_info_args[] = {p_name.to_dart()};
    DART_CHECK(method_info, Dart_Invoke(dart_obj, Dart_NewStringFromCString("getMethodInfo"), 1, method_info_args),
               "Failed getting method");

    hasMethod = !Dart_IsNull(method_info);
  });

  return hasMethod;
}

void DartScriptInstance::call(const GDStringName* p_method, const GDExtensionConstVariantPtr *p_args,
                              GDExtensionInt p_argument_count, GDExtensionVariantPtr r_return,
                              GDExtensionCallError *r_error) {
  GodotDartBindings *gde = GodotDartBindings::instance();
  if (gde == nullptr) {
    return;
  }

  gde->execute_on_dart_thread([&] {
    DartBlockScope scope;

    Dart_Handle dart_obj = Dart_HandleFromPersistent(_dart_object);
    
    Dart_Handle method_info_args[] = {p_method->to_dart()};
    DART_CHECK(method_info, Dart_Invoke(dart_obj, Dart_NewStringFromCString("getMethodInfo"), 1, method_info_args), "Failed getting method");
    if (Dart_IsNull(method_info)) {
      return;
    }

    DART_CHECK(dart_method_name, Dart_GetField(method_info, Dart_NewStringFromCString("dartMethodName")), "Failed getting dart method name");
    if (Dart_IsNull(dart_method_name)) {
      dart_method_name = Dart_GetField(method_info, Dart_NewStringFromCString("methodName"));
    }
    DART_CHECK(args_list, Dart_GetField(method_info, Dart_NewStringFromCString("arguments")), "Failed getting method arguments");
    intptr_t arg_count = 0;
    Dart_ListLength(args_list, &arg_count);

    Dart_Handle *dart_args = nullptr;
    if (arg_count != 0) {
      dart_args = new Dart_Handle[arg_count];
      Dart_Handle args_address = Dart_NewInteger(reinterpret_cast<intptr_t>(p_args));
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
        // TODO: Need a better way to do this. Replace references with proper references
        Dart_Handle type_info = Dart_ListGetAt(args_list, i);
        Dart_Handle d_is_reference = Dart_GetField(type_info, Dart_NewStringFromCString("isReference"));
        bool is_reference = false;
        Dart_BooleanValue(d_is_reference, &is_reference);
        if (is_reference) {
          DART_CHECK(inner_type, Dart_GetField(type_info, Dart_NewStringFromCString("type")), "Failed getting className");
          DART_CHECK(type_args, Dart_NewList(1), "ASDGARGAEg");
          Dart_ListSetAt(type_args, 0, inner_type);
          DART_CHECK(ref_type,
                     Dart_GetNonNullableType(gde->_godot_dart_library, Dart_NewStringFromCString("Ref"), 1, &type_args),
                     "Failed finding Ref type");
          Dart_Handle constructor_args[] {
            Dart_ListGetAt(dart_converted_arg_list, i)
          };
          dart_args[i] = Dart_New(ref_type, Dart_Null(), 1, constructor_args);
        } else {
          dart_args[i] = Dart_ListGetAt(dart_converted_arg_list, i);
        }
      }
    }

    DART_CHECK(dart_ret, Dart_Invoke(dart_obj, dart_method_name, arg_count, dart_args));
    Dart_Handle native_library = Dart_HandleFromPersistent(gde->_native_library);
    Dart_Handle args[] = {dart_ret};
    Dart_Handle variant_result = Dart_Invoke(native_library, Dart_NewStringFromCString("_convertToVariant"), 1, args);
    
    if (Dart_IsError(variant_result)) {
      GD_PRINT_ERROR("GodotDart: Error converting return to variant: ");
      GD_PRINT_ERROR(Dart_GetError(variant_result));
    } else {
      void *variantDataPtr = get_opaque_address(variant_result);
      if (variantDataPtr) {
        GDE->variant_new_copy(r_return, reinterpret_cast<GDExtensionConstVariantPtr>(variantDataPtr));
      }
    }

    // TODO - these leak on error
    if (dart_args != nullptr) {
      delete[] dart_args;
    }
  });
}

void DartScriptInstance::notification(int32_t p_what) {
}

void DartScriptInstance::to_string(GDExtensionBool *r_is_valid, GDExtensionStringPtr r_out) {
}

void DartScriptInstance::ref_count_incremented() {
}

GDExtensionBool DartScriptInstance::ref_count_decremented() {
  return GDExtensionBool();
}

GDExtensionObjectPtr DartScriptInstance::get_script() {
  if (_godot_script_obj == nullptr) {
    GodotDartBindings::instance()->execute_on_dart_thread([&] {
      DartBlockScope scope;

      Dart_Handle dart_script_obj = Dart_HandleFromPersistent(_dart_script);

      DART_CHECK(obj_native_ptr, Dart_GetField(dart_script_obj, Dart_NewStringFromCString("nativePtr")),
                 "Failed getting nativePtr for Script");
      Dart_Handle address = Dart_GetField(obj_native_ptr, Dart_NewStringFromCString("address"));
      if (Dart_IsError(address)) {
        GD_PRINT_ERROR(Dart_GetError(address));
      }
      uint64_t obj_ptr = 0;
      Dart_IntegerToUint64(address, &obj_ptr);
      _godot_script_obj = reinterpret_cast<GDExtensionObjectPtr>(obj_ptr);
    });
  }

  return _godot_script_obj;
}

GDExtensionBool DartScriptInstance::is_placeholder() {
  return false;
}

bool DartScriptInstance::set_fallback(const GDStringName &p_name, GDExtensionConstVariantPtr p_value) {
  return false;
}

bool DartScriptInstance::get_fallback(const GDStringName &p_name, GDExtensionTypePtr r_ret) {
  return false;
}

GDExtensionScriptLanguagePtr DartScriptInstance::get_language() {

  return nullptr;
}

// * Static Callback Functions for Godot */

GDExtensionBool script_instance_set(GDExtensionScriptInstanceDataPtr p_instance, GDExtensionConstStringNamePtr p_name,
                                    GDExtensionConstVariantPtr p_value) {
  const GDStringName *gd_name = reinterpret_cast<const GDStringName *>(p_name);
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->set(*gd_name, p_value);
}

GDExtensionBool script_instance_get(GDExtensionScriptInstanceDataPtr p_instance, GDExtensionConstStringNamePtr p_name,
                                    GDExtensionVariantPtr r_ret) {
  const GDStringName *gd_name = reinterpret_cast<const GDStringName *>(p_name);
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->get(*gd_name, r_ret);
}

const GDExtensionPropertyInfo *script_instance_get_property_list(GDExtensionScriptInstanceDataPtr p_instance,
                                                                 uint32_t *r_count) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->get_property_list(r_count);
}

void script_instance_free_property_list(GDExtensionScriptInstanceDataPtr p_instance,
                                        const GDExtensionPropertyInfo *p_list) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  instance->free_property_list(p_list);
}

GDExtensionVariantType script_instance_get_property_type(GDExtensionScriptInstanceDataPtr p_instance,
                                                         GDExtensionConstStringNamePtr p_name,
                                                         GDExtensionBool *r_is_valid) {
  const GDStringName *gd_name = reinterpret_cast<const GDStringName *>(p_name);
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->get_property_type(*gd_name, r_is_valid);
}

GDExtensionBool script_instance_property_can_revert(GDExtensionScriptInstanceDataPtr p_instance,
                                                    GDExtensionConstStringNamePtr p_name) {
  const GDStringName *gd_name = reinterpret_cast<const GDStringName *>(p_name);
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->property_can_revert(*gd_name);
}

GDExtensionBool script_instance_property_get_revert(GDExtensionScriptInstanceDataPtr p_instance,
                                                    GDExtensionConstStringNamePtr p_name, GDExtensionVariantPtr r_ret) {
  const GDStringName *gd_name = reinterpret_cast<const GDStringName *>(p_name);
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->property_get_revert(*gd_name, r_ret);
}

GDExtensionObjectPtr script_instance_get_owner(GDExtensionScriptInstanceDataPtr p_instance) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->get_owner();
}

void script_instance_get_property_state(GDExtensionScriptInstanceDataPtr p_instance,
                                        GDExtensionScriptInstancePropertyStateAdd p_add_func, void *p_userdata) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  instance->get_property_state(p_add_func, p_userdata);
}

const GDExtensionMethodInfo *script_instance_get_method_list(GDExtensionScriptInstanceDataPtr p_instance,
                                                             uint32_t *r_count) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->get_method_list(r_count);
}

void script_instance_free_method_list(GDExtensionScriptInstanceDataPtr p_instance,
                                      const GDExtensionMethodInfo *p_list) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  instance->free_method_list(p_list);
}

GDExtensionBool script_instance_has_method(GDExtensionScriptInstanceDataPtr p_instance,
                                           GDExtensionConstStringNamePtr p_name) {
  const GDStringName *gd_name = reinterpret_cast<const GDStringName *>(p_name);
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->has_method(*gd_name);
}

void script_instance_call(GDExtensionScriptInstanceDataPtr p_self, GDExtensionConstStringNamePtr p_method,
                          const GDExtensionConstVariantPtr *p_args, GDExtensionInt p_argument_count,
                          GDExtensionVariantPtr r_return, GDExtensionCallError *r_error) {
  const GDStringName *gd_method = reinterpret_cast<const GDStringName *>(p_method);
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_self);
  instance->call(gd_method, p_args, p_argument_count, r_return, r_error);
}

void script_instance_notification(GDExtensionScriptInstanceDataPtr p_instance, int32_t p_what) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  instance->notification(p_what);
}

void script_instance_to_string(GDExtensionScriptInstanceDataPtr p_instance, GDExtensionBool *r_is_valid,
                               GDExtensionStringPtr r_out) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  instance->to_string(r_is_valid, r_out);
}

void script_instance_ref_count_incremented(GDExtensionScriptInstanceDataPtr p_instance) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  instance->ref_count_incremented();
}

GDExtensionBool script_instance_ref_count_decremented(GDExtensionScriptInstanceDataPtr p_instance) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->ref_count_decremented();
}

GDExtensionObjectPtr script_instance_get_script(GDExtensionScriptInstanceDataPtr p_instance) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->get_script();
}

GDExtensionBool script_instance_is_placeholder(GDExtensionScriptInstanceDataPtr p_instance) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->is_placeholder();
}

GDExtensionBool script_instance_set_fallback(GDExtensionScriptInstanceDataPtr p_instance,
                                             GDExtensionConstStringNamePtr p_name, GDExtensionConstVariantPtr p_value) {
  const GDStringName *gd_name = reinterpret_cast<const GDStringName *>(p_name);
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->set_fallback(*gd_name, p_value);
}

GDExtensionBool script_instance_get_fallback(GDExtensionScriptInstanceDataPtr p_instance,
                                             GDExtensionConstStringNamePtr p_name, GDExtensionVariantPtr r_ret) {
  const GDStringName *gd_name = reinterpret_cast<const GDStringName *>(p_name);
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->get_fallback(*gd_name, r_ret);
}

GDExtensionScriptLanguagePtr script_instance_get_language(GDExtensionScriptInstanceDataPtr p_instance) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->get_language();
}

void script_instance_free(GDExtensionScriptInstanceDataPtr p_instance) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  delete instance;
}

const GDExtensionScriptInstanceInfo *DartScriptInstance::get_script_instance_info() {
  return &script_instance_info;
}

GDExtensionScriptInstanceInfo DartScriptInstance::script_instance_info = {
    script_instance_set,
    script_instance_get,
    script_instance_get_property_list,
    script_instance_free_property_list,
    script_instance_property_can_revert,
    script_instance_property_get_revert,
    script_instance_get_owner,
    script_instance_get_property_state,
    script_instance_get_method_list,
    script_instance_free_method_list,
    script_instance_get_property_type,
    script_instance_has_method,
    script_instance_call,
    script_instance_notification,
    script_instance_to_string,
    script_instance_ref_count_incremented,
    script_instance_ref_count_decremented,
    script_instance_get_script,
    script_instance_is_placeholder,
    script_instance_set_fallback,
    script_instance_get_fallback,
    script_instance_get_language,
    script_instance_free,
};