#pragma once

#include <functional>
#include <mutex>
#include <semaphore>
#include <thread>
#include <vector>
#include <set>

#include <dart_api.h>
#include <gdextension_interface.h>

#include "gde_dart_converters.h"
#include "dart_instance_binding.h"

enum class MethodFlags : int32_t {
  None,
  PropertyGetter,
  PropertySetter,
};

class DartScript;

class GodotDartBindings {
public:
  static GodotDartBindings *instance() {
    return _instance;
  }

  explicit GodotDartBindings()
      : _is_stopping(false), _fully_initialized(false), _pending_messages(0), _isolate(nullptr) {
  }
  ~GodotDartBindings();

  bool initialize(const char *script_path, const char *package_config);
  bool is_fully_initialized() const {
    return _fully_initialized;
  }
  void shutdown();

  void reload_code();

  void bind_method(const TypeInfo &bind_type, const char *method_name, const TypeInfo &ret_type_info,
                   Dart_Handle args_list, MethodFlags method_flags);
  void add_property(const TypeInfo &bind_type, Dart_Handle dart_prop_info);
  void execute_on_dart_thread(std::function<void()> work);
  Dart_Handle new_dart_void_pointer(void *ptr);
  void perform_frame_maintanance();

  void add_pending_ref_change(DartGodotInstanceBinding *bindings);
  void remove_pending_ref_change(DartGodotInstanceBinding *bindings);
  void perform_pending_ref_changes();

  void* create_script_instance(Dart_Handle type, const DartScript* script, void *godot_object, bool is_placeholder,
                              bool is_refcounted);

  static GDExtensionObjectPtr class_create_instance(void *p_userdata);
  static void class_free_instance(void *p_userdata, GDExtensionClassInstancePtr p_instance);
  static void *get_virtual_call_data(void *p_userdata, GDExtensionConstStringNamePtr p_name);
  static void call_virtual_func(void* p_instance, GDExtensionConstStringNamePtr p_name,
                                void *p_userdata, const GDExtensionConstTypePtr *p_args, GDExtensionTypePtr r_ret);
  
private:
  static void bind_call(void *method_userdata, GDExtensionClassInstancePtr instance,
                        const GDExtensionConstVariantPtr *args, GDExtensionInt argument_count,
                        GDExtensionVariantPtr r_return, GDExtensionCallError *r_error);
  static void ptr_call(void *method_userdata, GDExtensionClassInstancePtr instance,
                       const GDExtensionConstVariantPtr *args, GDExtensionVariantPtr r_return);

  static GodotDartBindings *_instance;

public:
  bool _fully_initialized;
  bool _is_stopping;
  int32_t _pending_messages;
  std::mutex _work_lock;
  Dart_Isolate _isolate;
  std::thread::id _isolate_current_thread;
  std::set<DartGodotInstanceBinding *> _pending_ref_changes;

  Dart_PersistentHandle _godot_dart_library;
  Dart_PersistentHandle _core_types_library;
  Dart_PersistentHandle _native_library;

  // Some things we need often
  Dart_PersistentHandle _void_pointer_type;
  Dart_PersistentHandle _void_pointer_optional_type;
  Dart_PersistentHandle _void_pointer_pointer_type;
  Dart_PersistentHandle _variant_type;
};