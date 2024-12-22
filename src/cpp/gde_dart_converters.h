#pragma once

#include <gdextension_interface.h>

#include <dart_api.h>

struct TypeInfo {
  GDExtensionStringNamePtr type_name = nullptr;
  // Can be null
  Dart_Handle parent_type = nullptr;
  GDExtensionVariantType variant_type = GDEXTENSION_VARIANT_TYPE_NIL;
  // Can be null
  const GDExtensionInstanceBindingCallbacks *binding_callbacks = nullptr;
};

// Actually defined in dart_bindings.cpp
void type_info_from_dart(TypeInfo *type_info, Dart_Handle dart_type_info);

void *get_object_address(Dart_Handle variant_handle);

void gde_method_info_from_dart(Dart_Handle dart_method_info, GDExtensionMethodInfo *method_info);
void gde_free_method_info_fields(GDExtensionMethodInfo *method_info);

void gde_property_info_from_dart(Dart_Handle dart_property_info, GDExtensionPropertyInfo *prop_info);
void gde_free_property_info_fields(GDExtensionPropertyInfo *prop_info);