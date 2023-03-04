import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../../godot_dart.dart';
import '../core/gdextension_ffi_bindings.dart';

typedef GDExtensionVariantFromType = void Function(
    GDExtensionVariantPtr, GDExtensionTypePtr);

late List<GDExtensionVariantFromType?> _fromTypeConstructor;
late List<GDExtensionTypeFromVariantConstructorFunc?> _toTypeConstructor;

Map<Type, GDExtensionVariantFromTypeConstructorFunc> _dartTypeToVariant = {};

void initVariantBindings(GDExtensionInterface gdeInterface) {
  _fromTypeConstructor = List.generate(
    GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_VARIANT_MAX,
    (variantType) {
      if (variantType == 0) {
        return null;
      }
      GDExtensionVariantFromTypeConstructorFunc Function(int) f;
      f = gdeInterface.get_variant_from_type_constructor
          .asFunction(isLeaf: true);
      return f(variantType).asFunction(isLeaf: true);
    },
  );
  _toTypeConstructor = List.generate(
    GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_VARIANT_MAX,
    (variantType) {
      if (variantType == 0) {
        return null;
      }
      GDExtensionTypeFromVariantConstructorFunc Function(int) f;
      f = gdeInterface.get_variant_to_type_constructor.asFunction(isLeaf: true);
      return f(variantType);
    },
  );

  // String and String name need their constructors bound before anything else
  // because everything else relies onthem being done.
  GDString.initBindingsConstructorDestructor();
  StringName.initBindingsConstructorDestructor();
  GDString.initBindings();
  StringName.initBindings();

  // Generate this?
  Vector2.initBindings();
  Vector2i.initBindings();
  Vector3.initBindings();
  Vector3i.initBindings();
  Vector4.initBindings();
  Vector4i.initBindings();
  Quaternion.initBindings();
  Rect2.initBindings();
  Rect2i.initBindings();
  Transform2D.initBindings();
  Plane.initBindings();
  AABB.initBindings();
  Basis.initBindings();
  Transform3D.initBindings();
  Projection.initBindings();
  Color.initBindings();
  NodePath.initBindings();
  RID.initBindings();
  Callable.initBindings();
  Signal.initBindings();
  Dictionary.initBindings();
  Array.initBindings();
  PackedByteArray.initBindings();
  PackedInt32Array.initBindings();
  PackedInt64Array.initBindings();
  PackedFloat32Array.initBindings();
  PackedFloat64Array.initBindings();
  PackedStringArray.initBindings();
  PackedVector2Array.initBindings();
  PackedVector3Array.initBindings();
  PackedColorArray.initBindings();
}

class Variant {
  static final Finalizer<Pointer<Uint8>> _finalizer =
      Finalizer((mem) => calloc.free(mem));

  // TODO: This is supposed to come from the generator, but we
  // may just need to take the max size
  static const int _size = 24;

  final _opaque = calloc<Uint8>(_size);
  Pointer<Uint8> get opaque => _opaque;

  Variant() {
    _finalizer.attach(this, _opaque);
  }
}

Variant convertToVariant(Object? obj) {
  final ret = Variant();
  final objectType = obj?.runtimeType;
  void Function(GDExtensionVariantPtr, GDExtensionTypePtr)? c;

  // First easy checks, are we null?
  if (obj == null) {
    GodotDart.instance!.interface.ref.variant_new_nil
        .asFunction<void Function(GDExtensionVariantPtr)>(
            isLeaf: true)(ret.opaque.cast());
  } else if (obj is Wrapped) {
    // Are we an Object already? (For now we check Wrapped)
    c = _fromTypeConstructor[
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_OBJECT];
    c?.call(ret.opaque.cast(), obj.owner.cast());
  } else {
    // Convert built in types
    using((arena) {
      switch (objectType) {
        case bool:
          final b = arena.allocate<GDExtensionBool>(sizeOf<GDExtensionBool>());
          b.value = (obj as bool) ? 1 : 0;
          c = _fromTypeConstructor[
              GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_BOOL];
          c?.call(ret.opaque.cast(), b.cast());
          break;
        case int:
          final i = arena.allocate<GDExtensionInt>(sizeOf<GDExtensionInt>());
          i.value = obj as int;
          c = _fromTypeConstructor[
              GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_INT];
          c?.call(ret.opaque.cast(), i.cast());
          break;
        case double:
          final d = arena.allocate<Double>(sizeOf<Double>());
          d.value = obj as double;
          c = _fromTypeConstructor[
              GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_FLOAT];
          c?.call(ret.opaque.cast(), d.cast());
          break;
        case String:
          final gdString = GDString.fromString(obj as String);
          c = _fromTypeConstructor[
              GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_STRING];
          c?.call(ret.opaque.cast(), gdString.opaque.cast());
          break;
        // TODO: All the other variant types (dictionary? List?)
        default:
          // If we got here, return nil variant
          GodotDart.instance!.interface.ref.variant_new_nil
              .asFunction<void Function(GDExtensionVariantPtr)>(
                  isLeaf: true)(ret.opaque.cast());
      }
    });
  }

  return ret;
}
