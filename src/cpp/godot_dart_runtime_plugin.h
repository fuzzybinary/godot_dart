#pragma once

#include <string>

#include "dart_bindings.h"
#include "script/dart_resource_format.h"

// This class wraps the Dart bindings for Godot so we can do the following:
//   - Detect if a Dart project exists before loading
//   - Load the Dart project post initialization
//   - TODO:
//   - Load the godot_dart package separately from user code (allows some 
//     functionality of the extension even if the user code doesn't compile)
class GodotDartRuntimePlugin {
public:
  GodotDartRuntimePlugin();

  void base_init();

  bool has_dart_module() const;
  bool has_package_config() const;

  const std::string &get_root_dart_dir() const {
    return _root_dart_dir;
  }

  bool initialize_dart_bindings();  
  void shutdown_dart_bindings();

  static GodotDartRuntimePlugin* get_instance() {
    return s_instance;
  }

private: 
  static GodotDartRuntimePlugin *s_instance;

  GodotDartBindings *_dart_bindings;
  std::string _root_dart_dir;

  godot::Ref<DartResourceFormatLoader> _resource_format_loader;
  godot::Ref<DartResourceFormatSaver> _resource_format_saver;
};