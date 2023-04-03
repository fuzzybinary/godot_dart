import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../../godot_dart.dart';
import 'gdextension_ffi_bindings.dart';
import 'godot_dart_native_bindings.dart';

GodotDart get gde => GodotDart.instance!;

typedef GodotVirtualFunction = NativeFunction<
    Void Function(GDExtensionClassInstancePtr, Pointer<GDExtensionConstTypePtr>,
        GDExtensionTypePtr)>;

/// This is a wrapper around the [GDExtensionInterface] generated FFI
/// code to make calling the extension easier.
class GodotDart {
  static GodotDart? instance;

  final Pointer<GDExtensionInterface> interface;
  final GDExtensionClassLibraryPtr libraryPtr;

  late GodotDartNativeBindings dartBindings;

  GodotDart(this.interface, this.libraryPtr) {
    instance = this;

    dartBindings = GodotDartNativeBindings();
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

  GDExtensionPtrGetter variantGetPtrGetter(int variantType, StringName name) {
    return interface.ref.variant_get_ptr_getter.asFunction<
            GDExtensionPtrGetter Function(int, GDExtensionConstStringNamePtr)>(
        isLeaf: true)(variantType, name.nativePtr.cast());
  }

  GDExtensionPtrGetter variantGetPtrSetter(int variantType, StringName name) {
    return interface.ref.variant_get_ptr_setter.asFunction<
            GDExtensionPtrGetter Function(int, GDExtensionConstStringNamePtr)>(
        isLeaf: true)(variantType, name.nativePtr.cast());
  }

  GDExtensionObjectPtr globalGetSingleton(StringName name) {
    return interface.ref.global_get_singleton.asFunction<
            GDExtensionObjectPtr Function(GDExtensionConstStringNamePtr)>(
        isLeaf: true)(name.nativePtr.cast());
  }

  GDExtensionMethodBindPtr classDbGetMethodBind(
      StringName className, StringName methodName, int hash) {
    return interface.ref.classdb_get_method_bind.asFunction<
            GDExtensionMethodBindPtr Function(GDExtensionConstStringNamePtr,
                GDExtensionConstStringNamePtr, int)>(isLeaf: true)(
        className.nativePtr.cast(), methodName.nativePtr.cast(), hash);
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

      callFunc(function, instance?.nativePtr ?? nullptr, argArray, ret);
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
        argArray.elementAt(i).value = args[i].nativePtr.cast();
      }
      callFunc(function, instance?.nativePtr.cast() ?? nullptr.cast(), argArray,
          args.length, ret.nativePtr.cast(), errorPtr.cast());
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
            int)>()(variantType, name.nativePtr.cast(), hash);
  }

  GDExtensionObjectPtr constructObject(StringName className) {
    final func = interface.ref.classdb_construct_object.asFunction<
        GDExtensionObjectPtr Function(GDExtensionConstStringNamePtr)>();
    return func(className.nativePtr.cast());
  }
}
