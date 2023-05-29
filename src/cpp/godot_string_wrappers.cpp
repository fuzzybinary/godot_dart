#include "godot_string_wrappers.h"
#include "gde_wrapper.h"
#include <malloc.h>

// *****
// GDString
// *****

GDExtensionPtrConstructor GDString::_constructor = nullptr;
GDExtensionPtrConstructor GDString::_copy_constructor = nullptr;
GDExtensionPtrConstructor GDString::_from_gdstringname_constructor = nullptr;
GDExtensionPtrDestructor GDString::_destructor = nullptr;

void GDString::init_from_gde(const GDExtensionInterface *gde) {
  _constructor = gde->variant_get_ptr_constructor(GDEXTENSION_VARIANT_TYPE_STRING, 0);
  _copy_constructor = gde->variant_get_ptr_constructor(GDEXTENSION_VARIANT_TYPE_STRING, 1);
  _from_gdstringname_constructor = gde->variant_get_ptr_constructor(GDEXTENSION_VARIANT_TYPE_STRING, 2);
  _destructor = gde->variant_get_ptr_destructor(GDEXTENSION_VARIANT_TYPE_STRING);
}

GDString::GDString() {
  _constructor(&_opaque, nullptr);
}

GDString::GDString(const GDString &from) {
  const GDExtensionConstTypePtr args[1] = {&from};
  _copy_constructor(&_opaque, args);
}

GDString::GDString(const GDStringName &from) {
  const GDExtensionConstTypePtr args[1] = {&from};
  _from_gdstringname_constructor(&_opaque, args);
}

GDString::GDString(const Dart_Handle &from_dart) {
    if (Dart_IsNull(from_dart)) {
      _constructor(&_opaque, nullptr);
      return;
    }

    const char *dart_cstring;
    Dart_Handle result = Dart_StringToCString(from_dart, &dart_cstring);
    if (Dart_IsError(result)) {
      GD_PRINT_ERROR("GodotDart: Error converting Dart String property to Godot String");
      GD_PRINT_ERROR(Dart_GetError(result));
      _constructor(&_opaque, nullptr);
      return;
    }
  
    GDEWrapper *gde = GDEWrapper::instance();
    gde->gde()->string_new_with_utf8_chars(&_opaque, dart_cstring);
}

GDString::GDString(const char *from) {
  GDEWrapper* wrapper = GDEWrapper::instance();
  wrapper->gde()->string_new_with_utf8_chars(&_opaque, from);
 
}

GDString::~GDString() {
  _destructor(&_opaque);
}

Dart_Handle GDString::to_dart() const {
  GDEWrapper *gde = GDEWrapper::instance();
  GDExtensionInt length = gde->gde()->string_to_utf16_chars(_opaque, nullptr, 0);
  char16_t *temp = (char16_t *)_alloca(sizeof(char16_t) * (length + 1));
  gde->gde()->string_to_utf16_chars(_opaque, temp, length);
  temp[length] = 0;
  
  Dart_Handle dart_string = Dart_NewStringFromUTF16((uint16_t *)temp, length);
  if (Dart_IsError(dart_string)) {
    GD_PRINT_ERROR("GodotDart: Error converting String to Dart String: ");
    GD_PRINT_ERROR(Dart_GetError(dart_string));
    dart_string = Dart_Null();
  }

  return dart_string;
}

// *****
// GDStringName
// *****

GDExtensionPtrConstructor GDStringName::_constructor = nullptr;
GDExtensionPtrConstructor GDStringName::_copy_constructor = nullptr;
GDExtensionPtrConstructor GDStringName::_from_gdstring_constructor = nullptr;
GDExtensionPtrDestructor GDStringName::_destructor = nullptr;

void GDStringName::init_from_gde(const GDExtensionInterface *gde) {
  _constructor = gde->variant_get_ptr_constructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME, 0);
  _copy_constructor = gde->variant_get_ptr_constructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME, 1);
  _from_gdstring_constructor = gde->variant_get_ptr_constructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME, 2);
  _destructor = gde->variant_get_ptr_destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME);
}

GDStringName::GDStringName() {
  _constructor(&_opaque, nullptr);
}

GDStringName::GDStringName(const GDStringName &from) {
  const GDExtensionConstTypePtr args[1] = {&from};
  _copy_constructor(&_opaque, args);
}

GDStringName::GDStringName(const GDString &from) {
  const GDExtensionConstTypePtr args[1] = {&from};
  _from_gdstring_constructor(&_opaque, args);
}


GDStringName::GDStringName(const Dart_Handle &from_dart) {
  if (Dart_IsNull(from_dart)) {
    _constructor(&_opaque, nullptr);
    return;
  }

  GDString str(from_dart);
  const GDExtensionConstTypePtr args[1] = {&str};
  _from_gdstring_constructor(&_opaque, args);
}

GDStringName::GDStringName(const char *from) {
  GDString str(from);
  const GDExtensionConstTypePtr args[1] = {&str};
  _from_gdstring_constructor(&_opaque, args);
}

GDStringName::~GDStringName() {
  _destructor(&_opaque);
}

Dart_Handle GDStringName::to_dart() const {
  GDString gd_string(*this);
  return gd_string.to_dart();
}