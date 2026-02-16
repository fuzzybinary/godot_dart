#include "dart_instance_binding.h"

#include <godot_cpp/classes/object.hpp>
#include <godot_cpp/godot.hpp>

#include "dart_bindings.h"
#include "dart_helpers.h"
#include "gde_c_interface.h"
#include "godot_string_wrappers.h"
#include "ref_counted_wrapper.h"

void gde_weak_finalizer(void *isolate_callback_data, void *peer) {
  if (peer == nullptr) {
    return;
  }

  DartGodotInstanceBinding *binding = (DartGodotInstanceBinding *)peer;
  RefCountedWrapper ref_counted(binding->get_godot_object());
  if (ref_counted.unreference()) {
    gde_object_destroy(binding->get_godot_object());
  } else {
    // TODO: Reset the binding so it can recreate the Dart object?
    assert(false);
  }
}

std::map<intptr_t, DartGodotInstanceBinding *> DartGodotInstanceBinding::s_instanceMap;

DartGodotInstanceBinding::~DartGodotInstanceBinding() {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  // Can't do anything as Dart is shutdown
  if (bindings == nullptr) {
    return;
  }

  s_instanceMap.erase((intptr_t)this);

  if (_persistent_handle) {
    // If we have an isolate group, we're likely running on the Finalizer.
    // Don't attempt to execute on the Dart isolate if this is the case
    // (it might be already doing things)
    Dart_IsolateGroup current_isolate_group = Dart_CurrentIsolateGroup();
    if (current_isolate_group) {
      delete_dart_handle();
    } else {
      GodotDartBindings::instance()->execute_on_dart_thread([&] { delete_dart_handle(); });
    }
    bindings->remove_pending_ref_change(this);
  }
}

void DartGodotInstanceBinding::delete_dart_handle() {
  if (_is_weak) {
    Dart_DeleteWeakPersistentHandle((Dart_WeakPersistentHandle)_persistent_handle);
  } else {
    Dart_DeletePersistentHandle((Dart_PersistentHandle)_persistent_handle);
  }
}

void DartGodotInstanceBinding::initialize(Dart_Handle dart_object, bool is_refcounted) {
  s_instanceMap[(intptr_t)this] = this;
  _is_refcounted = is_refcounted;

  if (is_refcounted) {
    RefCountedWrapper ref_counted(_godot_object);

    // Create our initial handle weak before calling init_ref, which may callback into reference
    _is_weak = true;
    _persistent_handle = (void *)Dart_NewWeakPersistentHandle(dart_object, this, 0, gde_weak_finalizer);
    ref_counted.init_ref();

    int32_t count = ref_counted.get_reference_count();
    if (_is_weak && count > 1) {
      // Not the first reference. Hold strong until we're the only reference
      convert_to_strong();
    }
  } else {
    // Not refcounted, always hold strong
    _is_weak = false;
    _persistent_handle = (void *)Dart_NewPersistentHandle(dart_object);
  }
}

Dart_Handle DartGodotInstanceBinding::get_dart_object() {
  if (!is_initialized()) {
    create_dart_object();
  }

  if (_is_weak) {
    return Dart_HandleFromWeakPersistent((Dart_WeakPersistentHandle)_persistent_handle);
  }

  return Dart_HandleFromPersistent((Dart_PersistentHandle)_persistent_handle);
}

bool DartGodotInstanceBinding::convert_to_strong() {
  if (!_is_weak) return true;

  DartBlockScope scope;

  Dart_Handle object = Dart_HandleFromWeakPersistent((Dart_WeakPersistentHandle)_persistent_handle);
  if (Dart_IsNull(object)) {
    return false;
  }
  Dart_PersistentHandle strong_handle = Dart_NewPersistentHandle(object);
  Dart_DeleteWeakPersistentHandle((Dart_WeakPersistentHandle)_persistent_handle);

  _persistent_handle = strong_handle;
  _is_weak = false;

  return true;
}

bool DartGodotInstanceBinding::convert_to_weak() {
  if (_is_weak) return true;

  DartBlockScope scope;

  Dart_Handle object = Dart_HandleFromPersistent((Dart_PersistentHandle)_persistent_handle);
  if (Dart_IsNull(object)) {
    return false;
  }
  Dart_WeakPersistentHandle weak_handle = Dart_NewWeakPersistentHandle(object, this, 0, gde_weak_finalizer);
  Dart_DeletePersistentHandle((Dart_PersistentHandle)_persistent_handle);

  _persistent_handle = weak_handle;
  _is_weak = true;

  return true;
}

void DartGodotInstanceBinding::create_dart_object() {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings && _godot_object != nullptr) {
    return;
  }

  bindings->execute_on_dart_thread([&] {
    Dart_Handle dart_type_info = Dart_HandleFromPersistent(_dart_type_info);
    DART_CHECK(dart_type, Dart_GetField(dart_type_info, Dart_NewStringFromCString("type")),
               "Failed to get name from class info");
    DART_CHECK(new_obj, bindings->new_godot_owned_object(dart_type, _godot_object), "Error creating bindings");
  });

  // tie_dart_to_native should have called back in during creation
  assert(_persistent_handle != nullptr);
}

/* Binding callbacks used for Engine types implemented in Godot and wrapped in Dart */

static void *__engine_binding_create_callback(void *p_token, void *p_instance) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  godot::StringName class_name;

  DartGodotInstanceBinding *binding = nullptr;
  if (godot::internal::gdextension_interface_object_get_class_name(
          p_instance, p_token, reinterpret_cast<GDExtensionStringNamePtr>(class_name._native_ptr()))) {
    bindings->execute_on_dart_thread([&] {
      Dart_EnterScope();

      Dart_Handle type_name = to_dart_string(class_name);
      DART_CHECK(type_info, bindings->get_dart_type_info_by_name(type_name), "Error finding Dart type");
      // TODO: Since DartTypeInfo is ephemeral (it's recreated on hot reload), it might be good to have bindings
      // hold onto the Type, not the TypeInfo. Bindings only use this for object creation, so holding onto the
      // type info isn't needed.
      if (!Dart_IsNull(type_info)) {
        Dart_PersistentHandle persistent_type_info = Dart_NewPersistentHandle(type_info);
        binding = new DartGodotInstanceBinding(persistent_type_info, p_instance);
      }

      Dart_ExitScope();
    });
  }

  return binding;
}

static void __engine_binding_free_callback(void *p_token, void *p_instance, void *p_binding) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  DartGodotInstanceBinding *binding = reinterpret_cast<DartGodotInstanceBinding *>(p_binding);
  if (!bindings) {
    // Dart is already shutdown, but let's not leak memory
    delete binding;
    return;
  }

  if (binding->is_weak() || bindings->_is_stopping) {
    // If the binding is weak or we're shutting down, there's a possibility Dart is asking us
    // to kill this in a way that does not allow us to call back into any other Dart code other
    // than deleting the reference. So just do that and be done with it.
    delete binding;
    return;
  }

  bindings->execute_on_dart_thread([&] {
    DartBlockScope scope;

    Dart_Handle dart_object = binding->get_dart_object();

    if (!Dart_IsNull(dart_object)) {
      Dart_Handle result = Dart_Invoke(dart_object, Dart_NewStringFromCString("detachOwner"), 0, nullptr);
      if (Dart_IsError(result)) {
        GD_PRINT_ERROR("GodotDart: Error detaching owner during instance free: ");
        GD_PRINT_ERROR(Dart_GetError(result));
      }
    }

    delete binding;
  });
}

static GDExtensionBool __engine_binding_reference_callback(void *p_token, void *p_instance,
                                                           GDExtensionBool p_reference) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    return true;
  }

  DartGodotInstanceBinding *engine_binding = reinterpret_cast<DartGodotInstanceBinding *>(p_instance);
  godot::Object *godot_object = reinterpret_cast<godot::Object *>(engine_binding->get_godot_object());
  assert(engine_binding->is_initialized());

  RefCountedWrapper ref_counted(godot_object);
  int refcount = ref_counted.get_reference_count();

  bool is_dieing = refcount == 0;
  if (bindings->_is_stopping) {
    return is_dieing;
  }

  if (engine_binding->is_weak() && is_dieing) {
    // Fast out, can't do anything with dieing weak pointers.
    return true;
  }

  // If we're on the finalizer, we can't run any conversions, we'll have to hold them until we're done
  // performing finalization
  bool is_finalizer = Dart_CurrentIsolate() == nullptr && Dart_CurrentIsolateGroup() != nullptr;

  if (p_reference) {
    // Refcount incremented, change our reference to strong to prevent Dart from finalizing
    if (refcount > 1 && engine_binding->is_weak()) {
      if (!is_finalizer) {
        bindings->execute_on_dart_thread([&] { engine_binding->convert_to_strong(); });
      } else {
        bindings->add_pending_ref_change(engine_binding);
      }
    }

    is_dieing = false;
  } else {
    if (refcount == 1 && !engine_binding->is_weak()) {
      if (!is_finalizer) {
        bindings->execute_on_dart_thread([&] { engine_binding->convert_to_weak(); });
      } else {
        bindings->add_pending_ref_change(engine_binding);
      }

      is_dieing = false;
    }
  }

  return is_dieing;
}

GDExtensionInstanceBindingCallbacks DartGodotInstanceBinding::engine_binding_callbacks = {
    __engine_binding_create_callback,
    __engine_binding_free_callback,
    __engine_binding_reference_callback,
};