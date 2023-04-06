#pragma once

#include <functional>
#include <mutex>
#include <semaphore>
#include <thread>
#include <vector>

#include <dart_api.h>
#include <godot/gdextension_interface.h>

struct TypeInfo {
  GDExtensionStringNamePtr type_name;
  // Can be null
  GDExtensionStringNamePtr parent_name;
  GDExtensionVariantType variant_type;
  // Can be null
  GDExtensionInstanceBindingCallbacks *binding_callbacks;
};

class GodotDartBindings {
public:
  static GodotDartBindings *instance() {
    return _instance;
  }

  explicit GodotDartBindings() : _stopRequested(false), _dart_thread(nullptr), _work_semaphore(0), _done_semaphore(0), _isolate(nullptr) {
  }

  bool initialize(const char *script_path, const char *package_config);
  void shutdown();

  void bind_method(const TypeInfo &bind_type, const char *method_name, const TypeInfo &ret_type_info,
                   const std::vector<TypeInfo> &arg_list);
  void execute_on_dart_thread(std::function<void()> work);

  static GDExtensionObjectPtr class_create_instance(void *p_userdata);
  static void class_free_instance(void *p_userdata, GDExtensionClassInstancePtr p_instance);
  static GDExtensionClassCallVirtual get_virtual_func(void *p_userdata, GDExtensionConstStringNamePtr p_name);

private:
  static void thread_callback(GodotDartBindings *bindings);

  static void bind_call(void *method_userdata, GDExtensionClassInstancePtr instance,
                        const GDExtensionConstVariantPtr *args, GDExtensionInt argument_count,
                        GDExtensionVariantPtr r_return, GDExtensionCallError *r_error);
  static void ptr_call(void *method_userdata, GDExtensionClassInstancePtr instance,
                       const GDExtensionConstVariantPtr *args, GDExtensionVariantPtr r_return);

  void thread_main();

  static GodotDartBindings *_instance;

  bool _stopRequested;

  std::thread *_dart_thread;
  std::mutex _work_lock;
  std::function<void()> _pendingWork;
  std::binary_semaphore _work_semaphore;
  std::binary_semaphore _done_semaphore;

  Dart_Isolate _isolate;
  Dart_PersistentHandle _godot_dart_library;
  Dart_PersistentHandle _core_types_library;
  Dart_PersistentHandle _native_library;

  // Some things we need often
  Dart_PersistentHandle _void_pointer_type;
  Dart_PersistentHandle _void_pointer_optional_type;
  Dart_PersistentHandle _void_pointer_pointer_type;
};