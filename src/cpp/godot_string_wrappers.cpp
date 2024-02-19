#include "godot_string_wrappers.h"
#include "gde_wrapper.h"

#include "dart_helpers.h"

godot::StringName create_godot_string_name(const Dart_Handle &from_dart) {
  if (Dart_IsNull(from_dart)) {
    return godot::StringName();
  }

  const char *dart_cstring;
  Dart_Handle result = Dart_StringToCString(from_dart, &dart_cstring);
  if (Dart_IsError(result)) {
    GD_PRINT_ERROR("GodotDart: Error converting Dart String property to Godot String");
    GD_PRINT_ERROR(Dart_GetError(result));
    return godot::StringName();
  }

  return godot::StringName(godot::String::utf8(dart_cstring));
}

godot::StringName* create_godot_string_name_ptr(const Dart_Handle &from_dart) {
  if (Dart_IsNull(from_dart)) {
    return new godot::StringName();
  }

  const char *dart_cstring;
  Dart_Handle result = Dart_StringToCString(from_dart, &dart_cstring);
  if (Dart_IsError(result)) {
    GD_PRINT_ERROR("GodotDart: Error converting Dart String property to Godot String");
    GD_PRINT_ERROR(Dart_GetError(result));
    return new godot::StringName();
  }

  return new godot::StringName(godot::String::utf8(dart_cstring));
}

Dart_Handle to_dart_string(const godot::StringName &from_godot) {
  godot::String godot_string(from_godot);
  godot::CharString utf8 = godot_string.utf8();
  
  Dart_Handle dart_string = Dart_NewStringFromUTF8((const uint8_t *)utf8.get_data(), utf8.length());
  if (Dart_IsError(dart_string)) {
    GD_PRINT_ERROR("GodotDart: Error converting String to Dart String: ");
    GD_PRINT_ERROR(Dart_GetError(dart_string));
    dart_string = Dart_Null();
  }

  return dart_string;
}

godot::String create_godot_string(const Dart_Handle &from_dart) {
  if (Dart_IsNull(from_dart)) {
    return godot::String();
  }

  const char *dart_cstring;
  Dart_Handle result = Dart_StringToCString(from_dart, &dart_cstring);
  if (Dart_IsError(result)) {
    GD_PRINT_ERROR("GodotDart: Error converting Dart String property to Godot String");
    GD_PRINT_ERROR(Dart_GetError(result));
    return godot::String();
  }

  return godot::String::utf8(dart_cstring);
}

godot::String *create_godot_string_ptr(const Dart_Handle &from_dart) {
  if (Dart_IsNull(from_dart)) {
    return new godot::String();
  }

  const char *dart_cstring;
  Dart_Handle result = Dart_StringToCString(from_dart, &dart_cstring);
  if (Dart_IsError(result)) {
    GD_PRINT_ERROR("GodotDart: Error converting Dart String property to Godot String");
    GD_PRINT_ERROR(Dart_GetError(result));
    return new godot::String();
  }

  return new godot::String(dart_cstring);
}

Dart_Handle to_dart_string(const godot::String&from_godot) {
  godot::CharString utf8 = from_godot.utf8();

  Dart_Handle dart_string = Dart_NewStringFromUTF8((const uint8_t *)utf8.get_data(), utf8.length());
  if (Dart_IsError(dart_string)) {
    GD_PRINT_ERROR("GodotDart: Error converting String to Dart String: ");
    GD_PRINT_ERROR(Dart_GetError(dart_string));
    dart_string = Dart_Null();
  }

  return dart_string;
}
