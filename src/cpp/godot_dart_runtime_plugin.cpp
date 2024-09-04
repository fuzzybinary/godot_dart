#include "godot_dart_runtime_plugin.h"

#include <sstream>

#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/resource_saver.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/object.hpp>

#include "dart_helpers.h"
#include "dart_script_instance.h"
#include "gde_wrapper.h"
#include "godot_string_wrappers.h"
#include "ref_counted_wrapper.h"

#include "script/dart_script_language.h"
#include "script/dart_resource_format.h"

GodotDartRuntimePlugin *GodotDartRuntimePlugin::s_instance = nullptr;

GodotDartRuntimePlugin::GodotDartRuntimePlugin() : _dart_bindings(nullptr), _root_dart_dir() {
  assert(s_instance == nullptr);
  s_instance = this;
}

void GodotDartRuntimePlugin::base_init() {
  auto gde = GDEWrapper::instance();

  godot::ClassDB::register_class<DartScriptLanguage>();
  godot::ClassDB::register_class<DartScript>();
  godot::ClassDB::register_class<DartResourceFormatLoader>();
  godot::ClassDB::register_class<DartResourceFormatSaver>();

  godot::String library_path;
  gde_get_library_path(gde->get_library_ptr(), library_path._native_ptr());

  // Get the base dir from the library path
  godot::String gd_basedir_path = library_path.get_base_dir();

  // basedir_path to c string
  GDExtensionInt basedir_path_size = gde_string_to_utf8_chars(gd_basedir_path._native_ptr(), NULL, 0);
  char *basedir_path = reinterpret_cast<char *>(gde_mem_alloc(basedir_path_size + 1));
  if (basedir_path == NULL) {
    GD_PRINT_ERROR("GodotDart: Initialization Error (Memory allocation failure)");
    return;
  }

  gde_string_to_utf8_chars(gd_basedir_path._native_ptr(), basedir_path, basedir_path_size);
  basedir_path[basedir_path_size] = '\0';

  // Save path to main src directory
  std::stringstream ss;
  ss << basedir_path << "/src";
  _root_dart_dir = ss.str();

  _resource_format_loader.instantiate();
  _resource_format_saver.instantiate();
  godot::ResourceLoader::get_singleton()->add_resource_format_loader(_resource_format_loader);
  godot::ResourceSaver::get_singleton()->add_resource_format_saver(_resource_format_saver);

  godot::Engine::get_singleton()->register_script_language(DartScriptLanguage::instance());
  
  if (has_dart_module() && has_package_config()) {
    initialize_dart_bindings();
  }
}

bool GodotDartRuntimePlugin::has_dart_module() const {
  // Looking for src/pubspec.yaml and src/main.dart. If both are there, we're probably good.
  // We'll check for the package config later

  godot::String gd_root_dir(_root_dart_dir.c_str());

  if (!godot::DirAccess::dir_exists_absolute(gd_root_dir)) {
    return false;
  }

  std::stringstream ss_yaml_path;
  ss_yaml_path << _root_dart_dir << "/pubspec.yaml";
  godot::String gd_yaml_path(ss_yaml_path.str().c_str());
  if (!godot::FileAccess::file_exists(gd_yaml_path)) {
    return false;
  }

  std::stringstream ss_main_path;
  ss_main_path << _root_dart_dir << "/main.dart";
  godot::String gd_main_path(ss_main_path.str().c_str());
  if (!godot::FileAccess::file_exists(gd_main_path)) {
    return false;
  }

  return true;
}

bool GodotDartRuntimePlugin::has_package_config() const {
  std::stringstream ss_main_path;
  ss_main_path << _root_dart_dir << "/.dart_tool/package_config.json";
  godot::String gd_main_path(ss_main_path.str().c_str());
  if (!godot::FileAccess::file_exists(gd_main_path)) {
    return false;
  }

  return true;
}

bool GodotDartRuntimePlugin::initialize_dart_bindings() {
  char dart_script_path[256], package_path[256];
  sprintf(dart_script_path, "%s/main.dart", _root_dart_dir.c_str());
  sprintf(package_path, "%s/.dart_tool/package_config.json", _root_dart_dir.c_str());

  _dart_bindings = new GodotDartBindings();
  if (!_dart_bindings->initialize(dart_script_path, package_path)) {
    delete _dart_bindings;
    _dart_bindings = nullptr;
  }

  return true;
}

void GodotDartRuntimePlugin::shutdown_dart_bindings() {
  if (_dart_bindings) {
    _dart_bindings->shutdown();
    delete _dart_bindings;
    _dart_bindings = nullptr;

    for (const auto &itr : DartGodotInstanceBinding::s_instanceMap) {
      DartGodotInstanceBinding *binding = itr.second;
      GDExtensionObjectPtr godot_object = binding->get_godot_object();
      if (!binding->is_weak()) {
        if (binding->is_refcounted()) {
          // Unref Dart's copy.
          RefCountedWrapper ref_counted(godot_object);
          if (ref_counted.unreference()) {
            // Dart was the last thing holding and couldn't convert to weak as part of shutdown
            gde_object_destroy(godot_object);
          } else {
            godot::Object obj;
            obj._owner = godot_object;
          }
        } else {
          // Godot should ask to destroy this.
        }
      } else {
        // This should also not happen. If it's weak, Dart should have destroyed it.
        assert(false);
      }
    }

    DartGodotInstanceBinding::s_instanceMap.clear();

    for (const auto &itr : DartScriptInstance::s_instanceMap) {
      godot::Object obj;
      obj._owner = itr.second->_binding.get_godot_object();

      auto str = obj.to_string().utf8();

      // TODO: Remove when we know we're not leaking
      printf("Leaked binding instance at %llx\n: %s", static_cast<int64_t>(itr.first), str.get_data());
      printf("   binding at %llx\n", (intptr_t)&itr.second->_binding);
    }
  }

  godot::ResourceLoader::get_singleton()->remove_resource_format_loader(_resource_format_loader);
  _resource_format_loader.unref();
  godot::ResourceSaver::get_singleton()->remove_resource_format_saver(_resource_format_saver);
  _resource_format_saver.unref();
  DartScriptLanguage *language = DartScriptLanguage::instance();
  godot::Engine::get_singleton()->unregister_script_language(language);
  // This will cause the instance to delete itself
  language->shutdown();
}
