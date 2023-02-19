import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:godot_dart/src/godot_dart_native_bindings.dart';
import 'package:path/path.dart' as path;

import 'gdextension_bindings.dart';
import 'gen/string_name.dart';

GodotDart get gde => GodotDart.instance!;

/// This is a wrapper around the [GDExtensionInterface] generated FFI
/// code to make calling the extension easier.
class GodotDart {
  static GodotDart? instance;

  final Pointer<GDExtensionInterface> interface;
  final GDExtensionClassLibraryPtr libraryPtr;

  late GodotDartNativeBindings dartBindings;

  GodotDart(this.interface, this.libraryPtr) {
    instance = this;

    var libraryPath = path.join(Directory.current.path, 'libgodot_dart.so');
    if (Platform.isMacOS) {
      libraryPath = path.join(Directory.current.path, 'libgodot_dart.dylib');
    } else if (Platform.isWindows) {
      libraryPath = path.join(Directory.current.path, 'godot_dart.dll');
    }
    dartBindings = GodotDartNativeBindings(DynamicLibrary.open(libraryPath));
  }

  // Object?
  void setInstance(
      GDExtensionObjectPtr owner, StringName name, Object instance) {
    dartBindings.setInstance(owner, name, instance);
  }

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

  // Class Db
  void registerExtensionClass(
    StringName className,
    StringName parentClassName,
    Pointer<GDExtensionClassCreationInfo> classInfo,
  ) {
    void Function(
            GDExtensionClassLibraryPtr,
            GDExtensionConstStringNamePtr,
            GDExtensionConstStringNamePtr,
            Pointer<GDExtensionClassCreationInfo>) f =
        interface.ref.classdb_register_extension_class.asFunction();
    f(
      libraryPtr,
      className.opaque.cast(),
      parentClassName.opaque.cast(),
      classInfo,
    );
  }

  GDExtensionObjectPtr constructObject(StringName className) {
    print("Construct object");
    final func = interface.ref.classdb_construct_object.asFunction<
        GDExtensionObjectPtr Function(GDExtensionConstStringNamePtr)>();
    return func(className.opaque.cast());
  }
}
