#pragma once

#include <dart_api.h>
#include <godot/gdextension_interface.h>

class GodotDartBindings {
public:
  static GodotDartBindings *instance() {
    return _instance;
  }

  explicit GodotDartBindings() : _isolate(nullptr) {
  }

  bool initialize(const char *script_path, const char *package_config);
  void shutdown();

  void set_instance(GDExtensionObjectPtr gd_object, GDExtensionConstStringNamePtr classname, Dart_Handle instance);
  void bind_method(const char *classname, const char *method_name);

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
};