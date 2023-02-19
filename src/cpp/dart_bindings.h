#pragma once

#include <dart_api.h>
#include <godot/gdextension_interface.h>

class GodotDartBindings {

public:
  static GodotDartBindings* instance() {
    return _instance;
  }

  explicit GodotDartBindings(const GDExtensionInterface* interface, GDExtensionClassLibraryPtr library)
    : _gde(interface)
    , _libraryPtr(library)
    , _isolate(nullptr) {

  }

  bool initialize(const char* script_path, const char* package_config);
  void shutdown();

  void set_instance(GDExtensionObjectPtr gd_object, GDExtensionConstStringNamePtr classname, Dart_Handle instance);

private:
  static GodotDartBindings* _instance;

  const GDExtensionInterface* _gde;
  GDExtensionClassLibraryPtr _libraryPtr;

  Dart_Isolate _isolate;
};