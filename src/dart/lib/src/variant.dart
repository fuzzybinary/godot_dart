import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'gdextension.dart';
import 'gen/string.dart';
import 'gen/string_name.dart';

// TODO: This has to come from the generator
const int variantSize = 24;

class Variant {
  final Pointer<Uint8> opaque = malloc<Uint8>(variantSize);

  static void registerVariantTypes() {
    final gde = GodotDartExtensionInterface.instance!;

    StringName.initBindingsConstructorDestructor(gde);
    GDString.initBindingsConstructorDestructor(gde);
  }
}
