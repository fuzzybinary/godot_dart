#pragma once

#include <godot/gdextension_interface.h>

#if !defined(GDE_EXPORT)
#if defined(_WIN32)
#define GDE_EXPORT __declspec(dllexport)
#elif defined(__GNUC__)
#define GDE_EXPORT __attribute__((visibility("default")))
#else
#define GDE_EXPORT
#endif
#endif

#define GD_STRING_MAX_SIZE 8
#define GD_STRING_NAME_MAX_SIZE 8

#define GD_PRINT_ERROR(msg)                                                                                            \
  { GDEWrapper::instance()->gde()->print_error(msg, __func__, __FILE__, __LINE__, true); }

#define GD_PRINT_WARNING(msg)                                                                                          \
  { GDEWrapper::instance()->gde()->print_warning(msg, __func__, __FILE__, __LINE__, true); }

class GDEWrapper {
public:
  static void create_instance(const GDExtensionInterface *gde_interface, GDExtensionClassLibraryPtr library);
  static GDEWrapper *instance() {
    return _instance;
  }

  bool initialize();
  bool is_editor_hint();

  const GDExtensionInterface *gde() {
    return _gde_interface;
  }
  GDExtensionClassLibraryPtr lib() {
    return _library;
  }  

private:
  static GDEWrapper *_instance;

  const GDExtensionInterface *_gde_interface = nullptr;
  GDExtensionClassLibraryPtr _library = nullptr;
  GDExtensionMethodBindPtr _is_editor_hint_method = nullptr;
  void *token = nullptr;
};