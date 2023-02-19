#include "dart_bindings.h"

#include <string.h>
#include <iostream>

#include <godot/gdextension_interface.h>
#include <dart_dll.h>
#include <dart_api.h>

#define GD_PRINT_ERROR(msg) { \
    _gde->print_error(msg, __func__, __FILE__, __LINE__); \
}

#define GD_PRINT_WARNING(msg) { \
    _gde->print_warning(msg, __func__, __FILE__, __LINE__); \
}

GodotDartBindings* GodotDartBindings::_instance = nullptr;

bool GodotDartBindings::initialize(const char* script_path, const char* package_config) {

  DartDll_Initialize();

  _isolate = DartDll_LoadScript(script_path, package_config);
  if (_isolate == nullptr) {
    GD_PRINT_ERROR("GodotDart: Initialization Error (Failed to load script)");
    return false;
  }

  Dart_EnterIsolate(_isolate);
  Dart_EnterScope();

  Dart_Handle godot_dart_package_name = Dart_NewStringFromCString("package:godot_dart/godot_dart.dart");
  Dart_Handle godot_dart_library = Dart_LookupLibrary(godot_dart_package_name);
  if (Dart_IsError(godot_dart_library)) {
    GD_PRINT_ERROR("GodotDart: Initialization Error (Could not find the `godot_dart` package)");
    return false;
  }

  {
    Dart_Handle args[] = {
      Dart_NewInteger((int64_t)_gde),
      Dart_NewInteger((int64_t)_libraryPtr)
    };
    Dart_Handle result = Dart_Invoke(godot_dart_library, Dart_NewStringFromCString("_registerGodot"), 2, args);
    if (Dart_IsError(result)) {
      GD_PRINT_ERROR("GodotDart: Error calling `_registerGodot`");
      GD_PRINT_ERROR(Dart_GetError(result));
      return false;
    }
  }

  {
    Dart_Handle library = Dart_RootLibrary();
    Dart_Handle mainFunctionName = Dart_NewStringFromCString("main");
    Dart_Handle result = Dart_Invoke(library, mainFunctionName, 0, nullptr);
    if (Dart_IsError(result)) {
      GD_PRINT_ERROR("GodotDart: Error calling `main`");
      GD_PRINT_ERROR(Dart_GetError(result));
      return false;
    }
  }

  Dart_ExitScope();

  _instance = this;

  return true;
}

void GodotDartBindings::set_instance(GDExtensionObjectPtr gd_object, GDExtensionConstStringNamePtr classname, Dart_Handle instance) {
  // Persist the handle, as Godot will be holding onto it.
  Dart_PersistentHandle persist = Dart_NewPersistentHandle(instance);
  _gde->object_set_instance(gd_object, classname, persist);
}

void GodotDartBindings::shutdown() {
  DartDll_DrainMicrotaskQueue();
  Dart_ShutdownIsolate();
  DartDll_Shutdown();

  _instance = nullptr;
}

/* Native C Functions */

#if !defined(GDE_EXPORT)
#if defined(_WIN32)
#define GDE_EXPORT __declspec(dllexport)
#elif defined(__GNUC__)
#define GDE_EXPORT __attribute__((visibility("default")))
#else
#define GDE_EXPORT
#endif
#endif

extern "C" {

void GDE_EXPORT godot_dart_set_instance(GDExtensionObjectPtr object, GDExtensionConstStringNamePtr classname, Dart_Handle instance) {
  GodotDartBindings* bindings = GodotDartBindings::instance();
  if (!bindings) {
    Dart_ThrowException(Dart_NewStringFromCString("GodotDart has been shutdown!"));
    return;
  }

  bindings->set_instance(object, classname, instance);
}

}