#include "dart_script.h"

#include <godot_cpp/classes/editor_file_system.hpp>
#include <godot_cpp/classes/editor_interface.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/file_access.hpp>

#include "../dart_bindings.h"

#include "../dart_helpers.h"
#include "../godot_string_wrappers.h"
#include "script/dart_script_instance.h"
#include "script/dart_script_language.h"

using namespace godot;

DartScript::DartScript() : _source_code(), _dart_type(nullptr), _type_info(nullptr) {
}

DartScript::~DartScript() {
  clear_property_cache();

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
    if (_type_info != nullptr) {
      Dart_DeletePersistentHandle(_type_info);
      _type_info = nullptr;
    }
  });
}

void DartScript::_bind_methods() {
}

godot::Ref<Script> DartScript::_get_base_script() const {
  const_cast<DartScript *>(this)->refresh_type(false);

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
  const_cast<DartScript *>(this)->refresh_type(false);                                                                 \
  if (_type_info == nullptr) {                                                                                         \
    return default_return;                                                                                             \
  }

bool DartScript::_has_method(const godot::StringName &method) const {
  WITH_SCRIPT_INFO(false)

  bool has_method = false;

  bindings->execute_on_dart_thread([&] {
    DartBlockScope scope;

    Dart_Handle script_info = Dart_HandleFromPersistent(_type_info);
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

    Dart_Handle script_info = Dart_HandleFromPersistent(_type_info);
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

    Dart_Handle script_info = Dart_HandleFromPersistent(_type_info);
    Dart_Handle args[] = {to_dart_string(signal)};
    Dart_Handle method_name = Dart_NewStringFromCString("hasSignal");
    DART_CHECK(dart_has_signal, Dart_Invoke(script_info, method_name, 1, args), "Error calling hasSignal");

    Dart_BooleanValue(dart_has_signal, &has_signal);
  });

  return has_signal;
}

godot::TypedArray<godot::Dictionary> DartScript::_get_script_signal_list() const {
  WITH_SCRIPT_INFO(godot::TypedArray<godot::Dictionary>());

  godot::TypedArray<godot::Dictionary> ret_val;

  bindings->execute_on_dart_thread([&] {
    DartBlockScope scope;

    Dart_Handle type_info = Dart_HandleFromPersistent(_type_info);

    Dart_Handle dart_prop_name = Dart_NewStringFromCString("signals");
    DART_CHECK(dart_signal_list, Dart_GetField(type_info, dart_prop_name), "Error getting field signals");

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

    Dart_Handle script_info = Dart_HandleFromPersistent(_type_info);

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

  const DartScript *top = this;
  while (top != nullptr) {
    const auto &properties_cache = top->get_properties();
    for (const auto &prop_info : properties_cache) {
      godot::Dictionary info_dict;
      info_dict[godot::Variant(godot::String("type"))] = Variant(prop_info.type);
      info_dict[godot::Variant(godot::String("name"))] =
          Variant(*reinterpret_cast<godot::StringName *>(prop_info.name));
      info_dict[godot::Variant(godot::String("class_name"))] =
          Variant(*reinterpret_cast<godot::StringName *>(prop_info.class_name));
      info_dict[godot::Variant(godot::String("hint"))] = Variant(prop_info.hint);
      info_dict[godot::Variant(godot::String("hint_string"))] =
          Variant(*reinterpret_cast<godot::String *>(prop_info.hint_string));
      info_dict[godot::Variant(godot::String("usage"))] = Variant(prop_info.usage);
      ret_val.push_back(info_dict);
    }
    top = top->_base_script.ptr();
  }

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
  if (bindings == nullptr) {
    return godot::StringName();
  }
  const_cast<DartScript *>(this)->refresh_type(false);
  if (_dart_type == nullptr) {
    return godot::StringName();
  }

  godot::StringName native_base_type;
  bindings->execute_on_dart_thread([&] {
    DartBlockScope scope;

    Dart_Handle dart_type = Dart_HandleFromPersistent(_dart_type);
    DART_CHECK(type_info, Dart_GetField(dart_type, Dart_NewStringFromCString("sTypeInfo")), "Failed getting type info");
    DART_CHECK(dart_native_type_name, Dart_GetField(type_info, Dart_NewStringFromCString("nativeTypeName")),
               "Failed to get nativeTypeName");

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

void DartScript::_update_exports() {
  refresh_type(true);

  for (const auto &script_instance : _placeholders) {
    script_instance->notify_property_list_changed();
  }
}

godot::StringName DartScript::_get_global_name() const {
  WITH_SCRIPT_INFO(godot::StringName());

  godot::StringName ret;

  bindings->execute_on_dart_thread([&] {
    DartBlockScope scope;

    Dart_Handle dart_type = Dart_HandleFromPersistent(_dart_type);
    DART_CHECK(type_info, Dart_GetField(dart_type, Dart_NewStringFromCString("sTypeInfo")), "Failed getting type info");
    DART_CHECK(value, Dart_GetField(type_info, Dart_NewStringFromCString("isGlobalClass")),
               "Failed to get isGlobalClass");
    bool is_global = false;
    Dart_BooleanValue(value, &is_global);
    if (is_global) {
      DART_CHECK(class_name, Dart_GetField(type_info, Dart_NewStringFromCString("className")),
                 "Failed getting class name from type info");
      ret = *(godot::StringName *)get_object_address(class_name);
    }
  });

  return ret;
}

void DartScript::load_from_disk(const godot::String &path) {
  Ref<FileAccess> file = FileAccess::open(path, FileAccess::READ);
  if (!file.is_null()) {
    String text = file->get_as_text();
    set_source_code(text);
    file->close();
  }
}

void DartScript::did_hot_reload() {
  _update_exports();
  auto editor_interface = godot::EditorInterface::get_singleton();
  if (editor_interface) {
    String path = get_path();
    editor_interface->get_resource_filesystem()->update_file(path);
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

  const_cast<DartScript *>(this)->refresh_type(false);
  // Even if we don't know our type, we still need to create the script instance,
  // This is mostly for new scripts that we might not know about yet because
  // hot reload hasn't happened.
  // if (_dart_type == nullptr) {
  //   return nullptr;
  // }

  return create_script_instance_internal(for_object, false);
}

void *DartScript::_placeholder_instance_create(Object *for_object) const {
  if (for_object == nullptr) {
    return nullptr;
  }

  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (bindings == nullptr) {
    return nullptr;
  }

  // Even if we don't know our type, we still need to create the script instance,
  // This is mostly for new scripts that we don't know about yet because hot reload
  // hasn't taken affect.
  // const_cast<DartScript *>(this)->refresh_type(false);
  // if (_dart_type == nullptr) {
  //   return nullptr;
  // }

  return create_script_instance_internal(for_object, true);
}

void *DartScript::create_script_instance_internal(Object *for_object, bool is_placeholder) const {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  GDExtensionScriptInstancePtr godot_script_instance = nullptr;

  RefCounted *rc = Object::cast_to<RefCounted>(for_object);
  DartScriptInstance *script_instance =
      new DartScriptInstance(const_cast<DartScript *>(this), for_object, is_placeholder, rc != nullptr);

  godot_script_instance =
      gde_script_instance_create2(DartScriptInstance::get_script_instance_info(),
                                  reinterpret_cast<GDExtensionScriptInstanceDataPtr>(script_instance));
  if (is_placeholder) {
    _placeholders.insert(script_instance);
  }

  return godot_script_instance;
}

Dart_Handle DartScript::create_dart_object(Object *for_object) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  Dart_Handle ret_object = Dart_Null();
  refresh_type(false);

  if (!_dart_type) {
    return Dart_Null();
  }

  bindings->execute_on_dart_thread([&] {
    DartBlockScope scope;

    DART_CHECK(dart_type, Dart_HandleFromPersistent(_dart_type), "Could not get type from persistent handle");
    DART_CHECK(dart_object, bindings->new_godot_owned_object(dart_type, for_object->_owner), "Error creating bindings");
    if (Dart_IsNull(dart_object)) {
      GD_PRINT_ERROR("Failed to create script instance! Got Null");
    }
    ret_object = dart_object;
  });

  return ret_object;
}

Dart_Handle DartScript::get_dart_type_info() {
  if (!_type_info) {
    return Dart_Null();
  }

  return Dart_HandleFromPersistent(_type_info);
}

void DartScript::dart_placeholder_erased(DartScriptInstance *p_placeholder) {
  _placeholders.erase(p_placeholder);
}

void DartScript::clear_property_cache() {
  for (auto &prop : _properties_cache) {
    gde_free_property_info_fields(&prop);
  }
  _properties_cache.clear();
}

void DartScript::refresh_type(bool force) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (bindings == nullptr) {
    return;
  }

  if (_dart_type != nullptr && !force) {
    return;
  }

  _base_script.unref();

  bindings->execute_on_dart_thread([&] {
    DartBlockScope scope;

    // Delete old persistent handles
    if (_dart_type != nullptr) {
      Dart_DeletePersistentHandle(_dart_type);
      _dart_type = nullptr;
    }
    if (_type_info != nullptr) {
      Dart_DeletePersistentHandle(_type_info);
      _type_info = nullptr;
    }

    DartScriptLanguage *language = DartScriptLanguage::instance();

    String path = get_path();

    Dart_Handle dart_type = language->get_type_for_script(path);
    if (!Dart_IsNull(dart_type)) {
      _dart_type = Dart_NewPersistentHandle(dart_type);
      DART_CHECK(type_info, Dart_GetField(dart_type, Dart_NewStringFromCString("sTypeInfo")),
                 "Failed getting type info");
      if (!Dart_IsNull(type_info)) {
        _type_info = Dart_NewPersistentHandle(type_info);

        // Find the base type
        DART_CHECK(base_type_info, Dart_GetField(type_info, Dart_NewStringFromCString("parentTypeInfo")),
                   "Failed to get parentTypeInfo for type");
        if (!Dart_IsNull(base_type_info)) {
          DART_CHECK(base_type, Dart_GetField(base_type_info, Dart_NewStringFromCString("type")),
                     "Failed to get type from parentTypeInfo");
          if (!Dart_IsNull(base_type)) {
            _base_script = language->find_script_for_type(base_type);
          }
        }

        // Update Properties
        clear_property_cache();

        // TODO: Get properties from our base class?
        DART_CHECK(properties_list, Dart_GetField(_type_info, Dart_NewStringFromCString("properties")),
                   "Failed to get properties info");
        intptr_t prop_count = 0;
        Dart_ListLength(properties_list, &prop_count);

        // Always add a secret hidden property that tells Godot the name of our class
        {
          DART_CHECK(class_name, Dart_GetField(type_info, Dart_NewStringFromCString("className")),
                     "Failed to get class name.");
          GDExtensionPropertyInfo property_info = {
              GDEXTENSION_VARIANT_TYPE_NIL,
              new godot::StringName(*reinterpret_cast<godot::StringName *>(get_object_address(class_name))),
              new godot::String(),
              PROPERTY_HINT_NONE,
              new godot::String(path),
              PROPERTY_USAGE_CATEGORY};
          _properties_cache.push_back(property_info);
        }

        if (prop_count > 0) {
          for (auto i = 0; i < prop_count; ++i) {
            DART_CHECK(dart_property, Dart_ListGetAt(properties_list, i), "Failed to get property at index");
            GDExtensionPropertyInfo property_info;
            gde_property_info_from_dart(dart_property, &property_info);
            godot::StringName *prop_name = reinterpret_cast<godot::StringName *>(property_info.name);
            _properties_cache.push_back(property_info);
          }
        }

        // Update RPC Methods
        DART_CHECK(rpc_list, Dart_GetField(type_info, Dart_NewStringFromCString("rpcInfo")), "Failed to get Rpc Info");
        intptr_t rpc_count = 0;
        Dart_ListLength(rpc_list, &rpc_count);
        _rpc_config.clear();
        if (rpc_count > 0) {
          Dart_Handle rpc_as_dict = Dart_NewStringFromCString("asDict");
          godot::Dictionary godot_rpc_config;
          for (auto i = 0; i < rpc_count; ++i) {
            DART_CHECK(rpc_info, Dart_ListGetAt(rpc_list, i), "Failed to get rpc at index");
            DART_CHECK(dart_godot_dict, Dart_Invoke(rpc_info, rpc_as_dict, 0, nullptr), "Error calling asDict");

            void *dict_pointer = get_object_address(dart_godot_dict);
            auto dict = godot::Dictionary(*((godot::Dictionary *)dict_pointer));
            auto name = dict.get(godot::String("name"), godot::Variant());
            godot_rpc_config[name] = dict;
          }
          _rpc_config = godot_rpc_config;
        }
      }
    }
  });
}
