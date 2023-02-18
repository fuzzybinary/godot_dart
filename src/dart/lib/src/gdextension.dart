import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'gdextension_bindings.dart';

GodotDart get gde => GodotDart.instance!;

/// This is a wrapper around the [GDExtensionInterface] generated FFI
/// code to make calling the extension easier.
class GodotDart {
  final Pointer<GDExtensionInterface> interface;

  static GodotDart? instance;

  GodotDart(this.interface) {
    instance = this;
  }

  // Godot Core

  // Godot Variant

  // Variant General
  // copy
  // new nil
  // destroy

  // Variant Type

  GDExtensionPtrConstructor variantGetConstructor(
    int variantType,
    int index,
  ) {
    GDExtensionPtrConstructor Function(int, int) func = interface
        .ref.variant_get_ptr_constructor
        .asFunction<GDExtensionPtrConstructor Function(int, int)>();
    return func(variantType, index);
  }

  GDExtensionPtrDestructor variantGetDestructor(int variantType) {
    return interface.ref.variant_get_ptr_destructor
        .asFunction<GDExtensionPtrDestructor Function(int)>()(variantType);
  }

  void callBuiltinConstructor(
    GDExtensionPtrConstructor constructor,
    GDExtensionTypePtr base,
    List<GDExtensionConstTypePtr> args,
  ) {
    final array = malloc<GDExtensionConstTypePtr>(args.length);
    for (int i = 0; i < args.length; ++i) {
      array[i] = args[i];
    }

    void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>) c =
        constructor.asFunction();
    c(base, array);

    malloc.free(array);
  }

  void registerType(Type type) {
    // For now, use mirrors. In the future, use code generation
  }
}
