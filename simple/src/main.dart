import 'package:godot_dart/godot_dart.dart';

class Simple extends ExtensionType {
  static late TypeInfo typeInfo;
  static void initTypeInfo() => typeInfo = TypeInfo(
        StringName.fromString('Simple'),
        parentClass: StringName.fromString('Object'),
      );

  final double _doubleValue = 12.0;

  Simple() {
    owner = gde.constructObject(StringName.fromString('Object'));
  }

  String myMethod() {
    return 'Hello from Dart!';
  }

  double paramMethod(Vector3 vector) {
    double length = vector.length();
    print('Got a vector of length $length}');

    return length;
  }

  bool isSame(Simple simple) {
    print("Got a simple back... it's value is ${simple._doubleValue}");
    print('Our owners are: ${simple.owner.address} - ${simple.owner.address}');
    return simple == this;
  }
}

void main() {
  Simple.initTypeInfo();

  gde.dartBindings.bindClass(Simple, Simple.typeInfo);
  gde.dartBindings
      .bindMethod(Simple.typeInfo, 'myMethod', TypeInfo.forType(String)!, []);
  gde.dartBindings.bindMethod(Simple.typeInfo, 'paramMethod',
      TypeInfo.forType(double)!, [Vector3.typeInfo]);
  gde.dartBindings.bindMethod(
      Simple.typeInfo, 'isSame', TypeInfo.forType(bool)!, [Simple.typeInfo]);
}
