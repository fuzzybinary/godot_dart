#pragma once

#include <dart_api.h>

#include <godot/gdextension_interface.h>

// Because Godot has us switching between strong and weak
// persitent handles, encapsulate that into a custom GC handle
class DartGodotInstanceBinding {
public:
  DartGodotInstanceBinding(void *token, GDExtensionObjectPtr godot_object)
      : _is_weak(false), _persistent_handle(nullptr), _godot_object(godot_object), _token(token) {
  }

  ~DartGodotInstanceBinding();

  bool is_initialized() const {
    return _persistent_handle != nullptr;
  }
  bool is_weak() const {
    return _is_weak;
  }

  Dart_Handle get_dart_object();
  GDExtensionObjectPtr get_godot_object() const {
    return _godot_object;
  }

  void initialize(Dart_Handle dart_object, bool is_refcounted);
  void create_dart_object();
  bool convert_to_strong();
  bool convert_to_weak();

  static GDExtensionInstanceBindingCallbacks engine_binding_callbacks;

private:
  bool _is_weak;
  void *_persistent_handle;
  GDExtensionObjectPtr _godot_object;
  void *_token;
};