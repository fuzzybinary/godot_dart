#include "ref_counted_wrapper.h"

#include "gde_c_interface.h"
#include "godot_string_wrappers.h"

GDExtensionMethodBindPtr RefCountedWrapper::init_ref_ptr_call = nullptr;
GDExtensionMethodBindPtr RefCountedWrapper::reference_ptr_call = nullptr;
GDExtensionMethodBindPtr RefCountedWrapper::unreference_ptr_call = nullptr;
GDExtensionMethodBindPtr RefCountedWrapper::get_reference_count_ptr_call = nullptr;

bool RefCountedWrapper::init_ref() {
  bool ret = false;
  gde_object_method_bind_ptrcall(init_ref_ptr_call, _object, nullptr, &ret);

  return ret;
}

bool RefCountedWrapper::reference() {
  bool ret = false;
  gde_object_method_bind_ptrcall(reference_ptr_call, _object, nullptr, &ret);

  return ret;
}

bool RefCountedWrapper::unreference() {
  bool ret = false;
  gde_object_method_bind_ptrcall(unreference_ptr_call, _object, nullptr, &ret);

  return ret;
}

int RefCountedWrapper::get_reference_count() {
  int64_t ret = 0;
  gde_object_method_bind_ptrcall(get_reference_count_ptr_call, _object, nullptr, &ret);

  return ret;
}

void RefCountedWrapper::init() {
  const GDExtensionInt class_hash = 2240911060;
  godot::StringName class_name("RefCounted");
  init_ref_ptr_call =
      gde_classdb_get_method_bind(class_name._native_ptr(), godot::StringName("init_ref")._native_ptr(), class_hash);
  reference_ptr_call =
      gde_classdb_get_method_bind(class_name._native_ptr(), godot::StringName("reference")._native_ptr(), class_hash);
  unreference_ptr_call =
      gde_classdb_get_method_bind(class_name._native_ptr(), godot::StringName("unreference")._native_ptr(), class_hash);
  get_reference_count_ptr_call = gde_classdb_get_method_bind(
      class_name._native_ptr(), godot::StringName("get_reference_count")._native_ptr(), 3905245786);
}
