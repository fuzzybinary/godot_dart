#pragma once

#include <functional>
#include <mutex>
#include <semaphore>
#include <set>
#include <thread>
#include <vector>

#include <dart_api.h>
#include <gdextension_interface.h>
#include <godot_cpp/classes/ref.hpp>
#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/classes/wrapped.hpp>

#include "dart_instance_binding.h"
#include "gde_dart_converters.h"
#include "script/dart_script.h"

enum class MethodFlags : int32_t {
  None,
  PropertyGetter,
  PropertySetter,
};

class GodotDartBindings {
public:
  static GodotDartBindings *instance() {
    return _instance;
  }

  explicit GodotDartBindings()
      : _is_stopping(false), _fully_initialized(false), _is_reloading(false), _pending_messages(0), _isolate(nullptr) {
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
  Dart_Handle find_dart_type(Dart_Handle type_name);
  void add_property(const TypeInfo &bind_type, Dart_Handle dart_prop_info);
  void execute_on_dart_thread(std::function<void()> work);
  Dart_Handle new_dart_void_pointer(const void *ptr);
  void perform_frame_maintanance();

  void add_pending_ref_change(DartGodotInstanceBinding *bindings);
  void remove_pending_ref_change(DartGodotInstanceBinding *bindings);
  void perform_pending_ref_changes();

  static GDExtensionObjectPtr class_create_instance(void *p_userdata);
  static void class_free_instance(void *p_userdata, GDExtensionClassInstancePtr p_instance);
  static void *get_virtual_call_data(void *p_userdata, GDExtensionConstStringNamePtr p_name);
  static void call_virtual_func(void *p_instance, GDExtensionConstStringNamePtr p_name, void *p_userdata,
                                const GDExtensionConstTypePtr *p_args, GDExtensionTypePtr r_ret);

private:
  void did_finish_hot_reload();

  static void bind_call(void *method_userdata, GDExtensionClassInstancePtr instance,
                        const GDExtensionConstVariantPtr *args, GDExtensionInt argument_count,
                        GDExtensionVariantPtr r_return, GDExtensionCallError *r_error);
  static void ptr_call(void *method_userdata, GDExtensionClassInstancePtr instance,
                       const GDExtensionConstVariantPtr *args, GDExtensionVariantPtr r_return);

  static GodotDartBindings *_instance;

public:
  bool _fully_initialized;
  bool _is_stopping;
  bool _is_reloading;
  int32_t _pending_messages;
  std::mutex _work_lock;
  Dart_Isolate _isolate;
  std::thread::id _isolate_current_thread;
  std::set<godot::Ref<DartScript>> _pending_reloads;
  std::set<DartGodotInstanceBinding *> _pending_ref_changes;

  Dart_PersistentHandle _godot_dart_library;
  Dart_PersistentHandle _engine_classes_library;
  Dart_PersistentHandle _variant_classes_library;
  Dart_PersistentHandle _native_library;

  // Some things we need often
  Dart_PersistentHandle _void_pointer_type;
  Dart_PersistentHandle _void_pointer_optional_type;
  Dart_PersistentHandle _void_pointer_pointer_type;
  Dart_PersistentHandle _variant_type;
};