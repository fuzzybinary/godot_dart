#pragma once

#include <map>

#include "dart_script.h"
#include <dart_api.h>
#include <godot_cpp/classes/script_language_extension.hpp>

class DartScriptLanguage : public godot::ScriptLanguageExtension {
  GDCLASS(DartScriptLanguage, godot::ScriptLanguageExtension);

public:
  DartScriptLanguage();

  godot::String _get_name() const override;

  /* Language Functions */
  void _init() override;
  godot::String _get_type() const override;
  godot::String _get_extension() const override;
  void _finish() override;

  /* Editor Functions */
  godot::PackedStringArray _get_reserved_words() const override;
  bool _is_control_flow_keyword(const godot::String &keyword) const override;
  godot::PackedStringArray _get_comment_delimiters() const override;
  godot::PackedStringArray _get_doc_comment_delimiters() const override;
  godot::PackedStringArray _get_string_delimiters() const override;
  godot::Ref<godot::Script> _make_template(const godot::String &_template, const godot::String &class_name,
                                           const godot::String &base_class_name) const override;
  bool _is_using_templates() override {
    return false;
  }
  godot::TypedArray<godot::Dictionary> _get_built_in_templates(const godot::StringName &object) const override;
  godot::Dictionary _validate(const godot::String &script, const godot::String &path, bool validate_functions,
                              bool validate_errors, bool validate_warnings, bool validate_safe_lines) const override;
  godot::String _validate_path(const godot::String &path) const override;
  godot::Object *_create_script() const override;
  bool _has_named_classes() const override {
    return true;
  }
  bool _supports_builtin_mode() const override {
    return false;
  }
  bool _can_inherit_from_file() const override {
    return false;
  }
  int _find_function(const godot::String &class_name, const godot::String &funciton_name) const override;
  bool _overrides_external_editor() override {
    return false;
  }
  godot::String _make_function(const godot::String &class_name, const godot::String &name,
                               const godot::PackedStringArray &args) const override;
  godot::String _auto_indent_code(const godot::String &code, int32_t fromLine, int32_t toLine) const override;
  void _add_global_constant(const godot::StringName &p_variable, const godot::Variant &value) override{
    // TODO:
  }

  /* Thread Functions */
  void _thread_enter() override;
  void _thread_exit() override;

  /* Debugger Functions */
  godot::String _debug_get_error() const override;
  int32_t _debug_get_stack_level_count() const override;
  int32_t _debug_get_stack_level_line(int32_t level) const override;
  godot::String _debug_get_stack_level_function(int32_t level) const override;
  godot::Dictionary _debug_get_stack_level_locals(int32_t level, int32_t max_subitems, int32_t max_depth) override;
  godot::Dictionary _debug_get_stack_level_members(int32_t level, int32_t max_subitems, int32_t max_depth) override;
  void *_debug_get_stack_level_instance(int32_t level) override;
  godot::Dictionary _debug_get_globals(int32_t max_subitems, int32_t max_depth) override;
  godot::String _debug_parse_stack_level_expression(int32_t level, const godot::String &expression,
                                                    int32_t max_subitems, int32_t max_depth) override;
  godot::TypedArray<godot::Dictionary> _debug_get_current_stack_info() override;

  void _reload_all_scripts() override;
  void _reload_tool_script(const godot::Ref<godot::Script> &script, bool soft_reload) override;

  /* Loader functions */

  godot::PackedStringArray _get_recognized_extensions() const override;
  godot::TypedArray<godot::Dictionary> _get_public_functions() const override;
  godot::Dictionary _get_public_constants() const override;
  godot::TypedArray<godot::Dictionary> _get_public_annotations() const override;

  void _profiling_start() override {
    // TODO:
  }
  void _profiling_stop() override {
    // TODO:
  }
  int32_t _profiling_get_accumulated_data(godot::ScriptLanguageExtensionProfilingInfo *info_array,
                                          int32_t info_max) override {
    // TODO:
    return 0;
  }
  int32_t _profiling_get_frame_data(godot::ScriptLanguageExtensionProfilingInfo *info_array, int32_t info_max) {
    // TODO:
    return 0;
  }

  void _frame() override;

  virtual bool _handles_global_class_type(const godot::String &type) const override;
  virtual godot::Dictionary _get_global_class_name(const godot::String &path) const override;

  /* Godot Dart Functions */

  void shutdown();

  void attach_type_resolver(Dart_Handle resolver);
  Dart_Handle get_type_for_script(const godot::String &path) const;
  godot::String get_script_for_type(Dart_Handle dart_type) const;

  godot::Ref<DartScript> get_cached_script(const godot::String &path);
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