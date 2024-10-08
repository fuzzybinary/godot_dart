#pragma once

#include <dart_api.h>

#include <godot_cpp/classes/script_extension.hpp>
#include <godot_cpp/classes/script_language.hpp>

class DartScript : public godot::ScriptExtension {
  GDCLASS(DartScript, ScriptExtension);

public:
  DartScript();
  ~DartScript();

  bool _editor_can_reload_from_file() override {
    return false;
  }
  godot::Ref<Script> _get_base_script() const override;
  godot::ScriptLanguage *_get_language() const override;
  void _set_source_code(const godot::String& code);
  godot::String _get_source_code() const override;
  bool _has_source_code() const override;
  bool _can_instantiate() const override;
  bool _has_method(const godot::StringName &method) const override;
  bool _has_static_method(const godot::StringName &method) const override;
  godot::Dictionary _get_method_info(const godot::StringName &method) const override;
  bool _is_valid() const override;
  bool _has_script_signal(const godot::StringName &signal) const override;
  godot::TypedArray<godot::Dictionary> _get_script_signal_list() const override;
  godot::TypedArray<godot::Dictionary> _get_script_method_list() const override;
  godot::TypedArray<godot::Dictionary> _get_script_property_list() const override;
  godot::Error _reload(bool keep_state) override;
  bool _is_tool() const override;
  godot::StringName _get_instance_base_type() const override;
  godot::TypedArray<godot::Dictionary> _get_documentation() const override;
  bool _has_property_default_value(const godot::StringName &property) const override;
  godot::Variant _get_property_default_value(const godot::StringName &property) const override;
  godot::StringName _get_global_name() const override;


  void load_from_disk(const godot::String &path);

  void *_instance_create(Object *for_object) const override;
  void *_placeholder_instance_create(Object *for_object) const override;
	

protected:
  static void _bind_methods();

private:
  // Not actually const
  void refresh_type() const;

  godot::String _source_code;
  godot::String _path;
  mutable bool _needs_refresh;
  mutable godot::Ref<DartScript> _base_script;
  mutable Dart_PersistentHandle _dart_type;
  mutable Dart_PersistentHandle _script_info;
};