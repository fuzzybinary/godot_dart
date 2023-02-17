/// Library for supporting Dart in the Godot Game Engine
library godot_dart;

import 'dart:ffi';

import 'godot_dart.dart';

export 'src/gdextension.dart';
export 'src/gdextension_bindings.dart';
export 'src/gen/string.dart';
export 'src/gen/string_name.dart';

late GodotDartExtensionInterface _globalExtension;

void _register_godot(int gdeAddress) {
  final gde = Pointer<GDExtensionInterface>.fromAddress(gdeAddress);

  // TODO: Assert everything is how we expect..
  _globalExtension = GodotDartExtensionInterface(gde);
  GDString.initBindingsConstructorDestructor(_globalExtension);
  StringName.initBindingsConstructorDestructor(_globalExtension);
}
