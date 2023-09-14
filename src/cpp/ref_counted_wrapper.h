#pragma once

#include <godot/gdextension_interface.h>

// This serves as a wrapper around RefCounted objects. Since
// we don't import all of godot-cpp, we use this to wrap the
// functions we need to access from RefCounted
class RefCountedWrapper
{
public:
  explicit RefCountedWrapper(GDExtensionObjectPtr object) : _object(object) {
  
  }

  bool init_ref();
  bool reference();
  bool unreference();
  int32_t get_reference_count();

  static void init();

private:
  GDExtensionObjectPtr _object;

  static GDExtensionMethodBindPtr init_ref_ptr_call;
  static GDExtensionMethodBindPtr reference_ptr_call;
  static GDExtensionMethodBindPtr unreference_ptr_call;
  static GDExtensionMethodBindPtr get_reference_count_ptr_call;
};