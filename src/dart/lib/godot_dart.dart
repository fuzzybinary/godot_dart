/// Library for supporting Dart in the Godot Game Engine
library godot_dart;

import 'dart:ffi';

import 'godot_dart.dart';

export 'src/gdextension.dart';
export 'src/gdextension_bindings.dart';
export 'src/gen/string.dart';
export 'src/gen/string_name.dart';
export 'src/variant.dart';

// ignore: unused_element
late GodotDart _globalExtension;

// ignore: unused_element
void _registerGodot(int gdeAddress, int libraryAddress) {
  final extensionInterface =
      Pointer<GDExtensionInterface>.fromAddress(gdeAddress);
  final libraryPtr = GDExtensionClassLibraryPtr.fromAddress(libraryAddress);

  // TODO: Assert everything is how we expect..
  _globalExtension = GodotDart(extensionInterface, libraryPtr);

  initVariantBindings(extensionInterface.ref);
  GDString.initBindingsConstructorDestructor();
  StringName.initBindingsConstructorDestructor();
}