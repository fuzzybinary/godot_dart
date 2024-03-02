#pragma once

#include <gdextension_interface.h>
#include <godot_cpp/classes/ref_counted.hpp>

#include "dart_instance_binding.h"
#include "script/dart_script.h"
#include "godot_string_wrappers.h"

class DartScript;

class DartScriptInstance {
public:
  DartScriptInstance(Dart_Handle for_object, godot::Ref<DartScript> script, GDExtensionObjectPtr owner, bool is_placeholder,
                     bool is_refcounted);
  ~DartScriptInstance();

  bool set(const godot::StringName &p_name, GDExtensionConstVariantPtr p_value);
  bool get(const godot::StringName &p_name, GDExtensionVariantPtr r_ret);
  bool get_class_category(GDExtensionPropertyInfo *p_class_category);

  const GDExtensionPropertyInfo *get_property_list(uint32_t *r_count);
  void free_property_list(const GDExtensionPropertyInfo *p_list);
  GDExtensionVariantType get_property_type(const godot::StringName &p_name, GDExtensionBool *r_is_valid);
  bool validate_property(GDExtensionPropertyInfo *p_property);

  GDExtensionBool property_can_revert(const godot::StringName &p_name);
  GDExtensionBool property_get_revert(const godot::StringName &p_name, GDExtensionVariantPtr r_ret);

  GDExtensionObjectPtr get_owner();
  void get_property_state(GDExtensionScriptInstancePropertyStateAdd p_add_func, void *p_userdata);

  const GDExtensionMethodInfo *get_method_list(uint32_t *r_count);
  void free_method_list(const GDExtensionMethodInfo *p_list);

  GDExtensionBool has_method(const godot::StringName &p_name);

  void call(const godot::StringName *p_method, const GDExtensionConstVariantPtr *p_args,
            GDExtensionInt p_argument_count,
            GDExtensionVariantPtr r_return, GDExtensionCallError *r_error);
  void notification(int32_t p_what, bool p_reversed);
  void to_string(GDExtensionBool *r_is_valid, GDExtensionStringPtr r_out);

  void ref_count_incremented();
  GDExtensionBool ref_count_decremented();

  GDExtensionObjectPtr get_script();
  GDExtensionBool is_placeholder();

  bool set_fallback(const godot::StringName &p_name, GDExtensionConstVariantPtr p_value);
  bool get_fallback(const godot::StringName &p_name, GDExtensionVariantPtr r_ret);

  GDExtensionScriptLanguagePtr get_language();

  Dart_Handle get_dart_object() {
    return _binding.get_dart_object();
  }

  static const GDExtensionScriptInstanceInfo2 *get_script_instance_info();

  static std::map<intptr_t, DartScriptInstance*> s_instanceMap; 

  DartGodotInstanceBinding _binding;

private:
  bool _is_placeholder;

  godot::Ref<DartScript> _dart_script;
  GDExtensionObjectPtr _godot_script_obj;

  static GDExtensionScriptInstanceInfo2 script_instance_info;
};