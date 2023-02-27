import 'dart:ffi';
import 'dart:nativewrappers';

import 'package:ffi/ffi.dart';
import 'package:godot_dart/godot_dart.dart';

class Simple {
  static late StringName className;
  late GDExtensionObjectPtr owner;

  Simple() {
    owner = gde.constructObject(StringName.fromString('Object'));
  }

  Simple.fromOwner(this.owner);

  Variant myMethod() {
    return convertToVariant('Hello from Dart!');
  }
}

GDExtensionObjectPtr createSimple(Pointer<Void> data) {
  final simple = Simple();
  gde.setInstance(simple.owner, Simple.className, simple);

  return simple.owner;
}

void destroySimple(Pointer<Void> data, GDExtensionObjectPtr ptr) {}

void main() {
  Simple.className = StringName.fromString('Simple');

  final classInfo = calloc<GDExtensionClassCreationInfo>();
  classInfo.ref
    ..create_instance_func = Pointer.fromFunction(createSimple)
    ..free_instance_func = Pointer.fromFunction(destroySimple);

  gde.registerExtensionClass(
    Simple.className,
    StringName.fromString('Object'),
    classInfo,
  );

  calloc.free(classInfo);

  gde.dartBindings.bindMethod("Simple", "myMethod", String, []);
}
