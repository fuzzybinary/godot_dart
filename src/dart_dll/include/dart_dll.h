#pragma once

typedef struct _Dart_Isolate* Dart_Isolate;

#ifdef _WIN
  #ifdef DART_DLL_EXPORTING
    #define DART_DLL_EXPORT __declspec(dllexport)
  #else
    #define DART_DLL_EXPORT __declspec(dllimport)
  #endif
#else
  #define DART_DLL_EXPORT
#endif

DART_DLL_EXPORT bool DartDll_Initialize();
DART_DLL_EXPORT Dart_Isolate DartDll_LoadScript(const char* script_uri,
                                        const char* package_config);
DART_DLL_EXPORT bool DartDll_Shutdown();
