#pragma once

#include <godot/gdextension_interface.h>

#include "godot_string_wrappers.h"

class DartScriptInstance {
public:
  DartScriptInstance();

  bool set(const GDStringName &p_name, GDExtensionConstVariantPtr p_value);
  bool get(const GDStringName &p_name, GDExtensionTypePtr r_ret);

  const GDExtensionPropertyInfo *get_property_list(uint32_t *r_count);
  void free_property_list(const GDExtensionPropertyInfo *p_list);
  GDExtensionVariantType get_property_type(const GDStringName &p_name, GDExtensionBool *r_is_valid);

  GDExtensionBool property_can_revert(const GDStringName &p_name);
  GDExtensionBool property_get_revert(const GDStringName &p_name, GDExtensionVariantPtr r_ret);

  GDExtensionObjectPtr get_owner();  
  void get_property_state(GDExtensionScriptInstancePropertyStateAdd p_add_func, void *p_userdata);

  const GDExtensionMethodInfo *get_method_list(uint32_t *r_count);
  void free_method_list(const GDExtensionMethodInfo *p_list);

  GDExtensionBool has_method(const GDStringName &p_name);

  void call(const GDStringName &p_method, const GDExtensionConstVariantPtr *p_args, GDExtensionInt p_argument_count, 
    GDExtensionVariantPtr r_return, GDExtensionCallError *r_error);
  void notification(int32_t p_what);
  void to_string(GDExtensionBool *r_is_valid, GDExtensionStringPtr r_out);

  void ref_count_incremented();
  GDExtensionBool ref_count_decremented();

  GDExtensionObjectPtr get_script();
  GDExtensionBool is_placeholder();

  bool set_fallback(const GDStringName &p_name, GDExtensionConstVariantPtr p_value);
  bool get_fallback(const GDStringName &p_name, GDExtensionTypePtr r_ret);

  GDExtensionScriptLanguagePtr get_language();

  static const GDExtensionScriptInstanceInfo* get_script_instance_info();

private:
  static GDExtensionScriptInstanceInfo script_instance_info;
};