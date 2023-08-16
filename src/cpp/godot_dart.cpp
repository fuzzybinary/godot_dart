#include <godot/gdextension_interface.h>

#include "dart_bindings.h"
#include "gde_wrapper.h"
#include "godot_string_wrappers.h"

namespace godot_dart {

// Hashes from the extension_api.json. Since we don't generate all of the
// bindings for C++ and only use the ones we need, these are just copied
const uint32_t kGetBaseDirHash = 3942272618;

GodotDartBindings *dart_bindings = nullptr;

void initialize_level(void *userdata, GDExtensionInitializationLevel p_level) {
  // TODO - Should we setup different types at different times?
  if (p_level != GDEXTENSION_INITIALIZATION_SCENE) {
    return;
  }

  auto gde = GDEWrapper::instance();

  if (!gde->initialize()) {
    return;
  }

  GDStringName gd_method_name("get_base_dir");
  GDExtensionPtrBuiltInMethod get_base_dir = gde_variant_get_ptr_builtin_method(
      GDEXTENSION_VARIANT_TYPE_STRING, gd_method_name._native_ptr(), kGetBaseDirHash);
  if (get_base_dir == nullptr) {
    GD_PRINT_ERROR("GodotDart: Initialization Error (cannot retrieve "
                   "`String.get_base_dir` method)");
    return;
  }

  // Get the library path
  GDString library_path;
  gde_get_library_path(gde->get_library_ptr(), library_path._native_ptr());

  // Get the base dir from the library path
  GDString gd_basedir_path;
  get_base_dir(library_path._native_ptr(), NULL, gd_basedir_path._native_ptr(), 0);

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
  sprintf_s(dart_script_path, "%s/src/main.dart", basedir_path);
  sprintf_s(package_path, "%s/src/.dart_tool/package_config.json", basedir_path);

  dart_bindings = new GodotDartBindings();
  if (!dart_bindings->initialize(dart_script_path, package_path)) {
    delete dart_bindings;
    dart_bindings = nullptr;
  }
}

void deinitialize_level(void *userdata, GDExtensionInitializationLevel p_level) {
  if (p_level != GDEXTENSION_INITIALIZATION_SCENE) {
    return;
  }

  if (dart_bindings) {
    dart_bindings->shutdown();
    delete dart_bindings;
    dart_bindings = nullptr;
  }
}

} // namespace godot_dart

extern "C" {

void GDE_EXPORT initialize_level(void *userdata, GDExtensionInitializationLevel p_level) {
  godot_dart::initialize_level(userdata, p_level);
}

void GDE_EXPORT deinitialize_level(void *userdata, GDExtensionInitializationLevel p_level) {
  godot_dart::deinitialize_level(userdata, p_level);
}

void GDE_EXPORT godot_dart_init(GDExtensionInterfaceGetProcAddress p_get_proc_address,
                                GDExtensionClassLibraryPtr p_library, GDExtensionInitialization *r_initialization) {
  
  gde_init_c_interface(p_get_proc_address);
  
  GDEWrapper::create_instance(p_get_proc_address, p_library);

  r_initialization->initialize = initialize_level;
  r_initialization->deinitialize = deinitialize_level;
  r_initialization->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SCENE;
}

}
