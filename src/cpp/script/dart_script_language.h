#pragma once

#include <map>

#include <dart_api.h>
#include <godot_cpp/classes/script_language_extension.hpp>
#include "dart_script.h"

class DartScriptLanguage : public godot::ScriptLanguageExtension {
  GDCLASS(DartScriptLanguage, godot::ScriptLanguageExtension);

public:
  DartScriptLanguage();

  void shutdown();

  virtual void _thread_enter() override;
  virtual void _thread_exit() override;
  virtual void _init() override;
  virtual godot::String _get_name() const override;
  virtual godot::String _get_type() const override;
  virtual godot::String _get_extension() const override;
  virtual void _frame() override;
  virtual bool _handles_global_class_type(const godot::String &type) const override;
  virtual godot::Dictionary _get_global_class_name(const godot::String &path) const override;
  virtual bool _overrides_external_editor() override;
  virtual godot::PackedStringArray _get_string_delimiters() const override;
  virtual godot::PackedStringArray _get_comment_delimiters() const override;
  virtual godot::PackedStringArray _get_doc_comment_delimiters() const override;
  virtual godot::Dictionary _validate(const godot::String &script, const godot::String &path, bool validate_functions,
                                      bool validate_errors, bool validate_warnings,
                                      bool validate_safe_lines) const override;
  virtual godot::PackedStringArray _get_reserved_words() const override;
  virtual bool _is_control_flow_keyword(const godot::String& keyword) const override;

  virtual bool _has_named_classes() const override {
    return true;
  }

  virtual godot::String _validate_path(const godot::String &path) const override;
  virtual godot::Object *_create_script() const override;
  virtual godot::Ref<godot::Script> _make_template(const godot::String &_template, const godot::String &class_name,
                                                   const godot::String &base_class_name) const override;

  virtual godot::PackedStringArray _get_recognized_extensions() const override;
  virtual godot::String _auto_indent_code(godot::String code, int fromLine, int toLine);

  void attach_type_resolver(Dart_Handle resolver);
  Dart_Handle get_type_for_script(const godot::String &path) const;
  godot::String get_script_for_type(Dart_Handle dart_type) const;

  godot::Ref<DartScript> get_cached_script(const godot::String& path);
  void push_cached_script(const godot::String &path, godot::Ref<DartScript> script);
  godot::Ref<DartScript> find_script_for_type(Dart_Handle dart_type);

  static DartScriptLanguage *instance();

protected:
  static void _bind_methods();

private:
  static DartScriptLanguage *s_instance;

  std::map<godot::String, godot::Ref<DartScript>> _script_cache;
  Dart_PersistentHandle _type_resolver;
};