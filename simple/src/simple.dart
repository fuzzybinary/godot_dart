import 'package:godot_dart/godot_dart.dart';

class Simple extends Control {
  static late TypeInfo typeInfo;
  static void initTypeInfo() => typeInfo = TypeInfo(
        StringName.fromString('Simple'),
        parentClass: StringName.fromString('Control'),
      );

  @override
  TypeInfo get staticTypeInfo => typeInfo;

  final double _doubleValue = 12.0;

  Simple();

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
    print(
        'Our owners are: ${simple.nativePtr.address} - ${simple.nativePtr.address}');
    return simple == this;
  }

  Viewport? doSomething() {
    if (isInsideTree()) {
      final viewport = getViewport();
      print(
          'Physics Process Delta Time? ${viewport?.getPhysicsProcessDeltaTime()}');
      return viewport;
    }

    return null;
  }
}
