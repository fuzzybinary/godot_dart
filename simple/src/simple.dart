import 'dart:ffi';
import 'dart:math';

import 'package:godot_dart/godot_dart.dart';

class Simple extends Sprite2D {
  static TypeInfo sTypeInfo = TypeInfo(
	Simple,
	StringName.fromString('Simple'),
	parentClass: StringName.fromString('Sprite2D'),
  );
  static Map<String, Pointer<GodotVirtualFunction>> get vTable =>
	  Sprite2D.vTable;

  @override
  TypeInfo get typeInfo => sTypeInfo;

  double _timePassed = 0.0;
  double amplitude = 10.0;
  double speed = 1.0;

  Simple() : super() {
	postInitialize();
  }

  @override
  void vProcess(double delta) {
	_timePassed += speed * delta;

	final x = amplitude + (amplitude * sin(_timePassed * 2.0));
	final y = amplitude + (amplitude * cos(_timePassed * 2.0));
	final newPosition = Vector2.fromXY(x, y);
	setPosition(newPosition);
  }

  static void bind() {
	gde.dartBindings.bindClass(Simple, Simple.sTypeInfo);
	gde.dartBindings.addProperty(Simple.sTypeInfo, 'amplitude',
		PropertyInfo(type: VariantType.typeFloat, name: 'amplitude'));
	gde.dartBindings.addProperty(
	  Simple.sTypeInfo,
	  'speed',
	  PropertyInfo(
		type: VariantType.typeFloat,
		name: 'speed',
		hint: PropertyHint.propertyHintRange,
		hintString: '0,20,0.01',
	  ),
	);
  }
}
