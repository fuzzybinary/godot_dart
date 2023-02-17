#include <godot/gdextension_interface.h>

#include <dart_dll.h>
#include <dart_api.h>

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

#define GD_PRINT_ERROR(msg) { \
    gdeInterface->print_error(msg, __func__, __FILE__, __LINE__); \
}

#define GD_PRINT_WARNING(msg) { \
    gdeInterface->print_warning(msg, __func__, __FILE__, __LINE__); \
}

// GDExtension interface uses GDStringName everywhere a name should be passed,
// however it is very cumbersome to create it !

static GDExtensionPtrConstructor gdstring_constructor = NULL;
static GDExtensionPtrDestructor gdstring_destructor = NULL;
static GDExtensionPtrConstructor gdstringname_from_gdstring_constructor = NULL;
static GDExtensionPtrDestructor gdstringname_destructor = NULL;

namespace godot_dart {

// Hashes from the extension_api.json. Since we don't generate all of the
// bindings for C++ and only use the ones we need, these are just copied
const uint32_t kGetBaseDirHash = 3942272618;

const GDExtensionInterface* gdeInterface = nullptr;
GDExtensionClassLibraryPtr library = nullptr;
void* token = nullptr;

void gd_string_name_new(GDExtensionStringNamePtr out, const char* cstr) {
  uint8_t as_gdstring[GD_STRING_MAX_SIZE];
  gdeInterface->string_new_with_utf8_chars(&as_gdstring, cstr);

  const GDExtensionConstTypePtr args[1] = {&as_gdstring};
  gdstringname_from_gdstring_constructor(out, args);
  gdstring_destructor(&as_gdstring);
}

void initialize_level(void* userdata, GDExtensionInitializationLevel p_level) {
  // TODO - Should we setup different types at different times?
  if (p_level != GDEXTENSION_INITIALIZATION_SERVERS) {
    return;
  }

  gdstring_constructor = gdeInterface->variant_get_ptr_constructor(GDEXTENSION_VARIANT_TYPE_STRING, 0);
  if (gdstring_constructor == NULL) {
    GD_PRINT_ERROR("GodotDart: Initialization Error (cannot retrive `String` constructor)");
    return;
  }

  gdstring_destructor = gdeInterface->variant_get_ptr_destructor(GDEXTENSION_VARIANT_TYPE_STRING);
  if (gdstring_destructor == NULL) {
    GD_PRINT_ERROR("GodotDart: Initialization Error (cannot retrive `String` destructor)");
    return;
  }

  gdstringname_from_gdstring_constructor = gdeInterface->variant_get_ptr_constructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME, 2);
  if (gdstringname_from_gdstring_constructor == NULL) {
    GD_PRINT_ERROR("GodotDart: Initialization Error (cannot retrive `StringName` constructor)");
    return;
  }
  gdstringname_destructor = gdeInterface->variant_get_ptr_destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME);
  if (gdstringname_destructor == NULL) {
    GD_PRINT_ERROR("GodotDart: Initialization Error (cannot retrive `StringName` destructor)");
    return;
  }

  DartDll_Initialize();

  uint8_t gdsn_method_name[GD_STRING_NAME_MAX_SIZE];
  gd_string_name_new(&gdsn_method_name, "get_base_dir");
  GDExtensionPtrBuiltInMethod get_base_dir = gdeInterface->variant_get_ptr_builtin_method(
    GDEXTENSION_VARIANT_TYPE_STRING, gdsn_method_name, kGetBaseDirHash
  );
  gdstringname_destructor(gdsn_method_name);
  if (get_base_dir == nullptr) {
    GD_PRINT_ERROR("GodotDart: Initialization Error (cannot retrieve `String.get_base_dir` method)");
    return;
  }

  // Get the library path
  uint8_t library_path[GD_STRING_MAX_SIZE];
  gdstring_constructor(library_path, NULL);
  gdeInterface->get_library_path(library, library_path);

  // Get the base dir from the library path
  uint8_t gd_basedir_path[GD_STRING_MAX_SIZE];
  gdstring_constructor(gd_basedir_path, NULL);
  get_base_dir(library_path, NULL, gd_basedir_path, 0);
  gdstring_destructor(library_path);

  // basedir_path to c string
  GDExtensionInt basedir_path_size = gdeInterface->string_to_utf8_chars(gd_basedir_path, NULL, 0);
  char* basedir_path = reinterpret_cast<char*>(gdeInterface->mem_alloc(basedir_path_size + 1));
  if(basedir_path == NULL) {
    GD_PRINT_ERROR("GodotDart: Initialization Error (Memory allocation failure)");
    return;
  }

  gdeInterface->string_to_utf8_chars(gd_basedir_path, basedir_path, basedir_path_size);
  basedir_path[basedir_path_size] = '\0';
  gdstring_destructor(gd_basedir_path);

  char dartScriptPath[256], packagePath[256];
  sprintf_s(dartScriptPath, "%s/src/main.dart", basedir_path);
  sprintf_s(packagePath, "%s/src/.dart_tool/package_config.json", basedir_path);
  Dart_Isolate isolate = DartDll_LoadScript(dartScriptPath, packagePath);
  if(isolate == nullptr) {
    GD_PRINT_ERROR("GodotDart: Initialization Error (Failed to load script)");
    return;
  }

  Dart_EnterIsolate(isolate);
  Dart_EnterScope();

  Dart_Handle godot_dart_package_name = Dart_NewStringFromCString("package:godot_dart/godot_dart.dart");
  Dart_Handle godot_dart_library = Dart_LookupLibrary(godot_dart_package_name);
  if (Dart_IsError(godot_dart_library)) {
    GD_PRINT_ERROR("GodotDart: Initialization Error (Could not find the `godot_dart` package)");
    return;
  }
  
  {
    Dart_Handle args[] = {
      Dart_NewInteger((int64_t)gdeInterface)
    };
    Dart_Handle result = Dart_Invoke(godot_dart_library, Dart_NewStringFromCString("_register_godot"), 1, args);
    if (Dart_IsError(result)) {
      GD_PRINT_ERROR("GodotDart: Error calling `_register_godot`");
      GD_PRINT_ERROR(Dart_GetError(result));
      return;
    }
  }
  
  {
    Dart_Handle library = Dart_RootLibrary();
    Dart_Handle mainFunctionName = Dart_NewStringFromCString("main");
    Dart_Handle result = Dart_Invoke(library, mainFunctionName, 0, nullptr);
    if (Dart_IsError(result)) {
      GD_PRINT_ERROR("GodotDart: Error calling `main`");
      GD_PRINT_ERROR(Dart_GetError(result));
    }
  }

  Dart_ExitScope();
}

void deinitialize_level(void* userdata, GDExtensionInitializationLevel p_level) {
  if(p_level != GDEXTENSION_INITIALIZATION_SERVERS) {
    return;
  }

  DartDll_Shutdown();
}

}

extern "C" {

void GDE_EXPORT initialize_level(void* userdata, GDExtensionInitializationLevel p_level) {
  godot_dart::initialize_level(userdata, p_level);
}

void GDE_EXPORT deinitialize_level(void* userdata, GDExtensionInitializationLevel p_level) {
  godot_dart::deinitialize_level(userdata, p_level);
}

GDExtensionBool GDE_EXPORT godot_dart_init(
  const GDExtensionInterface* p_interface, 
  GDExtensionClassLibraryPtr p_library, 
  GDExtensionInitialization *r_initialization
) {

  godot_dart::gdeInterface = p_interface;
  godot_dart::library = p_library;
  godot_dart::token = p_library;

  r_initialization->initialize = initialize_level;
  r_initialization->deinitialize = deinitialize_level;
  r_initialization->minimum_initialization_level = GDEXTENSION_INITIALIZATION_SERVERS;
  
  return true;
}

}
