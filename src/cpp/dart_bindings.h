#pragma once

#include <vector>

#include <dart_api.h>
#include <godot/gdextension_interface.h>

struct TypeInfo {
  GDExtensionStringNamePtr type_name;
  // Can be null
  GDExtensionStringNamePtr parent_name;
  GDExtensionVariantType variant_type;
};

class GodotDartBindings {
public:
  static GodotDartBindings *instance() {
    return _instance;
  }

  explicit GodotDartBindings() : _isolate(nullptr) {
  }

  bool initialize(const char *script_path, const char *package_config);
  void shutdown();

  void bind_method(const TypeInfo &bind_type, const char *method_name, const TypeInfo &ret_type_info,
                   const std::vector<TypeInfo> &arg_list);

  static GDExtensionObjectPtr class_create_instance(void *p_userdata);
  static void class_free_instance(void *p_userdata, GDExtensionClassInstancePtr p_instance);

private:
  static void bind_call(void *method_userdata, GDExtensionClassInstancePtr instance,
                        const GDExtensionConstVariantPtr *args, GDExtensionInt argument_count,
                        GDExtensionVariantPtr r_return, GDExtensionCallError *r_error);
  static void ptr_call(void *method_userdata, GDExtensionClassInstancePtr instance,
                       const GDExtensionConstVariantPtr *args, GDExtensionVariantPtr r_return);

  static GodotDartBindings *_instance;

  Dart_Isolate _isolate;
  Dart_PersistentHandle _native_library;

  // Some things we need often
  Dart_PersistentHandle _void_pointer_type;
  Dart_PersistentHandle _void_pointer_pointer_type;
};