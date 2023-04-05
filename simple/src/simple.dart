import 'dart:ffi';
import 'dart:math';

import 'package:godot_dart/godot_dart.dart';

class Simple extends Sprite2D {
  static late TypeInfo typeInfo;
  static void initTypeInfo() => typeInfo = TypeInfo(
        StringName.fromString('Simple'),
        parentClass: StringName.fromString('Sprite2D'),
      );
  static Map<String, Pointer<GodotVirtualFunction>> get vTable =>
      Sprite2D.vTable;

  @override
  TypeInfo get staticTypeInfo => typeInfo;

  double _timePassed = 0.0;

  Simple() : super() {
    postInitialize();
  }

  @override
  void vProcess(double delta) {
    _timePassed += delta;

    final x = 10.0 + (10.0 * sin(_timePassed * 2.0));
    final y = 10.0 + (10.0 * cos(_timePassed * 2.0));
    final newPosition = Vector2.fromXY(x, y);
    print('vProcess - $x, $y, ${newPosition.x}, ${newPosition.y}');
    setPosition(newPosition);
  }
}
