#include "dart_script_language.h"

#include "../dart_bindings.h"
#include "../dart_helpers.h"
#include "../godot_string_wrappers.h"
#include "../editor/dart_templates.h"

#include "dart_script.h"

DartScriptLanguage *DartScriptLanguage::s_instance = nullptr;
DartScriptLanguage *DartScriptLanguage::instance() {
  if (s_instance == nullptr) {
    s_instance = memnew(DartScriptLanguage);
  }

  return s_instance;
}

DartScriptLanguage::DartScriptLanguage() : _script_resolver(nullptr) {
}

void DartScriptLanguage::_thread_enter() {
}

void DartScriptLanguage::_thread_exit() {
}

void DartScriptLanguage::_bind_methods() {
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

void DartScriptLanguage::_frame() {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (bindings != nullptr) {
    bindings->perform_frame_maintanance();
  }
}

bool DartScriptLanguage::_handles_global_class_type(const godot::String &type) const {
  return type == _get_type();
}

godot::String DartScriptLanguage::_validate_path(const godot::String &path) const {
  return godot::String();
}

godot::Object *DartScriptLanguage::_create_script() const {
  return memnew(DartScript);
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

godot::PackedStringArray DartScriptLanguage::_get_recognized_extensions() const {
  godot::PackedStringArray array;
  array.append(".dart");
  return array;
}

godot::String DartScriptLanguage::_auto_indent_code(godot::String code, int fromLine, int toLine) {
  return code;
}

void DartScriptLanguage::attach_script_resolver(Dart_Handle resolver) {
  if (resolver != nullptr) {
    if (_script_resolver != nullptr) {
      Dart_DeletePersistentHandle(_script_resolver);
    }

    _script_resolver = Dart_NewPersistentHandle(resolver);
  }
}

Dart_Handle DartScriptLanguage::get_type_for_script(const godot::String &path) const {
  if (_script_resolver == nullptr) {
    return Dart_Null();
  }

  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (bindings == nullptr) {
    return Dart_Null();
  }

  Dart_Handle ret = Dart_Null();

  bindings->execute_on_dart_thread([&] { 
    Dart_Handle resolver = Dart_HandleFromPersistent(_script_resolver);
    Dart_Handle dart_path = to_dart_string(path);
    Dart_Handle args[] = {dart_path};

    DART_CHECK(value, Dart_InvokeClosure(resolver, 1, args), "Failed to invoke resolver closure!");
    ret = value;
  });
  
  return ret;
}
