import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../../godot_dart.dart';
import '../core/gdextension_ffi_bindings.dart';

export 'vector3.dart';

typedef GDExtensionVariantFromType = void Function(
    GDExtensionVariantPtr, GDExtensionTypePtr);
typedef GDExtensionTypeFromVariant = void Function(
    GDExtensionVariantPtr, GDExtensionTypePtr);

late List<GDExtensionVariantFromType?> _fromTypeConstructor;
late List<GDExtensionTypeFromVariant?> _toTypeConstructor;

typedef BuiltinConstructor = BuiltinType Function();
Map<int, BuiltinConstructor> _dartBuiltinConstructors = {};

void initVariantBindings(GDExtensionFFI ffIinterface) {
  _fromTypeConstructor = List.generate(
    GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_VARIANT_MAX,
    (variantType) {
      if (variantType == 0) {
        return null;
      }
      return ffIinterface
          .gde_get_variant_from_type_constructor(variantType)
          .asFunction();
    },
  );
  _toTypeConstructor = List.generate(
    GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_VARIANT_MAX,
    (variantType) {
      if (variantType == 0) {
        return null;
      }
      return ffIinterface
          .gde_get_variant_to_type_constructor(variantType)
          .asFunction();
    },
  );

  // String and String name need their constructors bound before anything else
  // because everything else relies on them being done.
  GDString.initBindingsConstructorDestructor();
  StringName.initBindingsConstructorDestructor();
  GDString.initBindings();

  StringName.initBindings();
  _dartBuiltinConstructors[StringName.sTypeInfo.variantType] = StringName.new;

  // Generate this?
  Vector2.initBindings();
  _dartBuiltinConstructors[Vector2.sTypeInfo.variantType] = Vector2.new;
  Vector2i.initBindings();
  _dartBuiltinConstructors[Vector2i.sTypeInfo.variantType] = Vector2i.new;
  Vector3i.initBindings();
  _dartBuiltinConstructors[Vector3i.sTypeInfo.variantType] = Vector3i.new;
  Vector4.initBindings();
  _dartBuiltinConstructors[Vector4.sTypeInfo.variantType] = Vector4.new;
  Vector4i.initBindings();
  _dartBuiltinConstructors[Vector4i.sTypeInfo.variantType] = Vector4i.new;
  Quaternion.initBindings();
  _dartBuiltinConstructors[Quaternion.sTypeInfo.variantType] = Quaternion.new;
  Rect2.initBindings();
  _dartBuiltinConstructors[Rect2.sTypeInfo.variantType] = Rect2.new;
  Rect2i.initBindings();
  _dartBuiltinConstructors[Rect2i.sTypeInfo.variantType] = Rect2i.new;
  Transform2D.initBindings();
  _dartBuiltinConstructors[Transform2D.sTypeInfo.variantType] = Transform2D.new;
  Plane.initBindings();
  _dartBuiltinConstructors[Plane.sTypeInfo.variantType] = Plane.new;
  AABB.initBindings();
  _dartBuiltinConstructors[AABB.sTypeInfo.variantType] = AABB.new;
  Basis.initBindings();
  _dartBuiltinConstructors[Basis.sTypeInfo.variantType] = Basis.new;
  Transform3D.initBindings();
  _dartBuiltinConstructors[Transform3D.sTypeInfo.variantType] = Transform3D.new;
  Projection.initBindings();
  _dartBuiltinConstructors[Projection.sTypeInfo.variantType] = Projection.new;
  Color.initBindings();
  _dartBuiltinConstructors[Color.sTypeInfo.variantType] = Color.new;
  NodePath.initBindings();
  _dartBuiltinConstructors[NodePath.sTypeInfo.variantType] = NodePath.new;
  RID.initBindings();
  _dartBuiltinConstructors[RID.sTypeInfo.variantType] = RID.new;
  Callable.initBindings();
  _dartBuiltinConstructors[Callable.sTypeInfo.variantType] = Callable.new;
  Signal.initBindings();
  _dartBuiltinConstructors[Signal.sTypeInfo.variantType] = Signal.new;
  Dictionary.initBindings();
  _dartBuiltinConstructors[Dictionary.sTypeInfo.variantType] = Dictionary.new;
  Array.initBindings();
  _dartBuiltinConstructors[Array.sTypeInfo.variantType] = Array.new;
  PackedByteArray.initBindings();
  _dartBuiltinConstructors[PackedByteArray.sTypeInfo.variantType] =
      PackedByteArray.new;
  PackedInt32Array.initBindings();
  _dartBuiltinConstructors[PackedInt32Array.sTypeInfo.variantType] =
      PackedInt32Array.new;
  PackedInt64Array.initBindings();
  _dartBuiltinConstructors[PackedInt64Array.sTypeInfo.variantType] =
      PackedInt64Array.new;
  PackedFloat32Array.initBindings();
  _dartBuiltinConstructors[PackedFloat32Array.sTypeInfo.variantType] =
      PackedFloat32Array.new;
  PackedFloat64Array.initBindings();
  _dartBuiltinConstructors[PackedFloat64Array.sTypeInfo.variantType] =
      PackedFloat64Array.new;
  PackedStringArray.initBindings();
  _dartBuiltinConstructors[PackedStringArray.sTypeInfo.variantType] =
      PackedStringArray.new;
  PackedVector2Array.initBindings();
  _dartBuiltinConstructors[PackedVector2Array.sTypeInfo.variantType] =
      PackedVector2Array.new;
  PackedVector3Array.initBindings();
  _dartBuiltinConstructors[PackedVector3Array.sTypeInfo.variantType] =
      PackedVector3Array.new;
  PackedColorArray.initBindings();
  _dartBuiltinConstructors[PackedColorArray.sTypeInfo.variantType] =
      PackedColorArray.new;
}

@internal
GDExtensionTypeFromVariant? getToTypeConstructor(int type) {
  return _toTypeConstructor[type];
}

// TODO: Variant probably shouldn't extend BuiltinType?
class Variant extends BuiltinType {
  // TODO: This is supposed to come from the generator, but we
  // may just need to take the max size
  static const int _size = 24;
  static final TypeInfo sTypeInfo = TypeInfo(
    Variant,
    StringName.fromString('Variant'),
    variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_VARIANT_MAX,
    size: _size,
  );

  @override
  TypeInfo get typeInfo => sTypeInfo;

  final Pointer<Uint8> _opaque = calloc<Uint8>(_size);
  @override
  Pointer<Uint8> get nativePtr => _opaque;

  Variant() : super();

  Variant.fromPointer(Pointer<void> ptr) {
    gde.dartBindings.variantCopyFromNative(this, ptr.cast());
  }

  int getType() {
    return gde.ffiBindings.gde_variant_get_type(_opaque.cast());
  }
}

Variant convertToVariant(Object? obj) {
  final ret = Variant();
  final objectType = obj?.runtimeType;
  void Function(GDExtensionVariantPtr, GDExtensionTypePtr)? c;

  // First easy checks, are we null?
  if (obj == null) {
    gde.ffiBindings.gde_variant_new_nil(ret.nativePtr.cast());
    // } else if (obj is Ref) {
    //   final referencedObj = obj.obj;
    //   if (referencedObj == null) {
    //     gde.ffiBindings.gde_variant_new_nil(ret.nativePtr.cast());
    //   } else {
    //     // Already an Object, but constructor expects a pointer to the object
    //     Pointer<GDExtensionVariantPtr> ptrToObj = malloc<GDExtensionVariantPtr>();
    //     ptrToObj.value = referencedObj.nativePtr;
    //     c = _fromTypeConstructor[
    //         GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_OBJECT];
    //     c?.call(ret.nativePtr.cast(), ptrToObj.cast());
    //     malloc.free(ptrToObj);
    //   }
  } else if (obj is ExtensionType) {
    // Already an Object, but constructor expects a pointer to the object
    Pointer<GDExtensionVariantPtr> ptrToObj = malloc<GDExtensionVariantPtr>();
    ptrToObj.value = obj.nativePtr;
    c = _fromTypeConstructor[
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_OBJECT];
    c?.call(ret.nativePtr.cast(), ptrToObj.cast());
    malloc.free(ptrToObj);
  } else if (obj is Pointer) {
    // Passed in a pointer, assume we know what we're doing and this is actually a
    // pointer to a Godot object.
    // TODO: Try to find a way to remove this to prevent abuse.
    c = _fromTypeConstructor[
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_OBJECT];
    c?.call(ret.nativePtr.cast(), obj.cast());
  } else if (obj is BuiltinType) {
    // Builtin type
    var typeInfo = obj.typeInfo;
    c = _fromTypeConstructor[typeInfo.variantType];
    c?.call(ret.nativePtr.cast(), obj.nativePtr.cast());
  } else {
    // Convert built in types
    using((arena) {
      switch (objectType) {
        case bool:
          final b = arena.allocate<GDExtensionBool>(sizeOf<GDExtensionBool>());
          b.value = (obj as bool) ? 1 : 0;
          c = _fromTypeConstructor[
              GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_BOOL];
          c?.call(ret.nativePtr.cast(), b.cast());
          break;
        case int:
          final i = arena.allocate<GDExtensionInt>(sizeOf<GDExtensionInt>());
          i.value = obj as int;
          c = _fromTypeConstructor[
              GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_INT];
          c?.call(ret.nativePtr.cast(), i.cast());
          break;
        case double:
          final d = arena.allocate<Double>(sizeOf<Double>());
          d.value = obj as double;
          c = _fromTypeConstructor[
              GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_FLOAT];
          c?.call(ret.nativePtr.cast(), d.cast());
          break;
        case String:
          final gdString = GDString.fromString(obj as String);
          c = _fromTypeConstructor[
              GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_STRING];
          c?.call(ret.nativePtr.cast(), gdString.nativePtr.cast());
          break;
        // TODO: All the other variant types (dictionary? List?)
        default:
          // If we got here, return nil variant
          gde.ffiBindings.gde_variant_new_nil(ret.nativePtr.cast());
      }
    });
  }

  return ret;
}

Object? convertFromVariant(
  Variant variant,
  TypeInfo? typeInfo,
) {
  Object? ret;
  int variantType = variant.getType();
  void Function(GDExtensionTypePtr, GDExtensionVariantPtr)? c;
  if (variantType > 0 && variantType < _toTypeConstructor.length) {
    c = _toTypeConstructor[variantType];
  }

  if (c == null) {
    // TODO: Output an error message
    return null;
  }

  // Do we have a CoreType that we can use to match?
  final builtinConstructor = _dartBuiltinConstructors[variantType];
  if (builtinConstructor != null) {
    var builtin = builtinConstructor();
    c(builtin.nativePtr.cast(), variant.nativePtr.cast());
    return builtin;
  }

  // Else, it's probably a dart native type
  using((arena) {
    switch (variantType) {
      // Built-in types
      case GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_BOOL:
        Pointer<GDExtensionBool> ptr =
            arena.allocate(sizeOf<GDExtensionBool>());
        c!(ptr.cast(), variant.nativePtr.cast());
        ret = ptr.value != 0;
        break;
      case GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_INT:
        Pointer<GDExtensionInt> ptr = arena.allocate(sizeOf<GDExtensionInt>());
        c!(ptr.cast(), variant.nativePtr.cast());
        ret = ptr.value;
        break;
      case GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_FLOAT:
        Pointer<Double> ptr = arena.allocate(sizeOf<Double>());
        c!(ptr.cast(), variant.nativePtr.cast());
        ret = ptr.value;
        break;
      case GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_STRING_NAME:
        var gdStringName = StringName();
        c!(gdStringName.nativePtr.cast(), variant.nativePtr.cast());
        ret = gdStringName.toDartString();
        break;
      case GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_STRING:
        var gdString = GDString();
        c!(gdString.nativePtr.cast(), variant.nativePtr.cast());
        ret = gdString.toDartString();
        break;

      // Or a hand-implemented object
      case GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_VECTOR3:
        ret = Vector3.fromVariant(variant);
        break;

      // Or a wrapped object
      case GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_OBJECT:
        Pointer<GDExtensionObjectPtr> ptr =
            arena.allocate(sizeOf<GDExtensionObjectPtr>());
        c!(ptr.cast(), variant.nativePtr.cast());
        ret = gde.dartBindings.gdObjectToDartObject(
          ptr.value,
          typeInfo?.bindingToken,
        );
        break;

      // TODO: all the other variant types
      default:
        ret = null;
    }
  });
  return ret;
}