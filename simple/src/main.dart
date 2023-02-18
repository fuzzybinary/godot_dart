import 'dart:ffi';

import 'package:godot_dart/godot_dart.dart';

void godot_main() {
  // Simple.className = StringName.fromString(GDString.fromString('Simple'));

  // var classInfo = calloc<GDExtensionClassCreationInfo>();
  // classInfo.ref.create_instance_func = x;
  // classInfo.ref.free_instance_func = y;

  // gdInterface.classdb_register_extension_class.asFunction<
  //     void Function(
  //         GDExtensionClassLibraryPtr,
  //         GDExtensionConstStringNamePtr,
  //         GDExtensionConstStringNamePtr,
  //         Pointer<GDExtensionClassCreationInfo>)>()(
  //   libraryPtr,
  //   Simple.className.opaque.cast(),
  //   StringName.fromString(GDString.fromString('Reference')).opaque.cast(),
  //   classInfo,
  // );
}

GDExtensionObjectPtr createSimple(Pointer<Void> data) {
  return Simple().owner;
}

class Simple {
  static late StringName className;
  late GDExtensionObjectPtr owner;

  Simple() {
    final gde = GodotDart.instance!.interface;
    owner = gde.ref.classdb_construct_object.asFunction<
        GDExtensionObjectPtr Function(
            GDExtensionConstStringNamePtr)>()(Simple.className.opaque.cast());
  }
}

void main() {
  Simple.className = StringName.fromString(GDString.fromString('Simple'));
}
