#include "dart_script_language.h"

#include <godot_cpp/classes/resource_loader.hpp>

#include "../dart_bindings.h"
#include "../dart_helpers.h"
#include "../editor/dart_templates.h"
#include "../godot_string_wrappers.h"

#include "dart_script.h"

DartScriptLanguage *DartScriptLanguage::s_instance = nullptr;
DartScriptLanguage *DartScriptLanguage::instance() {
  if (s_instance == nullptr) {
    s_instance = memnew(DartScriptLanguage);
  }

  return s_instance;
}

void DartScriptLanguage::shutdown() {
  s_instance = nullptr;

  memdelete(this);
}

DartScriptLanguage::DartScriptLanguage() : _type_resolver(nullptr) {
}

void DartScriptLanguage::_init() {
}

godot::String DartScriptLanguage::_get_name() const {
  static godot::StringName dart("Dart", true);

  return dart;
}

godot::String DartScriptLanguage::_get_type() const {
  static godot::StringName dart_script("DartScript", true);

  return dart_script;
}

godot::String DartScriptLanguage::_get_extension() const {
  static godot::StringName dart("dart", true);

  return dart;
}

void DartScriptLanguage::_finish() {
  // TODO: Anything to do here?
}

/* Editor Functions */

godot::PackedStringArray DartScriptLanguage::_get_reserved_words() const {
  godot::PackedStringArray words;

  static const char *_reserved_words[] = {
      // Reserved keywords
      "abstract", "as",       "assert",   "async",     "await",    "base",       "break",   "case",     "catch",
      "class",    "const",    "continue", "covariant", "default",  "deferred",   "do",      "dynamic",  "else",
      "enum",     "export",   "extends",  "extension", "external", "factory",    "false",   "final",    "finally",
      "for",      "Function", "get",      "hide",      "if",       "implements", "import",  "in",       "interface",
      "is",       "late",     "library",  "mixin",     "new",      "null",       "on",      "operator", "part",
      "required", "rethrow",  "return",   "sealed",    "set",      "show",       "static",  "super",    "switch",
      "sync",     "this",     "throw",    "true",      "try",      "type",       "typedef", "var",      "void",
      "when",     "while",    "with",     "yield",     nullptr};

  const char **w = _reserved_words;

  while (*w) {
    words.push_back(*w);
    w++;
  }

  return words;
}

bool DartScriptLanguage::_is_control_flow_keyword(const godot::String &keyword) const {
  return keyword == "break" || keyword == "case" || keyword == "catch" || keyword == "continue" ||
         keyword == "default" || keyword == "do" || keyword == "else" || keyword == "finally" || keyword == "for" ||
         keyword == "if" || keyword == "return" || keyword == "switch" || keyword == "throw" || keyword == "try" ||
         keyword == "while" || keyword == "yeild";
}

godot::PackedStringArray DartScriptLanguage::_get_comment_delimiters() const {
  godot::PackedStringArray delimiters;
  delimiters.append("//");
  delimiters.append("/* */");
  return delimiters;
}

godot::PackedStringArray DartScriptLanguage::_get_doc_comment_delimiters() const {
  godot::PackedStringArray delimiters;
  delimiters.append("///");
  return delimiters;
}

godot::PackedStringArray DartScriptLanguage::_get_string_delimiters() const {
  godot::PackedStringArray delimiters;
  delimiters.append("\" \"");
  delimiters.append("' '");
  delimiters.append("\"\"\" \"\"\"");
  delimiters.append("''' '''");
  return delimiters;
}

godot::Ref<godot::Script> DartScriptLanguage::_make_template(const godot::String &_template,
                                                             const godot::String &class_name,
                                                             const godot::String &base_class_name) const {
  godot::String source_template(dart_script);
  godot::String source =
      source_template.replace("__CLASS_NAME__", class_name).replace("__BASE_CLASS__", base_class_name);

  godot::Ref<DartScript> script;
  script.instantiate();
  script->set_source_code(source);
  script->set_name(class_name);

  return script;
}

godot::Dictionary DartScriptLanguage::_validate(const godot::String &script, const godot::String &path,
                                                bool validate_functions, bool validate_errors, bool validate_warnings,
                                                bool validate_safe_lines) const {
  return godot::Dictionary();
}

godot::String DartScriptLanguage::_validate_path(const godot::String &path) const {
  return godot::String();
}

godot::Object *DartScriptLanguage::_create_script() const {
  return memnew(DartScript);
}

int DartScriptLanguage::_find_function(const godot::String &class_name, const godot::String &funciton_name) const {
  // TODO:
  return 0;
}

godot::String DartScriptLanguage::_make_function(const godot::String &class_name, const godot::String &name,
                                                 const godot::PackedStringArray &args) const {
  // The make_function() API does not work for Dart for the same reason it doesn't work for C#.
  // It will always append the generated function at the very end of the script, outside of any closing bracket.
  // TODO: Look into `can_make_function`
  return godot::String();
}

godot::String DartScriptLanguage::_auto_indent_code(const godot::String &code, int32_t fromLine, int32_t toLine) const {
  // Really should use the language server for this
  return code;
}

/* Thread Functions */

void DartScriptLanguage::_thread_enter() {
}

void DartScriptLanguage::_thread_exit() {
}

/* Debugger Functions */

godot::String DartScriptLanguage::_debug_get_error() const {
  return godot::String();
}

int32_t DartScriptLanguage::_debug_get_stack_level_count() const {
  return 0;
}

int32_t DartScriptLanguage::_debug_get_stack_level_line(int32_t level) const {
  return 0;
}

godot::String DartScriptLanguage::_debug_get_stack_level_function(int32_t level) const {
  return godot::String();
}

godot::Dictionary DartScriptLanguage::_debug_get_stack_level_locals(int32_t level, int32_t max_subitems,
                                                                    int32_t max_depth) {
  return godot::Dictionary();
}

godot::Dictionary DartScriptLanguage::_debug_get_stack_level_members(int32_t level, int32_t max_subitems,
                                                                     int32_t max_depth) {
  return godot::Dictionary();
}

void *DartScriptLanguage::_debug_get_stack_level_instance(int32_t level) {
  return nullptr;
}

godot::Dictionary DartScriptLanguage::_debug_get_globals(int32_t max_subitems, int32_t max_depth) {
  return godot::Dictionary();
}

godot::String DartScriptLanguage::_debug_parse_stack_level_expression(int32_t level, const godot::String &expression,
                                                                      int32_t max_subitems, int32_t max_depth) {
  return godot::String();
}

godot::TypedArray<godot::Dictionary> DartScriptLanguage::_debug_get_current_stack_info() {
  return godot::TypedArray<godot::Dictionary>();
}

void DartScriptLanguage::_reload_all_scripts() {
  // Trigger the hot reloader
}

void DartScriptLanguage::_reload_tool_script(const godot::Ref<godot::Script> &script, bool soft_reload) {
  // Trigger the hot reloader
}

/* Loader functions */

godot::PackedStringArray DartScriptLanguage::_get_recognized_extensions() const {
  godot::PackedStringArray array;
  array.append("dart");
  return array;
}

godot::TypedArray<godot::Dictionary> DartScriptLanguage::_get_public_functions() const {
  return godot::TypedArray<godot::Dictionary>();
}

godot::Dictionary DartScriptLanguage::_get_public_constants() const {
  return godot::Dictionary();
}

godot::TypedArray<godot::Dictionary> DartScriptLanguage::_get_public_annotations() const {
  return godot::TypedArray<godot::Dictionary>();
}

void DartScriptLanguage::_frame() {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (bindings != nullptr) {
    bindings->perform_frame_maintanance();
  }
}

bool DartScriptLanguage::_handles_global_class_type(const godot::String &type) const {
  return type == _get_type();
}

godot::Dictionary DartScriptLanguage::_get_global_class_name(const godot::String &path) const {
  return godot::Dictionary();
}

void DartScriptLanguage::attach_type_resolver(Dart_Handle resolver) {
  if (resolver != nullptr) {
    if (_type_resolver != nullptr) {
      Dart_DeletePersistentHandle(_type_resolver);
    }

    _type_resolver = Dart_NewPersistentHandle(resolver);
  }
}

Dart_Handle DartScriptLanguage::get_type_for_script(const godot::String &path) const {
  if (_type_resolver == nullptr) {
    return Dart_Null();
  }

  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (bindings == nullptr) {
    return Dart_Null();
  }

  Dart_Handle ret = Dart_Null();

  bindings->execute_on_dart_thread([&] {
    Dart_Handle resolver = Dart_HandleFromPersistent(_type_resolver);
    Dart_Handle dart_path = to_dart_string(path);
    Dart_Handle args[] = {dart_path};

    DART_CHECK(value, Dart_Invoke(resolver, Dart_NewStringFromCString("typeFromPath"), 1, args),
               "Failed to invoke resolver!");
    ret = value;
  });

  return ret;
}

godot::String DartScriptLanguage::get_script_for_type(Dart_Handle dart_type) const {
  if (_type_resolver == nullptr) {
    return godot::String();
  }

  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (bindings == nullptr) {
    return godot::String();
  }

  godot::String ret;

  bindings->execute_on_dart_thread([&] {
    Dart_Handle resolver = Dart_HandleFromPersistent(_type_resolver);
    Dart_Handle args[] = {dart_type};

    DART_CHECK(value, Dart_Invoke(resolver, Dart_NewStringFromCString("pathFromType"), 1, args),
               "Failed to invoke resolver!");
    if (!Dart_IsNull(value)) {
      ret = create_godot_string(value);
    }
  });

  return ret;
}

godot::Ref<DartScript> DartScriptLanguage::get_cached_script(const godot::String &path) {
  auto script_itr = _script_cache.find(path);
  if (script_itr == _script_cache.end()) {
    return godot::Ref<DartScript>();
  }
  return script_itr->second;
}

void DartScriptLanguage::push_cached_script(const godot::String &path, godot::Ref<DartScript> script) {
  _script_cache.insert({path, script});
}

godot::Ref<DartScript> DartScriptLanguage::find_script_for_type(Dart_Handle dart_type) {
  godot::String script_path = get_script_for_type(dart_type);
  // No idea what this type is....
  if (script_path.is_empty()) {
    return godot::Ref<DartScript>();
  }

  godot::Ref<DartScript> ret = get_cached_script(script_path);
  if (ret.is_null()) {
    ret = godot::ResourceLoader::get_singleton()->load(script_path);
  }

  return ret;
}

void DartScriptLanguage::_bind_methods() {
}
