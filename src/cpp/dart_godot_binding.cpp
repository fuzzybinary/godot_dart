#include "dart_godot_binding.h"

#include "dart_helpers.h"
#include "dart_bindings.h"
#include "ref_counted_wrapper.h"
#include "gde_c_interface.h"

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

DartGodotInstanceBinding::~DartGodotInstanceBinding() {
  // Can't do anything as Dart is shutdown
  if (GodotDartBindings::instance() == nullptr) return;

  if (_persistent_handle) {
    if (_is_weak) {
      Dart_DeleteWeakPersistentHandle((Dart_WeakPersistentHandle)_persistent_handle);
    } else {
      Dart_DeletePersistentHandle((Dart_PersistentHandle)_persistent_handle);
    }
  }
}

void DartGodotInstanceBinding::initialize(Dart_Handle dart_object, bool is_refcounted) {
  if (is_refcounted) {
    RefCountedWrapper ref_counted(_godot_object);
    int32_t refcount = ref_counted.get_reference_count();
    if (refcount == 0) {
      // We're the first reference. Hooray for us!
      // Hold weak until more things reference
      _is_weak = true;
      _persistent_handle = (void *)Dart_NewWeakPersistentHandle(dart_object, this, 0, gde_weak_finalizer);
      ref_counted.init_ref();
    } else {
      // Not the first reference. Hold strong until we're the only reference
      _is_weak = false;
      _persistent_handle = (void *)Dart_NewPersistentHandle(dart_object);
      ref_counted.reference();
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
    Dart_PersistentHandle persistent_type = reinterpret_cast<Dart_PersistentHandle>(_token);
    Dart_Handle dart_type = Dart_HandleFromPersistent(persistent_type);

    Dart_Handle dart_pointer = bindings->new_dart_void_pointer(_godot_object);
    Dart_Handle args[1] = {dart_pointer};
    DART_CHECK(new_obj, Dart_New(dart_type, Dart_NewStringFromCString("withNonNullOwner"), 1, args),
               "Error creating bindings");
  });

  // tie_dart_to_native should have called back in during creation
  assert(_persistent_handle != nullptr);
}

/* Binding callbacks used for Engine types implemented in Godot and wrapped in Dart */

static void *__engine_binding_create_callback(void *p_token, void *p_instance) {
  DartGodotInstanceBinding *binding = new DartGodotInstanceBinding(p_token, p_instance);
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

      delete binding;
    }
  });
}

static GDExtensionBool __engine_binding_reference_callback(void *p_token, void *p_instance,
                                                           GDExtensionBool p_reference) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    return true;
  }

  DartGodotInstanceBinding *engine_binding = reinterpret_cast<DartGodotInstanceBinding *>(p_instance);
  if (!engine_binding->is_initialized()) {
    engine_binding->create_dart_object();
  }

  RefCountedWrapper refcounted(engine_binding->get_godot_object());
  int refcount = refcounted.get_reference_count();

  bool retValue = refcount == 0;
  if (bindings->_is_stopping) {
    return retValue;
  }

  bindings->execute_on_dart_thread([&] {
    DartBlockScope scope;

    if (p_reference) {
      // Refcount incremented, change our reference to strong to prevent Dart from finalizing
      if (refcount > 1 && engine_binding->is_weak()) {
        engine_binding->convert_to_strong();
      }

      retValue = false;
    } else {
      if (refcount == 1 && !engine_binding->is_weak()) {
        // We're the only ones holding on, switch us to weak so Dart will delete when it
        // has no more references
        engine_binding->convert_to_weak();

        retValue = false;
      }
    }
  });

  return retValue;
}

GDExtensionInstanceBindingCallbacks DartGodotInstanceBinding::engine_binding_callbacks = {
    __engine_binding_create_callback,
    __engine_binding_free_callback,
    __engine_binding_reference_callback,
};