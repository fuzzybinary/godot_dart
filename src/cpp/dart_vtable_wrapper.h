#pragma once

#include <godot/gdextension_interface.h>

namespace dart_vtable_wrapper {

void init_virtual_thunks();
GDExtensionClassCallVirtual get_wrapped_virtual(GDExtensionClassCallVirtual unwrapped_virtual);

} // namespace dart_vtable_wrapper