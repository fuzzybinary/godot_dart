import 'dart:ffi';
import 'dart:math';

import 'package:godot_dart/godot_dart.dart';

class Player extends Area2D {
  // This is necessary boilerplate at the moment
  static TypeInfo sTypeInfo = TypeInfo(
    Player,
    StringName.fromString('Player'),
    parentClass: Area2D.sTypeInfo.className,
  );
  static Map<String, Pointer<GodotVirtualFunction>> get vTable => Area2D.vTable;
  static final Map<String, MethodInfo> _methodTable = {
    '_ready': MethodInfo(
      methodName: '_ready',
      dartMethodName: 'vReady',
      arguments: [],
    ),
    '_process': MethodInfo(
      methodName: '_process',
      dartMethodName: 'vProcess',
      arguments: [],
    ),
  };

  @override
  TypeInfo get typeInfo => sTypeInfo;

  double _timePassed = 0;

  Player() : super() {
    postInitialize();
  }
  Player.withNonNullOwner(Pointer<Void> owner) : super.withNonNullOwner(owner) {
    postInitialize();
  }

  @override
  void vReady() {}

  @override
  void vProcess(double delta) {
    _timePassed += delta;

    var x = 10.0 + (10.0 * sin(_timePassed * 2.0));
    var y = 10.0 + (10.0 * cos(_timePassed * 2.0));
    var newPosition = Vector2.fromXY(x, y);

    setPosition(newPosition);
  }

  @override
  MethodInfo? getMethodInfo(String methodName) {
    return _methodTable[methodName];
  }

  static void bind() {
    gde.dartBindings.bindClass(Player, Player.sTypeInfo);
  }
}
