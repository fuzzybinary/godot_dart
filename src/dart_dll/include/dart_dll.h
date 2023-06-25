#pragma once

typedef struct _Dart_Isolate* Dart_Isolate;
typedef struct _Dart_Handle* Dart_Handle;

#ifdef _WIN
  #ifdef DART_DLL_EXPORTING
    #define DART_DLL_EXPORT __declspec(dllexport)
  #else
    #define DART_DLL_EXPORT __declspec(dllimport)
  #endif
#else
  #define DART_DLL_EXPORT
#endif

extern "C" {

struct DartDllConfig {
  bool start_service_isolate;
  int service_port;

  DartDllConfig()
    : start_service_isolate(true)
    , service_port(5858)
  {
    
  }
};

// Initialize Dart
DART_DLL_EXPORT bool DartDll_Initialize(const DartDllConfig& config);

// Load a script, with an optional package configuration location. The package
// configuration is usually in ".dart_tool/package_config.json".
DART_DLL_EXPORT Dart_Isolate DartDll_LoadScript(const char* script_uri,
                                        const char* package_config);

// Run "main" from the supplied library, usually one you got from
// Dart_RootLibrary()
DART_DLL_EXPORT Dart_Handle DartDll_RunMain(Dart_Handle library);

// Drain the microtask queue. This is necessary if you're using any async code
// or Futures, and using Dart_Invoke over DartDll_RunMain or Dart_RunLoop.
// Otherwise you're not giving the main isolate the opportunity to drain the task queue
// and complete pending Futures.
DART_DLL_EXPORT Dart_Handle DartDll_DrainMicrotaskQueue();

// Shutdown Dart
DART_DLL_EXPORT bool DartDll_Shutdown();

}
