#pragma once

#include <godot/gdextension_interface.h>
#include <dart_api.h>

// These are simplified wrappers around Godot's String and StringName classes, which are the most
// common objects we need to create when exchanging data from Dart to Godot. Creating these wrappers
// simplifies some of the RAII and destruction of these objects

class GDStringName;

class GDString {
public:
  static const size_t MAX_SIZE = 8;

  GDString();
  GDString(const GDString &from);
  GDString(const GDStringName &from);
  GDString(const Dart_Handle &from_dart);
  GDString(const char *from);  
  ~GDString();

  GDExtensionStringPtr _native_ptr() const {
    return const_cast<uint8_t(*)[MAX_SIZE]>(&_opaque);
  }

  Dart_Handle to_dart() const;

  static void init();

private:
  uint8_t _opaque[MAX_SIZE] = {0};

  static GDExtensionPtrConstructor _constructor;
  static GDExtensionPtrConstructor _copy_constructor;
  static GDExtensionPtrConstructor _from_gdstringname_constructor;
  static GDExtensionPtrDestructor _destructor;
};

class GDStringName {
public:
  static const size_t MAX_SIZE = 8;

  GDStringName();
  GDStringName(const GDStringName &from);
  GDStringName(const GDString &from);
  GDStringName(const Dart_Handle &from_dart);
  GDStringName(const char *from);
  ~GDStringName();

  GDExtensionStringNamePtr _native_ptr() const {
    return const_cast<uint8_t(*)[MAX_SIZE]>(&_opaque);
  }

  Dart_Handle to_dart() const;

  static void init();

private:
  uint8_t _opaque[MAX_SIZE];

  static GDExtensionPtrConstructor _constructor;
  static GDExtensionPtrConstructor _from_gdstring_constructor;
  static GDExtensionPtrConstructor _copy_constructor;
  static GDExtensionPtrDestructor _destructor;
};