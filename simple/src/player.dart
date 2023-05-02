import 'dart:ffi';

import 'package:godot_dart/godot_dart.dart';

class Player extends Area2D {
  // This is necessary boilerplate at the moment
  static TypeInfo typeInfo = TypeInfo(
	StringName.fromString('Player'),
	parentClass: Area2D.typeInfo.className,
  );
  static Map<String, Pointer<GodotVirtualFunction>> get vTable => Area2D.vTable;

  @override
  TypeInfo get staticTypeInfo => typeInfo;

  Player() : super() {
	postInitialize();
  }

  @override
  void vReady() {

  }

  @override
  void vProcess(double delta) {

  }
}
