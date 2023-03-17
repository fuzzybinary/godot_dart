/// Library for supporting Dart in the Godot Game Engine
library godot_dart;

import 'dart:ffi';

import 'godot_dart.dart';
import 'src/core/gdextension_ffi_bindings.dart';

export 'src/core/core_types.dart';
export 'src/core/gdextension.dart';
export 'src/core/type_info.dart';
export 'src/gen/classes/engine_classes.dart';
export 'src/gen/variant/builtins.dart';
export 'src/variant/variant.dart';

// ignore: unused_element
late GodotDart _globalExtension;

@pragma('vm:entry-point')
void _registerGodot(int gdeAddress, int libraryAddress) {
  final extensionInterface =
      Pointer<GDExtensionInterface>.fromAddress(gdeAddress);
  final libraryPtr = GDExtensionClassLibraryPtr.fromAddress(libraryAddress);

  // TODO: Assert everything is how we expect..
  _globalExtension = GodotDart(extensionInterface, libraryPtr);

  initVariantBindings(extensionInterface.ref);
  TypeInfo.initTypeMappings();
}
