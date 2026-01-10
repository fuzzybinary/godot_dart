#pragma once

#include <optional>

#include <gdextension_interface.h>
#include <godot_cpp/classes/ref_counted.hpp>

#include "dart_instance_binding.h"
#include "godot_string_wrappers.h"
#include "script/dart_script.h"

class DartScript;

class DartScriptInstance {
public:
  DartScriptInstance(godot::Ref<DartScript> script, godot::Object *owner, bool is_placeholder, bool is_refcounted);
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
            GDExtensionInt p_argument_count, GDExtensionVariantPtr r_return, GDExtensionCallError *r_error);
  void notification(int32_t p_what, bool p_reversed);
  void to_string(GDExtensionBool *r_is_valid, GDExtensionStringPtr r_out);

  void ref_count_incremented();
  GDExtensionBool ref_count_decremented();

  GDExtensionObjectPtr get_script();
  GDExtensionBool is_placeholder();

  DartScript *get_dart_script() {
    return _dart_script.ptr();
  }

  bool set_fallback(const godot::StringName &p_name, GDExtensionConstVariantPtr p_value);
  bool get_fallback(const godot::StringName &p_name, GDExtensionVariantPtr r_ret);

  GDExtensionScriptLanguagePtr get_language();

  void notify_property_list_changed();

  Dart_Handle get_dart_object();
  GDExtensionObjectPtr get_godot_object() {
    if (_binding.has_value()) {
      return _binding->get_godot_object();
    }
    return nullptr;
  }

  static const GDExtensionScriptInstanceInfo2 *get_script_instance_info();

  static std::map<intptr_t, DartScriptInstance *> s_instanceMap;

private:
  Dart_Handle create_dart_object();

  bool _is_placeholder;
  bool _is_refcounted;

  std::optional<DartGodotInstanceBinding> _binding;

  godot::Ref<DartScript> _dart_script;
  godot::Object *_godot_object;

  static GDExtensionScriptInstanceInfo2 script_instance_info;
};