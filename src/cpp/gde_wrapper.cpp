#include "gde_wrapper.h"

#include "godot_cpp/classes/engine.hpp"

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
  RefCountedWrapper::init();

  return true;
}

bool GDEWrapper::is_editor_hint() {
  godot::Engine* engine = godot::Engine::get_singleton();
  if (engine == nullptr) {
    return false;
  }
  
  return engine->is_editor_hint();
}