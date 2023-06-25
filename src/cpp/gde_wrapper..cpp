#include "gde_wrapper.h"
#include "godot_string_wrappers.h"

GDEWrapper *GDEWrapper::_instance = nullptr;

void GDEWrapper::create_instance(const GDExtensionInterface *gde_interface, GDExtensionClassLibraryPtr library) {
  _instance = new GDEWrapper();

  _instance->_gde_interface = gde_interface;
  _instance->_library = library;
}

bool GDEWrapper::initialize() {
  GDString::init_from_gde(_gde_interface);
  GDStringName::init_from_gde(_gde_interface);

  /// Get the is_editor_hint method from Engine
  const unsigned int is_editor_hint_hash = 36873697;
  
  GDStringName str_engine("Engine");
  GDStringName str_is_editor_hint("is_editor_hint");

  _is_editor_hint_method = _gde_interface->classdb_get_method_bind(&str_engine, &str_is_editor_hint, is_editor_hint_hash);

  return true;
}

bool GDEWrapper::is_editor_hint() {
  GDStringName str_engine("Engine");

  GDExtensionObjectPtr engine = _gde_interface->global_get_singleton(&str_engine);
  if (engine == nullptr) {
    return false;
  }

  GDExtensionBool is_editor_hint = false;

  _gde_interface->object_method_bind_ptrcall(_is_editor_hint_method, engine, nullptr, &is_editor_hint);

  return is_editor_hint;
}