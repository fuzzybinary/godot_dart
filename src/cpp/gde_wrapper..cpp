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

  return true;
}