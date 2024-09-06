#include "dart_script.h"

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/file_access.hpp>

#include "../dart_bindings.h"

#include "../dart_helpers.h"
#include "../godot_string_wrappers.h"
#include "dart_script_language.h"

using namespace godot;

DartScript::DartScript() : _source_code(), _dart_type(nullptr), _script_info(nullptr) {
}

DartScript::~DartScript() {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (bindings == nullptr) {
    return;
  }

  bindings->execute_on_dart_thread([&] {
    DartBlockScope scope;
    // Delete old persistent handles
    if (_dart_type != nullptr) {
      Dart_DeletePersistentHandle(_dart_type);
    }
    if (_script_info != nullptr) {
      Dart_DeletePersistentHandle(_script_info);
    }
  });
}

void DartScript::_bind_methods() {
}

godot::Ref<Script> DartScript::_get_base_script() const {
  refresh_type();

  return _base_script;
}

godot::ScriptLanguage *DartScript::_get_language() const {
  return DartScriptLanguage::instance();
}

void DartScript::_set_source_code(const godot::String &code) {
  _source_code = code;
}

godot::String DartScript::_get_source_code() const {
  return _source_code;
}

bool DartScript::_has_source_code() const {
  return !_source_code.is_empty();
}

bool DartScript::_can_instantiate() const {
  return _is_tool() || !Engine::get_singleton()->is_editor_hint();
}

/// Helper to make sure script info is refreshed and bindings are valid
#define WITH_SCRIPT_INFO(default_return)                                                                               \
  GodotDartBindings *bindings = GodotDartBindings::instance();                                                         \
  if (bindings == nullptr) {                                                                                           \
    return default_return;                                                                                             \
  }                                                                                                                    \
                                                                                                                       \
  refresh_type();                                                                                                      \
  if (_script_info == nullptr) {                                                                                       \
    return default_return;                                                                                             \
  }

bool DartScript::_has_method(const godot::StringName &method) const {
  WITH_SCRIPT_INFO(false)

  bool has_method = false;

  bindings->execute_on_dart_thread([&] {
    DartBlockScope scope;

    Dart_Handle script_info = Dart_HandleFromPersistent(_script_info);
    Dart_Handle args[] = {to_dart_string(method)};
    Dart_Handle method_name = Dart_NewStringFromCString("hasMethod");
    DART_CHECK(dart_has_method, Dart_Invoke(script_info, method_name, 1, args), "Error calling hasMethod");

    Dart_BooleanValue(dart_has_method, &has_method);
  });

  return has_method;
}

bool DartScript::_has_static_method(const godot::StringName &method) const {
  return false;
}

godot::Dictionary DartScript::_get_method_info(const godot::StringName &method) const {
  WITH_SCRIPT_INFO(godot::Dictionary())

  godot::Dictionary ret_val;

  bindings->execute_on_dart_thread([&] {
    DartBlockScope scope;

    Dart_Handle script_info = Dart_HandleFromPersistent(_script_info);
    Dart_Handle getMethodArgs[] = {to_dart_string(method)};
    Dart_Handle d_get_method_info = Dart_NewStringFromCString("getMethodInfo");

    DART_CHECK(dart_method_info, Dart_Invoke(script_info, d_get_method_info, 1, getMethodArgs),
               "Error calling getMethodInfo");

    // TODO: Having Dart do this conversion is a lot of back and forth. Maybe look into an optimization
    Dart_Handle d_as_dict = Dart_NewStringFromCString("asDict");
    DART_CHECK(dart_godot_dict, Dart_Invoke(dart_method_info, d_as_dict, 0, nullptr), "Error calling asDict");

    void *dict_pointer = get_object_address(dart_godot_dict);
    ret_val = godot::Dictionary(*((godot::Dictionary *)dict_pointer));
  });

  return ret_val;
}

bool DartScript::_is_valid() const {
  return true;
}

bool DartScript::_has_script_signal(const godot::StringName &signal) const {
  WITH_SCRIPT_INFO(false)

  bool has_signal = false;

  bindings->execute_on_dart_thread([&] {
    DartBlockScope scope;

    Dart_Handle script_info = Dart_HandleFromPersistent(_script_info);
    Dart_Handle args[] = {to_dart_string(signal)};
    Dart_Handle method_name = Dart_NewStringFromCString("hasSignal");
    DART_CHECK(dart_has_signal, Dart_Invoke(script_info, method_name, 1, args), "Error calling hasMethod");

    Dart_BooleanValue(dart_has_signal, &has_signal);
  });

  return has_signal;
}

godot::TypedArray<godot::Dictionary> DartScript::_get_script_signal_list() const {
  WITH_SCRIPT_INFO(godot::TypedArray<godot::Dictionary>());

  godot::TypedArray<godot::Dictionary> ret_val;

  bindings->execute_on_dart_thread([&] {
    DartBlockScope scope;

    Dart_Handle script_info = Dart_HandleFromPersistent(_script_info);

    Dart_Handle dart_prop_name = Dart_NewStringFromCString("signals");
    DART_CHECK(dart_signal_list, Dart_GetField(script_info, dart_prop_name), "Error getting field signals");

    intptr_t signal_size = 0;
    Dart_ListLength(dart_signal_list, &signal_size);
    for (intptr_t i = 0; i < signal_size; ++i) {
      Dart_Handle signal_info = Dart_ListGetAt(dart_signal_list, i);

      Dart_Handle d_as_dict = Dart_NewStringFromCString("asDict");
      DART_CHECK(dart_godot_dict, Dart_Invoke(signal_info, d_as_dict, 0, nullptr), "Error calling asDict");

      void *dict_pointer = get_object_address(dart_godot_dict);
      godot::Dictionary signal_dict(*((godot::Dictionary *)dict_pointer));
      ret_val.append(signal_dict);
    }
  });

  return ret_val;
}

godot::TypedArray<godot::Dictionary> DartScript::_get_script_method_list() const {
  WITH_SCRIPT_INFO(godot::TypedArray<godot::Dictionary>());

  godot::TypedArray<godot::Dictionary> ret_val;

  bindings->execute_on_dart_thread([&] {
    DartBlockScope scope;

    Dart_Handle script_info = Dart_HandleFromPersistent(_script_info);

    Dart_Handle dart_prop_name = Dart_NewStringFromCString("methods");
    DART_CHECK(dart_method_list, Dart_GetField(script_info, dart_prop_name), "Error getting field methods");

    intptr_t method_count = 0;
    Dart_ListLength(dart_method_list, &method_count);
    for (intptr_t i = 0; i < method_count; ++i) {
      Dart_Handle method_info = Dart_ListGetAt(dart_method_list, i);

      Dart_Handle d_as_dict = Dart_NewStringFromCString("asDict");
      DART_CHECK(dart_godot_dict, Dart_Invoke(method_info, d_as_dict, 0, nullptr), "Error calling asDict");

      void *dict_pointer = get_object_address(dart_godot_dict);
      godot::Dictionary method_dict(*((godot::Dictionary *)dict_pointer));
      ret_val.append(method_dict);
    }
  });

  return ret_val;
}

godot::TypedArray<godot::Dictionary> DartScript::_get_script_property_list() const {
  WITH_SCRIPT_INFO(godot::TypedArray<godot::Dictionary>());

  godot::TypedArray<godot::Dictionary> ret_val;

  bindings->execute_on_dart_thread([&] {
    DartBlockScope scope;

    Dart_Handle script_info = Dart_HandleFromPersistent(_script_info);

    Dart_Handle dart_prop_name = Dart_NewStringFromCString("properties");
    DART_CHECK(dart_property_list, Dart_GetField(script_info, dart_prop_name), "Error getting field properties");

    intptr_t property_count = 0;
    Dart_ListLength(dart_property_list, &property_count);
    for (intptr_t i = 0; i < property_count; ++i) {
      Dart_Handle property_info = Dart_ListGetAt(dart_property_list, i);

      Dart_Handle d_as_dict = Dart_NewStringFromCString("asDict");
      DART_CHECK(dart_godot_dict, Dart_Invoke(property_info, d_as_dict, 0, nullptr), "Error calling asDict");

      void *dict_pointer = get_object_address(dart_godot_dict);
      godot::Dictionary propety_dict(*((godot::Dictionary *)dict_pointer));
      ret_val.append(propety_dict);
    }
  });

  return ret_val;
}

godot::Error DartScript::_reload(bool keep_state) {
  GodotDartBindings *bindings = GodotDartBindings::instance();

  if (bindings != nullptr) {
    bindings->reload_code();
  }

  return godot::Error::OK;
}

bool DartScript::_is_tool() const {
  return false;
}

godot::StringName DartScript::_get_instance_base_type() const {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (bindings == nullptr || _dart_type == nullptr) {
    return godot::StringName();
  }

  godot::StringName native_base_type;
  bindings->execute_on_dart_thread([&] {
    DartBlockScope scope;

    Dart_Handle dart_type = Dart_HandleFromPersistent(_dart_type);
    DART_CHECK(type_info, Dart_GetField(dart_type, Dart_NewStringFromCString("sTypeInfo")), "Failed getting type info");
    DART_CHECK(dart_native_type_name, Dart_GetField(type_info, Dart_NewStringFromCString("nativeTypeName")), "Failed to get nativeTypeName");
    
    native_base_type = *(godot::StringName *)get_object_address(dart_native_type_name);
  });
  
  return native_base_type;
}

godot::TypedArray<godot::Dictionary> DartScript::_get_documentation() const {
  // TODO: See if the Dart VM can get me this info
  return godot::TypedArray<godot::Dictionary>();
}

bool DartScript::_has_property_default_value(const godot::StringName &property) const {
  return false;
}

godot::Variant DartScript::_get_property_default_value(const godot::StringName &property) const {
  return godot::Variant();
}

godot::StringName DartScript::_get_global_name() const {
  return godot::StringName();
}

void DartScript::load_from_disk(const godot::String &path) {
  Ref<FileAccess> file = FileAccess::open(path, FileAccess::READ);
  if (!file.is_null()) {
    String text = file->get_as_text();
    set_source_code(text);
    file->close();
  }
}

void *DartScript::_instance_create(Object *for_object) const {
  if (for_object == nullptr) {
    return nullptr;
  }

  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (bindings == nullptr) {
    return nullptr;
  }

  refresh_type();
  if (_dart_type == nullptr) {
    return nullptr;
  }

  RefCounted *rc = Object::cast_to<RefCounted>(for_object);
  // Don't take the godot_cpp version of the object, use the version from the engine
  return bindings->create_script_instance(_dart_type, this, for_object->_owner, false, rc != nullptr);
}

void *DartScript::_placeholder_instance_create(Object *for_object) const {
  if (for_object == nullptr) {
    return nullptr;
  }

  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (bindings == nullptr) {
    return nullptr;
  }

  refresh_type();
  if (_dart_type == nullptr) {
    return nullptr;
  }

  RefCounted *rc = Object::cast_to<RefCounted>(for_object);
  return bindings->create_script_instance(_dart_type, this, for_object->_owner, true, rc != nullptr);
}

void DartScript::refresh_type() const {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (bindings == nullptr) {
    return;
  }

  if (_dart_type != nullptr) {
    // Don't bother unless we've been asked to reload
    return;
  }

  _base_script.unref();

  bindings->execute_on_dart_thread([&] {
    // Delete old persistent handles
    if (_dart_type != nullptr) {
      Dart_DeletePersistentHandle(_dart_type);
      _dart_type = nullptr;
    }
    if (_script_info != nullptr) {
      Dart_DeletePersistentHandle(_script_info);
      _script_info = nullptr;
    }

    DartBlockScope scope;
    DartScriptLanguage *language = DartScriptLanguage::instance();

    String path = get_path();
    
    Dart_Handle dart_type = language->get_type_for_script(path);
    if (!Dart_IsNull(dart_type)) {
      _dart_type = Dart_NewPersistentHandle(dart_type);
      DART_CHECK(type_info, Dart_GetField(dart_type, Dart_NewStringFromCString("sTypeInfo")),
                 "Failed getting type info");
      DART_CHECK(script_info, Dart_GetField(type_info, Dart_NewStringFromCString("scriptInfo")), "Failed to get scriptInfo");
      if (script_info != nullptr) {
        _script_info = Dart_NewPersistentHandle(script_info);

        // Find the base type
        Dart_Handle base_type = Dart_GetField(type_info, Dart_NewStringFromCString("parentType"));
        if (Dart_IsNull(base_type)) {
          _base_script = language->find_script_for_type(script_info);
        }
      }
    }
  });
}
