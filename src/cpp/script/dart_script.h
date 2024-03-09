#pragma once

#include <dart_api.h>

#include <godot_cpp/classes/script_extension.hpp>
#include <godot_cpp/classes/script_language.hpp>

class DartScript : public godot::ScriptExtension {
  GDCLASS(DartScript, ScriptExtension);

public:
  DartScript();
  ~DartScript();

  virtual godot::Ref<Script> _get_base_script() const override;
  virtual godot::ScriptLanguage *_get_language() const override;
  virtual void _set_source_code(const godot::String& code);
  virtual godot::String _get_source_code() const override;
  virtual bool _has_source_code() const override;
  virtual bool _can_instantiate() const override;
  virtual bool _has_method(const godot::StringName &method) const override;
  virtual bool _has_static_method(const godot::StringName &method) const override;
  virtual godot::Dictionary _get_method_info(const godot::StringName &method) const override;
  virtual bool _is_valid() const override;
  virtual bool _has_script_signal(const godot::StringName &signal) const override;
  virtual godot::TypedArray<godot::Dictionary> _get_script_signal_list() const override;
  virtual godot::TypedArray<godot::Dictionary> _get_script_method_list() const override;
  virtual godot::TypedArray<godot::Dictionary> _get_script_property_list() const override;
  virtual godot::Error _reload(bool keep_state) override;
  virtual bool _is_tool() const override;
  virtual godot::StringName _get_instance_base_type() const override;
  virtual godot::TypedArray<godot::Dictionary> _get_documentation() const override;
  virtual bool _has_property_default_value(const godot::StringName &property) const override;
  virtual godot::Variant _get_property_default_value(const godot::StringName &property) const override;
  virtual godot::StringName _get_global_name() const override;


  void load_from_disk(const godot::String &path);

  virtual void *_instance_create(Object *for_object) const override;
  virtual void *_placeholder_instance_create(Object *for_object) const override;
	

protected:
  static void _bind_methods();

private:
  // Not actually const
  void refresh_type() const;

  godot::String _source_code;
  mutable godot::Ref<DartScript> _base_script;
  mutable Dart_PersistentHandle _dart_type;
  mutable Dart_PersistentHandle _script_info;
};