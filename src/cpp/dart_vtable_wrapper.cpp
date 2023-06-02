#include "dart_vtable_wrapper.h"

#include <unordered_map>

#include "dart_bindings.h"

// Because Godot needs pointers to functions to make virtual calls, and we need to wrap
// the calls to thunk to the main thread, we use template metaprogramming to
// generate as many wrapping functions as we can
//
// When Godot requests a virtual, we get the correct function pointer from Dart and store it
// in the next available index of the array, and return its corresponding generated wrapper
// function. When the wrapper function is called, it will get the correct Dart function and
// execute it on the Dart thread.
//
// To assist in lookup, we use the address of the correct Dart virtual function as a key
// to lookup the index. Godot caches these funciton pointers, but only per-object, and
// the functions provided from Dart are static per-class.

// We are limited in the number of segments we can have in the .obj without special compiler
// flags, and this may be compiler specific (need to experiment)
#define MAX_VIRTUAL 512

namespace dart_vtable_wrapper {

std::unordered_map<intptr_t, uint32_t> thunk_map;
uint32_t next_available_thunk = 0;

GDExtensionClassCallVirtual virtual_thunks[MAX_VIRTUAL] = {0};
GDExtensionClassCallVirtual dart_virtual_func[MAX_VIRTUAL] = {0};

template <int i>
void virtual_thunk(GDExtensionClassInstancePtr p_instance, const GDExtensionConstTypePtr *p_args,
                   GDExtensionTypePtr r_ret) {
  GodotDartBindings *bindings = GodotDartBindings::instance();
  if (!bindings) {
    // oooff
    return;
  }

  GDExtensionClassCallVirtual dart_call = dart_virtual_func[i];
  if (dart_call == nullptr) {
    return;
  }

  bindings->execute_on_dart_thread([&]() { dart_call(p_instance, p_args, r_ret); });
}

template <int i> void _init_virtual_thunks() {
  virtual_thunks[i] = &virtual_thunk<i>;
  _init_virtual_thunks<i - 1>();
}

template <> void _init_virtual_thunks<-1>() {
}

void init_virtual_thunks() {
  _init_virtual_thunks<MAX_VIRTUAL - 1>();
}

GDExtensionClassCallVirtual get_wrapped_virtual(GDExtensionClassCallVirtual unwrapped_virtual) {
  const auto &indexItr = thunk_map.find(reinterpret_cast<intptr_t>(unwrapped_virtual));
  if (indexItr != thunk_map.end()) {
    uint32_t index = indexItr->second;
    return virtual_thunks[index];
  }

  if (next_available_thunk >= MAX_VIRTUAL) {
    return nullptr;
  }

  GDExtensionClassCallVirtual thunk = virtual_thunks[next_available_thunk];
  dart_virtual_func[next_available_thunk] = unwrapped_virtual;
  thunk_map[reinterpret_cast<intptr_t>(unwrapped_virtual)] = next_available_thunk;

  next_available_thunk++;

  return thunk;
}

} // namespace dart_vtable_wrapper
