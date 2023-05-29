#pragma once

#include <functional>
#include <mutex>
#include <semaphore>
#include <thread>
#include <vector>

#include <dart_api.h>
#include <godot/gdextension_interface.h>

#define GDE GDEWrapper::instance()->gde()

#define DART_CHECK_RET(var, expr, ret, message)                                                                        \
  Dart_Handle var = (expr);                                                                                            \
  if (Dart_IsError(var)) {                                                                                             \
    GD_PRINT_ERROR("GodotDart: "##message##": ");                                                                      \
    GD_PRINT_ERROR(Dart_GetError(var));                                                                                \
    return ret;                                                                                                        \
  }

#define DART_CHECK(var, expr, message) DART_CHECK_RET(var, expr, , message)

enum class MethodFlags : int32_t {
  None,
  PropertyGetter,
  PropertySetter,
};

struct TypeInfo {
  GDExtensionStringNamePtr type_name = nullptr;
  // Can be null
  GDExtensionStringNamePtr parent_name = nullptr;
  GDExtensionVariantType variant_type = GDEXTENSION_VARIANT_TYPE_NIL;
  // Can be null
  const GDExtensionInstanceBindingCallbacks *binding_callbacks = nullptr;
};

class DartBlockScope {

public:
  DartBlockScope() {
    Dart_EnterScope();
  }

  ~DartBlockScope() {
    Dart_ExitScope();
  }
};

class GodotDartBindings {
public:
  static GodotDartBindings *instance() {
    return _instance;
  }

  explicit GodotDartBindings()
      : _stopRequested(false), _dart_thread(nullptr), _work_semaphore(0), _done_semaphore(0), _isolate(nullptr) {
  }
  ~GodotDartBindings();

  bool initialize(const char *script_path, const char *package_config);
  void shutdown();

  void bind_method(const TypeInfo &bind_type, const char *method_name, const TypeInfo &ret_type_info,
                   Dart_Handle args_list, MethodFlags method_flags);
  void add_property(const TypeInfo &bind_type, Dart_Handle dart_prop_info);
  void execute_on_dart_thread(std::function<void()> work);
  Dart_Handle new_dart_void_pointer(void *ptr);

  void bind_call(Dart_Handle dart_method_name, Dart_Handle dart_instance, const GDExtensionConstVariantPtr *p_args,
                 GDExtensionInt p_argument_count, GDExtensionVariantPtr r_return, GDExtensionCallError *r_error);

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

public:
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

void *get_opaque_address(Dart_Handle variant_handle);