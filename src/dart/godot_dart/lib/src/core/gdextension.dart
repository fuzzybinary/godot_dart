import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../gen/builtins.dart';
import '../gen/engine_classes.dart';
import '../variant/variant.dart';
import 'core_types.dart';
import 'gdextension_ffi_bindings.dart';
import 'godot_dart_native_bridge.dart';
import 'type_resolver.dart';

GodotDart get gde => GodotDart.instance!;

typedef GodotVirtualFunction = NativeFunction<
    Void Function(GDExtensionClassInstancePtr, Pointer<GDExtensionConstTypePtr>,
        GDExtensionTypePtr)>;

/// This is a wrapper around the [GDExtensionInterface] generated FFI
/// code to make calling the extension easier.
class GodotDart {
  static final int destructorSize = sizeOf<GDExtensionPtrDestructor>();

  static GodotDart? instance;

  final GDExtensionFFI ffiBindings;
  final GDExtensionClassLibraryPtr extensionToken;

  final TypeResolver typeResolver = TypeResolver();

  GodotDart(this.ffiBindings, this.extensionToken) {
    instance = this;

    GDNativeInterface.setTypeResolver(typeResolver);
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

  void callBuiltinDestructor(
      GDExtensionPtrDestructor destructor, GDExtensionTypePtr base) {
    void Function(GDExtensionTypePtr) d = destructor.asFunction();
    d(base);
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
    malloc.free(array);
  }

  Variant callNativeMethodBind(
    GDExtensionMethodBindPtr function,
    ExtensionType? instance,
    List<Variant> args,
  ) {
    Variant ret = Variant();
    using((arena) {
      final errorPtr =
          arena.allocate<GDExtensionCallError>(sizeOf<GDExtensionCallError>());
      final argArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstVariantPtr>() * args.length);
      for (int i = 0; i < args.length; ++i) {
        (argArray + i).value = args[i].nativePtr.cast();
      }
      ffiBindings.gde_object_method_bind_call(
        function,
        instance?.nativePtr.cast() ?? nullptr.cast(),
        argArray,
        args.length,
        ret.nativePtr.cast(),
        errorPtr.cast(),
      );
      if (errorPtr.ref.error != GDExtensionCallErrorType.GDEXTENSION_CALL_OK) {
        throw Exception(
            'Error calling function in Godot: Error ${errorPtr.ref.error}, Argument ${errorPtr.ref.argument}, Expected ${errorPtr.ref.expected}');
      }
    });

    return ret;
  }

  Variant variantCall(Variant self, String methodName, List<Variant> args) {
    Variant ret = Variant();
    final gdMethodName = StringName.fromString(methodName);
    using((arena) {
      final errorPtr =
          arena.allocate<GDExtensionCallError>(sizeOf<GDExtensionCallError>());
      final argArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstVariantPtr>() * args.length);
      for (int i = 0; i < args.length; ++i) {
        (argArray + i).value = args[i].nativePtr.cast();
      }
      ffiBindings.gde_variant_call(
        self.nativePtr.cast(),
        gdMethodName.nativePtr.cast(),
        argArray,
        args.length,
        ret.nativePtr.cast(),
        errorPtr.cast(),
      );
      if (errorPtr.ref.error != GDExtensionCallErrorType.GDEXTENSION_CALL_OK) {
        throw Exception(
            'Error calling function in Godot: Error ${errorPtr.ref.error}, Argument ${errorPtr.ref.argument}, Expected ${errorPtr.ref.expected}');
      }
    });

    return ret;
  }

  Variant variantGetIndexed(Variant self, int index) {
    Variant ret = Variant();
    using((arena) {
      final valid = arena.allocate<Uint8>(sizeOf<Uint8>());
      final oob = arena.allocate<Uint8>(sizeOf<Uint8>());
      ffiBindings.gde_variant_get_indexed(
        self.nativePtr.cast(),
        index,
        ret.nativePtr.cast(),
        valid,
        oob,
      );
      if (oob.value != 0) {
        throw RangeError.index(index, self);
      }
    });

    return ret;
  }

  void variantSetIndexed(Variant self, int index, Variant value) {
    using((arena) {
      final valid = arena.allocate<Uint8>(sizeOf<Uint8>());
      final oob = arena.allocate<Uint8>(sizeOf<Uint8>());
      ffiBindings.gde_variant_set_indexed(
        self.nativePtr.cast(),
        index,
        value.nativePtr.cast(),
        valid,
        oob,
      );
      if (oob.value != 0) {
        throw RangeError.index(index, self);
      }
    });
  }

  GDExtensionPtrBuiltInMethod variantGetBuiltinMethod(
    int variantType,
    StringName name,
    int hash,
  ) {
    return ffiBindings.gde_variant_get_ptr_builtin_method(
        variantType, name.nativePtr.cast(), hash);
  }

  // One line simple remappings
  GDExtensionPtrConstructor variantGetConstructor(int variantType, int index) =>
      ffiBindings.gde_variant_get_ptr_constructor(variantType, index);
  GDExtensionPtrDestructor variantGetDestructor(int variantType) =>
      ffiBindings.gde_variant_get_ptr_destructor(variantType);
  GDExtensionPtrGetter variantGetPtrGetter(int variantType, StringName name) =>
      ffiBindings.gde_variant_get_ptr_getter(
          variantType, name.nativePtr.cast());
  GDExtensionPtrGetter variantGetPtrSetter(int variantType, StringName name) =>
      ffiBindings.gde_variant_get_ptr_setter(
          variantType, name.nativePtr.cast());
  GDExtensionObjectPtr globalGetSingleton(StringName name) =>
      ffiBindings.gde_global_get_singleton(name.nativePtr.cast());
  GDExtensionMethodBindPtr classDbGetMethodBind(
          StringName className, StringName methodName, int hash) =>
      ffiBindings.gde_classdb_get_method_bind(
          className.nativePtr.cast(), methodName.nativePtr.cast(), hash);
  GDExtensionPtrIndexedSetter variantGetIndexedSetter(int variantType) =>
      ffiBindings.gde_variant_get_ptr_indexed_setter(variantType);
  GDExtensionPtrIndexedGetter variantGetIndexedGetter(int variantType) =>
      ffiBindings.gde_variant_get_ptr_indexed_getter(variantType);
  GDExtensionPtrKeyedSetter variantGetKeyedSetter(int variantType) =>
      ffiBindings.gde_variant_get_ptr_keyed_setter(variantType);
  GDExtensionPtrKeyedGetter variantGetKeyedGetter(int variantType) =>
      ffiBindings.gde_variant_get_ptr_keyed_getter(variantType);
  GDExtensionPtrKeyedChecker variantGetKeyedChecker(int variantType) =>
      ffiBindings.gde_variant_get_ptr_keyed_checker(variantType);
  GDExtensionObjectPtr constructObject(StringName className) =>
      ffiBindings.gde_classdb_construct_object(className.nativePtr.cast());
  Pointer<Void> getClassTag(StringName className) =>
      ffiBindings.gde_classdb_get_class_tag(className.nativePtr.cast());
}

extension GodotObjectCast on GodotObject {
  // Implementation of as? or dynamic_cast
  T? as<T>() {
    return this is T ? this as T : null;
  }
}
