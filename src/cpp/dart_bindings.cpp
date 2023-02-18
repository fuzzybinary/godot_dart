#include "dart_bindings.h"

#include <godot/gdextension_interface.h>
#include <dart_dll.h>
#include <dart_api.h>

#define GD_PRINT_ERROR(msg) { \
    _gde->print_error(msg, __func__, __FILE__, __LINE__); \
}

#define GD_PRINT_WARNING(msg) { \
    _gde->print_warning(msg, __func__, __FILE__, __LINE__); \
}

bool DartBindings::initialize(const char* script_path, const char* package_config) {

  DartDll_Initialize();

  Dart_Isolate isolate = DartDll_LoadScript(script_path, package_config);
  if (isolate == nullptr) {
    GD_PRINT_ERROR("GodotDart: Initialization Error (Failed to load script)");
    return false;
  }

  Dart_EnterIsolate(isolate);
  Dart_EnterScope();

  Dart_Handle godot_dart_package_name = Dart_NewStringFromCString("package:godot_dart/godot_dart.dart");
  Dart_Handle godot_dart_library = Dart_LookupLibrary(godot_dart_package_name);
  if (Dart_IsError(godot_dart_library)) {
    GD_PRINT_ERROR("GodotDart: Initialization Error (Could not find the `godot_dart` package)");
    return false;
  }

  {
    Dart_Handle args[] = {
      Dart_NewInteger((int64_t)_gde)
    };
    Dart_Handle result = Dart_Invoke(godot_dart_library, Dart_NewStringFromCString("_registerGodot"), 1, args);
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

  return true;
}

void DartBindings::shutdown() {
  DartDll_DrainMicrotaskQueue();
  Dart_ShutdownIsolate();
  DartDll_Shutdown();
}