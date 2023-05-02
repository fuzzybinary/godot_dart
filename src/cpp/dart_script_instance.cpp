#include "dart_script_instance.h"

bool DartScriptInstance::set(const GDStringName &p_name, GDExtensionConstVariantPtr p_value) {
  return false;
}

bool DartScriptInstance::get(const GDStringName &p_name, GDExtensionTypePtr r_ret) {
  return false;
}

const GDExtensionPropertyInfo *DartScriptInstance::get_property_list(uint32_t *r_count) {
  return nullptr;
}

void DartScriptInstance::free_property_list(const GDExtensionPropertyInfo *p_list) {
}

GDExtensionVariantType DartScriptInstance::get_property_type(const GDStringName &p_name, GDExtensionBool *r_is_valid) {
  return GDExtensionVariantType();
}

GDExtensionBool DartScriptInstance::property_can_revert(const GDStringName &p_name) {
  return GDExtensionBool();
}

GDExtensionBool DartScriptInstance::property_get_revert(const GDStringName &p_name, GDExtensionVariantPtr r_ret) {
  return GDExtensionBool();
}

GDExtensionObjectPtr DartScriptInstance::get_owner() {
  return GDExtensionObjectPtr();
}

void DartScriptInstance::get_property_state(GDExtensionScriptInstancePropertyStateAdd p_add_func, void *p_userdata) {
}

const GDExtensionMethodInfo *DartScriptInstance::get_method_list(uint32_t *r_count) {
  return nullptr;
}

void DartScriptInstance::free_method_list(const GDExtensionMethodInfo *p_list) {
}

GDExtensionBool DartScriptInstance::has_method(const GDStringName &p_name) {
  return GDExtensionBool();
}

void DartScriptInstance::call(const GDStringName &p_method, const GDExtensionConstVariantPtr *p_args,
                              GDExtensionInt p_argument_count, GDExtensionVariantPtr r_return,
                              GDExtensionCallError *r_error) {
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
  return GDExtensionObjectPtr();
}

GDExtensionBool DartScriptInstance::is_placeholder() {
  return GDExtensionBool();
}

bool DartScriptInstance::set_fallback(const GDStringName &p_name, GDExtensionConstVariantPtr p_value) {
  return false;
}

bool DartScriptInstance::get_fallback(const GDStringName &p_name, GDExtensionTypePtr r_ret) {
  return false;
}

GDExtensionScriptLanguagePtr DartScriptInstance::get_language() {
  return GDExtensionScriptLanguagePtr();
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
  instance->call(*gd_method, p_args, p_argument_count, r_return, r_error);
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