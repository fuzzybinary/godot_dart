import 'package:godot_dart/godot_dart.dart';

import 'simple.dart';

void main() {
  Simple.initTypeInfo();

  gde.dartBindings.bindClass(Simple, Simple.typeInfo);
}
