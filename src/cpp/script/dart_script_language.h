#pragma once

#include <dart_api.h>
#include <godot_cpp/classes/script_language_extension.hpp>

class DartScriptLanguage : public godot::ScriptLanguageExtension {
  GDCLASS(DartScriptLanguage, godot::ScriptLanguageExtension);

public:
  DartScriptLanguage();

  virtual void _thread_enter() override;
  virtual void _thread_exit() override;
  virtual void _init() override;
  virtual godot::String _get_name() const override;
  virtual godot::String _get_type() const override;
  virtual godot::String _get_extension() const override;
  virtual void _frame() override;
  virtual bool _handles_global_class_type(const godot::String &type) const override;

  virtual bool _has_named_classes() const override {
    return true;
  }

  virtual godot::String _validate_path(const godot::String &path) const override;
  virtual godot::Object *_create_script() const override;
  virtual godot::Ref<godot::Script> _make_template(const godot::String &_template, const godot::String &class_name,
                                                   const godot::String &base_class_name) const override;

  virtual godot::PackedStringArray _get_recognized_extensions() const override;
  virtual godot::String _auto_indent_code(godot::String code, int fromLine, int toLine);

  void attach_script_resolver(Dart_Handle resolver);
  Dart_Handle get_type_for_script(const godot::String &path) const;

  static DartScriptLanguage *instance();

protected:
  static void _bind_methods();

private:
  static DartScriptLanguage *s_instance;

  Dart_PersistentHandle _script_resolver;
};