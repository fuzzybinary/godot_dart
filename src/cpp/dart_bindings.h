#pragma once

#include <dart_api.h>
#include <godot/gdextension_interface.h>

class DartBindings {

public:

  explicit DartBindings(const GDExtensionInterface* interface)
    : _gde(interface)
    , _isolate(nullptr) {

  }

  bool initialize(const char* script_path, const char* package_config);
  void shutdown();

private:
  const GDExtensionInterface* _gde;

  Dart_Isolate _isolate;
};