#pragma once

#include <functional>
#include <mutex>
#include <semaphore>
#include <thread>
#include <vector>

#include <dart_api.h>
#include <godot/gdextension_interface.h>

#include "gde_dart_converters.h"

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
      : _stopRequested(false), _isolate(nullptr) {
  }
  ~GodotDartBindings();

  bool initialize(const char *script_path, const char *package_config);
  void shutdown();

  GDExtensionScriptLanguagePtr get_language() {
    return _dart_language;
  }

  void bind_method(const TypeInfo &bind_type, const char *method_name, const TypeInfo &ret_type_info,
                   Dart_Handle args_list, MethodFlags method_flags);
  void add_property(const TypeInfo &bind_type, Dart_Handle dart_prop_info);
  void execute_on_dart_thread(std::function<void()> work);
  Dart_Handle new_dart_void_pointer(void *ptr);

  static GDExtensionObjectPtr class_create_instance(void *p_userdata);
  static void class_free_instance(void *p_userdata, GDExtensionClassInstancePtr p_instance);
  static void *get_virtual_call_data(void *p_userdata, GDExtensionConstStringNamePtr p_name);
  static void call_virtual_func(void* p_instance, GDExtensionConstStringNamePtr p_name,
                                void *p_userdata, const GDExtensionConstTypePtr *p_args, GDExtensionTypePtr r_ret);
  static void reference(GDExtensionClassInstancePtr p_instance);
  static void unreference(GDExtensionClassInstancePtr p_instance);

private:
  static void bind_call(void *method_userdata, GDExtensionClassInstancePtr instance,
                        const GDExtensionConstVariantPtr *args, GDExtensionInt argument_count,
                        GDExtensionVariantPtr r_return, GDExtensionCallError *r_error);
  static void ptr_call(void *method_userdata, GDExtensionClassInstancePtr instance,
                       const GDExtensionConstVariantPtr *args, GDExtensionVariantPtr r_return);

  static GodotDartBindings *_instance;

public:
  bool _stopRequested;

  int32_t _pending_messages;
  std::mutex _work_lock;
  Dart_Isolate _isolate;
  std::thread::id _isolate_current_thread;

  Dart_PersistentHandle _godot_dart_library;
  Dart_PersistentHandle _core_types_library;
  Dart_PersistentHandle _native_library;

  // Some things we need often
  GDExtensionScriptLanguagePtr _dart_language;
  Dart_PersistentHandle _void_pointer_type;
  Dart_PersistentHandle _void_pointer_optional_type;
  Dart_PersistentHandle _void_pointer_pointer_type;
  Dart_PersistentHandle _variant_type;
};

void *get_opaque_address(Dart_Handle variant_handle);