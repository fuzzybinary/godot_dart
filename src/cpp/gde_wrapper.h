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

  const GDExtensionInterface *gde() {
    return _gde_interface;
  }
  GDExtensionClassLibraryPtr lib() {
    return _library;
  }

  void gd_string_name_new(GDExtensionStringNamePtr out, const char *cstr);
  void gd_string_name_destructor(GDExtensionStringNamePtr ptr);

  void gd_string_new(GDExtensionTypePtr out);
  void gd_string_from_string_name(GDExtensionConstStringNamePtr ptr, uint8_t* out);
  void gd_string_destructor(GDExtensionTypePtr ptr);

private:
  static GDEWrapper *_instance;

  const GDExtensionInterface *_gde_interface = nullptr;
  GDExtensionClassLibraryPtr _library = nullptr;
  void *token = nullptr;

  // GDExtension interface uses GDStringName everywhere a name should be passed,
  // however it is very cumbersome to create it!
  GDExtensionPtrConstructor _gdstring_constructor = nullptr;
  GDExtensionPtrConstructor _gdstring_from_gdstringname_constructor = nullptr;
  GDExtensionPtrDestructor _gdstring_destructor = nullptr;
  GDExtensionPtrConstructor _gdstringname_from_gdstring_constructor = nullptr;
  GDExtensionPtrDestructor _gdstringname_destructor = nullptr;
};