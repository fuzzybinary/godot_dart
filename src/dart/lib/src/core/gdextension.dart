import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

import '../../godot_dart.dart';
import 'gdextension_ffi_bindings.dart';
import 'godot_dart_native_bindings.dart';

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
    dartBindings = GodotDartNativeBindings(libraryPath);
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

  GDExtensionObjectPtr globalGetSingleton(StringName name) {
    return interface.ref.global_get_singleton.asFunction<
        GDExtensionObjectPtr Function(
            GDExtensionConstStringNamePtr)>(isLeaf: true)(name.opaque.cast());
  }

  GDExtensionMethodBindPtr classDbGetMethodBind(
      StringName className, StringName methodName, int hash) {
    return interface.ref.classdb_get_method_bind.asFunction<
            GDExtensionMethodBindPtr Function(GDExtensionConstStringNamePtr,
                GDExtensionConstStringNamePtr, int)>(isLeaf: true)(
        className.opaque.cast(), methodName.opaque.cast(), hash);
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

  void callBuiltinMethodPtr(
    GDExtensionPtrBuiltInMethod? method,
    GDExtensionTypePtr base,
    GDExtensionTypePtr ret,
    List<GDExtensionConstTypePtr> args,
  ) {
    if (method == null) return;

    final array = malloc<GDExtensionConstTypePtr>(args.length);
    for (int i = 0; i < args.length; ++i) {
      array[i] = args[i];
    }
    void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
        GDExtensionTypePtr, int) m = method.asFunction();
    m(base, array, ret, args.length);
  }

  void callNativeMethodBindPtrCall(
    GDExtensionMethodBindPtr function,
    ExtensionType? instance,
    Pointer<Void> ret,
    List<GDExtensionConstTypePtr> args,
  ) {
    final callFunc = interface.ref.object_method_bind_ptrcall.asFunction<
        void Function(GDExtensionMethodBindPtr, GDExtensionObjectPtr,
            Pointer<GDExtensionConstTypePtr>, GDExtensionTypePtr)>();

    using((arena) {
      final argArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * args.length);
      for (int i = 0; i < args.length; ++i) {
        argArray.elementAt(i).value = args[i];
      }

      callFunc(function, instance?.owner ?? nullptr, argArray, ret);
    });
  }

  Variant callNativeMethodBind(
    GDExtensionMethodBindPtr function,
    ExtensionType? instance,
    List<Variant> args,
  ) {
    final callFunc = interface.ref.object_method_bind_call.asFunction<
        void Function(
            GDExtensionMethodBindPtr,
            GDExtensionObjectPtr,
            Pointer<GDExtensionConstVariantPtr>,
            int,
            GDExtensionVariantPtr,
            Pointer<GDExtensionCallError>)>();
    final ret = Variant();
    using((arena) {
      final errorPtr =
          arena.allocate<GDExtensionCallError>(sizeOf<GDExtensionCallError>());
      final argArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstVariantPtr>() * args.length);
      for (int i = 0; i < args.length; ++i) {
        argArray.elementAt(i).value = args[i].opaque.cast();
      }
      callFunc(function, instance?.owner.cast() ?? nullptr.cast(), argArray,
          args.length, ret.opaque.cast(), errorPtr.cast());
      if (errorPtr.ref.error != GDExtensionCallErrorType.GDEXTENSION_CALL_OK) {
        throw Exception(
            'Error calling function in Godot: Error ${errorPtr.ref.error}, Argument ${errorPtr.ref.argument}, Expected ${errorPtr.ref.expected}');
      }
    });

    return ret;
  }

  GDExtensionPtrBuiltInMethod variantGetBuiltinMethod(
    int variantType,
    StringName name,
    int hash,
  ) {
    return interface.ref.variant_get_ptr_builtin_method.asFunction<
        GDExtensionPtrBuiltInMethod Function(int, GDExtensionConstStringNamePtr,
            int)>()(variantType, name.opaque.cast(), hash);
  }

  GDExtensionObjectPtr constructObject(StringName className) {
    final func = interface.ref.classdb_construct_object.asFunction<
        GDExtensionObjectPtr Function(GDExtensionConstStringNamePtr)>();
    return func(className.opaque.cast());
  }
}
