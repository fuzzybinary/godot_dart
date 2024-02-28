#include <gdextension_interface.h>

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/classes/editor_plugin_registration.hpp>

#include "dart_helpers.h"
#include "dart_bindings.h"
#include "gde_wrapper.h"
#include "godot_string_wrappers.h"
#include "godot_dart_runtime_plugin.h"

#include "dart_instance_binding.h"
#include "dart_script_instance.h"
#include "ref_counted_wrapper.h"

#include "editor/godot_dart_editor_plugin.h"
#include "editor/progress_dialog.h"

namespace godot_dart {

GodotDartRuntimePlugin *runtime_plugin = nullptr;

void initialize_level(godot::ModuleInitializationLevel p_level) {
  if (p_level == godot::ModuleInitializationLevel::MODULE_INITIALIZATION_LEVEL_EDITOR) {
    godot::ClassDB::register_class<GodotDartEditorPlugin>();
    godot::ClassDB::register_class<ProgressDialog>();

    godot::EditorPlugins::add_by_type<GodotDartEditorPlugin>();
  }

  // TODO - Should we setup different types at different times?
  if (p_level != godot::ModuleInitializationLevel::MODULE_INITIALIZATION_LEVEL_SCENE) {
    return;
  }

  auto gde = GDEWrapper::instance();

  if (!gde->initialize()) {
    return;
  }

  // Get the library path
  runtime_plugin = new GodotDartRuntimePlugin();
  runtime_plugin->base_init();
}

void deinitialize_level(godot::ModuleInitializationLevel p_level) {
  if (p_level != godot::ModuleInitializationLevel::MODULE_INITIALIZATION_LEVEL_SCENE) {
    return;
  }

  if (runtime_plugin != nullptr) {
    runtime_plugin->shutdown_dart_bindings();
  }
}

} // namespace godot_dart

extern "C" {

void GDE_EXPORT initialize_level(godot::ModuleInitializationLevel p_level) {
  godot_dart::initialize_level(p_level);
}

void GDE_EXPORT deinitialize_level(godot::ModuleInitializationLevel p_level) {
  godot_dart::deinitialize_level(p_level);
}

bool GDE_EXPORT godot_dart_init(GDExtensionInterfaceGetProcAddress p_get_proc_address,
                                GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
  gde_init_c_interface(p_get_proc_address);
  GDEWrapper::create_instance(p_get_proc_address, p_library);

  godot::GDExtensionBinding::InitObject init_obj(p_get_proc_address, p_library, r_initialization);

  init_obj.register_initializer(initialize_level);
  init_obj.register_terminator(deinitialize_level);
  init_obj.set_minimum_library_initialization_level(
      godot::ModuleInitializationLevel::MODULE_INITIALIZATION_LEVEL_SCENE);

  return init_obj.init();
}

}
