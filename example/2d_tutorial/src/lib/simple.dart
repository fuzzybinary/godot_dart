import 'dart:math';

import 'package:godot_dart/godot_dart.dart';

class Simple extends Sprite2D {
  static TypeInfo sTypeInfo = TypeInfo(
    Simple,
    StringName.fromString('Simple'),
    parentClass: StringName.fromString('Sprite2D'),
    vTable: Sprite2D.sTypeInfo.vTable,
  );

  @override
  TypeInfo get typeInfo => sTypeInfo;

  double _timePassed = 0.0;
  double amplitude = 10.0;
  double speed = 1.0;

  Simple() : super();

  @override
  void vProcess(double delta) {
    _timePassed += speed * delta;

    final x = amplitude + (amplitude * sin(_timePassed * 2.0));
    final y = amplitude + (amplitude * cos(_timePassed * 2.0));
    final newPosition = Vector2.fromXY(x, y);
    setPosition(newPosition);
  }

  static void bind() {
    gde.dartBindings.bindClass(Simple);
    gde.dartBindings.addProperty(Simple.sTypeInfo,
        PropertyInfo(typeInfo: TypeInfo.forType(double)!, name: 'amplitude'));
    gde.dartBindings.addProperty(
      Simple.sTypeInfo,
      PropertyInfo(
        typeInfo: TypeInfo.forType(double)!,
        name: 'speed',
        hint: PropertyHint.propertyHintRange,
        hintString: '0,20,0.01',
      ),
    );
  }
}