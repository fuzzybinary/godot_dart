import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'gdextension_bindings.dart';

GodotDartExtensionInterface get gde => GodotDartExtensionInterface.instance!;

/// This is a wrapper around the [GDExtensionInterface] generated FFI
/// code to make calling the extension easier.
class GodotDartExtensionInterface {
  final Pointer<GDExtensionInterface> interface;

  static GodotDartExtensionInterface? instance;

  GodotDartExtensionInterface(this.interface) {
    instance = this;
  }

  // Godot Core

  // Godot Variant

  // Variant General
  // copy
  // new nil
  // destroy

  // Variant Type

  GDExtensionPtrConstructor variantGetPtrConstructor(
      int variantType, int index) {
    return interface.ref.variant_get_ptr_constructor
            .asFunction<GDExtensionPtrConstructor Function(int, int)>()(
        variantType, index);
  }

  GDExtensionPtrDestructor variantGetPtrDestructor(int variantType) {
    return interface.ref.variant_get_ptr_destructor
        .asFunction<GDExtensionPtrDestructor Function(int)>()(variantType);
  }

  void callBuiltinConstructor(GDExtensionPtrConstructor constructor,
      GDExtensionTypePtr base, List<GDExtensionConstTypePtr> args) {
    final array = malloc<GDExtensionConstTypePtr>(args.length);
    for (int i = 0; i < args.length; ++i) {
      array[i] = args[i];
    }

    constructor.asFunction<
        void Function(GDExtensionTypePtr,
            Pointer<GDExtensionConstTypePtr>)>()(base, array);

    malloc.free(array);
  }

  void registerType(Type type) {
    // For now, use mirrors. In the future, use code generation
  }
}
