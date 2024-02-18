#include "gde_dart_converters.h"

#include <dart_api.h>

#include "dart_helpers.h"
#include "dart_bindings.h"
#include "gde_wrapper.h"
#include "godot_string_helpers.h"

void *get_object_address(Dart_Handle engine_handle) {
  Dart_Handle native_ptr = Dart_GetField(engine_handle, Dart_NewStringFromCString("nativePtr"));
  if (Dart_IsError(native_ptr)) {
    GD_PRINT_ERROR(Dart_GetError(native_ptr));
    return nullptr;
  }
  Dart_Handle address = Dart_GetField(native_ptr, Dart_NewStringFromCString("address"));
  if (Dart_IsError(address)) {
    GD_PRINT_ERROR(Dart_GetError(address));
    return nullptr;
  }
  uint64_t object_ptr = 0;
  Dart_IntegerToUint64(address, &object_ptr);

  return reinterpret_cast<void *>(object_ptr);
}

void gde_method_info_from_dart(Dart_Handle dart_method_info, GDExtensionMethodInfo *method_info) {
  DART_CHECK(dart_name, Dart_GetField(dart_method_info, Dart_NewStringFromCString("name")), "Failed to get name");  
  method_info->name = create_godot_string_name_ptr(dart_name);
  // TODO: id?
  method_info->id = 0;

  DART_CHECK(dart_ret_prop_info, Dart_GetField(dart_method_info, Dart_NewStringFromCString("returnInfo")),
             "Failed to get return info");
  if (Dart_IsNull(dart_ret_prop_info)) {
    method_info->return_value = {
        GDEXTENSION_VARIANT_TYPE_NIL, new godot::StringName(), new godot::StringName(), 0, new godot::String(), 0,
    };
  } else {
    gde_property_info_from_dart(dart_ret_prop_info, &method_info->return_value);
  }

  DART_CHECK(dart_args_list, Dart_GetField(dart_method_info, Dart_NewStringFromCString("args")), "Failed to get args");
  intptr_t args_length = 0;
  Dart_ListLength(dart_args_list, &args_length);
  method_info->argument_count = args_length;
  if (args_length > 0) {
    method_info->arguments = new GDExtensionPropertyInfo[args_length];
    for (intptr_t i = 0; i < args_length; ++i) {
      DART_CHECK(dart_arg, Dart_ListGetAt(dart_args_list, i), "Failed to get arg at index");
      gde_property_info_from_dart(dart_arg, &method_info->arguments[i]);
    }
  } else {
    method_info->arguments = nullptr;
  }

  // TDOO: Default Arguments
  method_info->default_arguments = nullptr;
  method_info->default_argument_count = 0;
}

void gde_free_method_info_fields(GDExtensionMethodInfo *method_info) {
  if (method_info->name != nullptr) {
    delete reinterpret_cast<godot::StringName*>(method_info->name);
  }

  gde_free_property_info_fields(&method_info->return_value);

  if (method_info->arguments != nullptr) {
    for (intptr_t i = 0; i < method_info->argument_count; ++i) {
      gde_free_property_info_fields(&method_info->arguments[i]);
    }

    delete[] method_info->arguments;
  }
}

void gde_property_info_from_dart(Dart_Handle dart_property_info, GDExtensionPropertyInfo *prop_info) {
  DART_CHECK(dart_type_info, Dart_GetField(dart_property_info, Dart_NewStringFromCString("typeInfo")),
             "Failed to get type info");
  TypeInfo type_info;
  type_info_from_dart(&type_info, dart_type_info);
  prop_info->type = type_info.variant_type;
  prop_info->class_name = type_info.type_name;

  DART_CHECK(dart_name, Dart_GetField(dart_property_info, Dart_NewStringFromCString("name")), "Failed to get name");
  godot::StringName *name = create_godot_string_name_ptr(dart_name);
  prop_info->name = name;

  DART_CHECK(dart_property_hint, Dart_GetField(dart_property_info, Dart_NewStringFromCString("hint")),
             "Failed to get hint");
  uint64_t hint = 0;
  Dart_IntegerToUint64(dart_property_hint, &hint);
  prop_info->hint = uint32_t(hint);

  DART_CHECK(dart_hint_string, Dart_GetField(dart_property_info, Dart_NewStringFromCString("hintString")),
             "Failed to get hint string");
  godot::String *hint_string = create_godot_string_ptr(dart_hint_string);
  prop_info->hint_string = hint_string;

  DART_CHECK(dart_flags, Dart_GetField(dart_property_info, Dart_NewStringFromCString("flags")), "Failed to get hint");
  uint64_t flags = 0;
  Dart_IntegerToUint64(dart_flags, &flags);
  prop_info->usage = uint32_t(flags);
}

// Only use for freeing propery info fiels made with gde_property_info_from_dart
void gde_free_property_info_fields(GDExtensionPropertyInfo *prop_info) {
  if (prop_info->name) {
    delete reinterpret_cast<godot::StringName *>(prop_info->name);
  }
  if (prop_info->hint_string) {
    delete reinterpret_cast<godot::String *>(prop_info->hint_string);
  }
}
