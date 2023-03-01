import 'package:godot_dart/godot_dart.dart';

class Simple extends Wrapped {
  static late StringName className;

  Simple() {
    owner = gde.constructObject(StringName.fromString('Object'));
  }

  Variant myMethod() {
    return convertToVariant('Hello from Dart!');
  }
}

void main() {
  Simple.className = StringName.fromString('Simple');
  final objectName = StringName.fromString('Object');

  gde.dartBindings.bindClass(Simple, Simple.className, objectName);
  gde.dartBindings.bindMethod('Simple', 'myMethod', String, []);
}
