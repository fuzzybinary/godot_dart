#include <gdextension_interface.h>

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/classes/object.hpp>

#include "dart_helpers.h"
#include "dart_bindings.h"
#include "gde_wrapper.h"
#include "godot_string_helpers.h"

#include "dart_godot_binding.h"
#include "dart_script_instance.h"

namespace godot_dart {

GodotDartBindings *dart_bindings = nullptr;

void initialize_level(godot::ModuleInitializationLevel p_level) {
  // TODO - Should we setup different types at different times?
  if (p_level != godot::ModuleInitializationLevel::MODULE_INITIALIZATION_LEVEL_SCENE) {
    return;
  }

  auto gde = GDEWrapper::instance();

  if (!gde->initialize()) {
    return;
  }

  // Get the library path
  godot::String library_path;
  gde_get_library_path(gde->get_library_ptr(), library_path._native_ptr());

  // Get the base dir from the library path
  godot::String gd_basedir_path = library_path.get_base_dir();
  
  // basedir_path to c string
  GDExtensionInt basedir_path_size = gde_string_to_utf8_chars(gd_basedir_path._native_ptr(), NULL, 0);
  char *basedir_path = reinterpret_cast<char *>(gde_mem_alloc(basedir_path_size + 1));
  if (basedir_path == NULL) {
    GD_PRINT_ERROR("GodotDart: Initialization Error (Memory allocation failure)");
    return;
  }

  gde_string_to_utf8_chars(gd_basedir_path._native_ptr(), basedir_path, basedir_path_size);
  basedir_path[basedir_path_size] = '\0';

  char dart_script_path[256], package_path[256];
  sprintf(dart_script_path, "%s/src/main.dart", basedir_path);
  sprintf(package_path, "%s/src/.dart_tool/package_config.json", basedir_path);

  dart_bindings = new GodotDartBindings();
  if (!dart_bindings->initialize(dart_script_path, package_path)) {
    delete dart_bindings;
    dart_bindings = nullptr;
  }
}

void deinitialize_level(godot::ModuleInitializationLevel p_level) {
  if (p_level != godot::ModuleInitializationLevel::MODULE_INITIALIZATION_LEVEL_SCENE) {
    return;
  }

  if (dart_bindings) {
    dart_bindings->shutdown();
    delete dart_bindings;
    dart_bindings = nullptr;

    for(const auto& itr : DartGodotInstanceBinding::s_instanceMap) {
      DartGodotInstanceBinding *binding = itr.second;
      GDExtensionObjectPtr godot_object = binding->get_godot_object();
      if (!binding->is_weak()) {
        if (binding->is_refcounted()) {
          // Unref Dart's copy.
          godot::RefCounted ref_counted;
          ref_counted._owner = reinterpret_cast<godot::RefCounted *>(godot_object);
          if (ref_counted.unreference()) {
            // Dart was the last thing holding and couldn't convert to weak as part of shutdown
            gde_object_destroy(godot_object);
          }
        } else {
          // Godot should ask to destroy this.
        }
      } else {
        // This should also not happen. If it's weak, Dart should have destroyed it.
        assert(false);
      }
    }

    DartGodotInstanceBinding::s_instanceMap.clear();

    for(const auto& itr : DartScriptInstance::s_instanceMap) {
      godot::Object obj;
      obj._owner = itr.second->_binding.get_godot_object();

      auto str = obj.to_string().utf8();

      printf("Leaked binding instance at %lx\n: %s", itr.first, str.get_data());
      printf("   binding at %lx\n", (intptr_t)&itr.second->_binding);
    }
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
  // TODO: Remove in favor of godot-cpp's version of this
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
