import 'package:godot_dart/godot_dart.dart';

import 'simple.dart';

void main() {
  Simple.initTypeInfo();

  gde.dartBindings.bindClass(Simple, Simple.typeInfo);
  gde.dartBindings
      .bindMethod(Simple.typeInfo, 'myMethod', TypeInfo.forType(String)!, []);
  gde.dartBindings.bindMethod(Simple.typeInfo, 'paramMethod',
      TypeInfo.forType(double)!, [Vector3.typeInfo]);
  gde.dartBindings.bindMethod(
      Simple.typeInfo, 'isSame', TypeInfo.forType(bool)!, [Simple.typeInfo]);
  gde.dartBindings
      .bindMethod(Simple.typeInfo, 'doSomething', Viewport.typeInfo, []);
}
