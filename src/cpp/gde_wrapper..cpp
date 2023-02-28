#include "gde_wrapper.h"

GDEWrapper *GDEWrapper::_instance = nullptr;

void GDEWrapper::create_instance(const GDExtensionInterface *gde_interface, GDExtensionClassLibraryPtr library) {
  _instance = new GDEWrapper();

  _instance->_gde_interface = gde_interface;
  _instance->_library = library;
}

bool GDEWrapper::initialize() {
  _gdstring_constructor = _gde_interface->variant_get_ptr_constructor(GDEXTENSION_VARIANT_TYPE_STRING, 0);
  if (_gdstring_constructor == nullptr) {
    GD_PRINT_ERROR("GodotDart: Initialization Error (cannot retrive `String` "
                   "constructor)");
    return false;
  }

  _gdstring_destructor = _gde_interface->variant_get_ptr_destructor(GDEXTENSION_VARIANT_TYPE_STRING);
  if (_gdstring_destructor == nullptr) {
    GD_PRINT_ERROR("GodotDart: Initialization Error (cannot retrive `String` destructor)");
    return false;
  }

  _gdstringname_from_gdstring_constructor =
      _gde_interface->variant_get_ptr_constructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME, 2);
  if (_gdstringname_from_gdstring_constructor == nullptr) {
    GD_PRINT_ERROR("GodotDart: Initialization Error (cannot retrive `StringName` "
                   "constructor)");
    return false;
  }
  _gdstringname_destructor = _gde_interface->variant_get_ptr_destructor(GDEXTENSION_VARIANT_TYPE_STRING_NAME);
  if (_gdstringname_destructor == nullptr) {
    GD_PRINT_ERROR("GodotDart: Initialization Error (cannot retrive `StringName` "
                   "destructor)");
    return false;
  }

  return true;
}

void GDEWrapper::gd_string_name_new(GDExtensionStringNamePtr out, const char *cstr) {
  uint8_t as_gdstring[GD_STRING_MAX_SIZE];
  _gde_interface->string_new_with_utf8_chars(&as_gdstring, cstr);

  const GDExtensionConstTypePtr args[1] = {&as_gdstring};
  _gdstringname_from_gdstring_constructor(out, args);
  _gdstring_destructor(&as_gdstring);
}

void GDEWrapper::gd_string_name_destructor(GDExtensionStringNamePtr ptr) {
  _gdstringname_destructor(ptr);
}

void GDEWrapper::gd_string_new(GDExtensionTypePtr out) {
  _gdstring_constructor(out, nullptr);
}

void GDEWrapper::gd_string_destructor(GDExtensionTypePtr ptr) {
  _gdstring_destructor(ptr);
}