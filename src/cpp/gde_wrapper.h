#pragma once

#include <gdextension/gdextension_interface.h>

#include "gde_c_interface.h"

#define GD_STRING_MAX_SIZE 8
#define GD_STRING_NAME_MAX_SIZE 8

class GDEWrapper {
public:
  static void create_instance(GDExtensionInterfaceGetProcAddress gde_get_proc_address, GDExtensionClassLibraryPtr library);
  static GDEWrapper *instance() {
    return _instance;
  }

  bool initialize();

  // ClassDb methods
  bool is_editor_hint();

  
  GDExtensionClassLibraryPtr get_library_ptr() {
    return _library;
  }

private:
  static GDEWrapper *_instance;

  GDExtensionInterfaceGetProcAddress _gde_get_proc_address = nullptr;
  GDExtensionClassLibraryPtr _library = nullptr;

  // General Extension Methods


  // Methods from ClassDb
  GDExtensionMethodBindPtr _is_editor_hint_method = nullptr;
};
