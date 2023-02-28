#include <godot/gdextension_interface.h>

#include "dart_bindings.h"
#include "gde_wrapper.h"

namespace godot_dart {

// Hashes from the extension_api.json. Since we don't generate all of the
// bindings for C++ and only use the ones we need, these are just copied
const uint32_t kGetBaseDirHash = 3942272618;

GodotDartBindings *dart_bindings = nullptr;

void initialize_level(void *userdata, GDExtensionInitializationLevel p_level) {
  // TODO - Should we setup different types at different times?
  if (p_level != GDEXTENSION_INITIALIZATION_SERVERS) {
    return;
  }

  auto gde = GDEWrapper::instance();

  if (!gde->initialize()) {
    return;
  }

  uint8_t gdsn_method_name[GD_STRING_NAME_MAX_SIZE];
  gde->gd_string_name_new(&gdsn_method_name, "get_base_dir");
  GDExtensionPtrBuiltInMethod get_base_dir =
      gde->gde()->variant_get_ptr_builtin_method(GDEXTENSION_VARIANT_TYPE_STRING, gdsn_method_name, kGetBaseDirHash);
  gde->gd_string_name_destructor(gdsn_method_name);
  if (get_base_dir == nullptr) {
    GD_PRINT_ERROR("GodotDart: Initialization Error (cannot retrieve "
                   "`String.get_base_dir` method)");
    return;
  }

  // Get the library path
  uint8_t library_path[GD_STRING_MAX_SIZE];
  gde->gd_string_new(library_path);
  gde->gde()->get_library_path(gde->lib(), library_path);

  // Get the base dir from the library path
  uint8_t gd_basedir_path[GD_STRING_MAX_SIZE];
  gde->gd_string_new(gd_basedir_path);
  get_base_dir(library_path, NULL, gd_basedir_path, 0);
  gde->gd_string_destructor(library_path);

  // basedir_path to c string
  GDExtensionInt basedir_path_size = gde->gde()->string_to_utf8_chars(gd_basedir_path, NULL, 0);
  char *basedir_path = reinterpret_cast<char *>(gde->gde()->mem_alloc(basedir_path_size + 1));
  if (basedir_path == NULL) {
    GD_PRINT_ERROR("GodotDart: Initialization Error (Memory allocation failure)");
    return;
  }

  gde->gde()->string_to_utf8_chars(gd_basedir_path, basedir_path, basedir_path_size);
  basedir_path[basedir_path_size] = '\0';
  gde->gd_string_destructor(gd_basedir_path);

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
  if (p_level != GDEXTENSION_INITIALIZATION_SERVERS) {
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

GDExtensionBool GDE_EXPORT godot_dart_init(const GDExtensionInterface *p_interface,
                                           GDExtensionClassLibraryPtr p_library,
                                           GDExtensionInitialization *r_initialization) {
  GDEWrapper::create_instance(p_interface, p_library);

  r_initialization->initialize = initialize_level;
  r_initialization->deinitialize = deinitialize_level;
  r_initialization->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SERVERS;

  return true;
}
}
