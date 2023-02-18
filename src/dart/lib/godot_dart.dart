/// Library for supporting Dart in the Godot Game Engine
library godot_dart;

import 'dart:ffi';

import 'godot_dart.dart';

export 'src/gdextension.dart';
export 'src/gdextension_bindings.dart';
export 'src/gen/string.dart';
export 'src/gen/string_name.dart';

// ignore: unused_element
late GodotDart _globalExtension;

// ignore: unused_element
void _registerGodot(int gdeAddress) {
  final extensionInterface =
      Pointer<GDExtensionInterface>.fromAddress(gdeAddress);

  // TODO: Assert everything is how we expect..
  _globalExtension = GodotDart(extensionInterface);

  GDString.initBindingsConstructorDestructor();
  StringName.initBindingsConstructorDestructor();
}
