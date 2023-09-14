#include "gde_wrapper.h"
#include "godot_string_wrappers.h"
#include "ref_counted_wrapper.h"

GDEWrapper *GDEWrapper::_instance = nullptr;

void GDEWrapper::create_instance(GDExtensionInterfaceGetProcAddress gde_get_proc_address,
                                 GDExtensionClassLibraryPtr library) {
  _instance = new GDEWrapper();

  _instance->_gde_get_proc_address = gde_get_proc_address;
  _instance->_library = library;
}

bool GDEWrapper::initialize() {
  GDString::init();
  GDStringName::init();
  RefCountedWrapper::init();

  /// Get the is_editor_hint method from Engine
  const unsigned int is_editor_hint_hash = 36873697;
  
  GDStringName str_engine("Engine");
  GDStringName str_is_editor_hint("is_editor_hint");

  _is_editor_hint_method = gde_classdb_get_method_bind(&str_engine, &str_is_editor_hint, is_editor_hint_hash);

  return true;
}

bool GDEWrapper::is_editor_hint() {
  GDStringName str_engine("Engine");

  GDExtensionObjectPtr engine = gde_global_get_singleton(&str_engine);
  if (engine == nullptr) {
    return false;
  }
  
  GDExtensionBool is_editor_hint = false;

  gde_object_method_bind_ptrcall(_is_editor_hint_method, engine, nullptr, &is_editor_hint);

  return is_editor_hint;
}