import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../../godot_dart.dart';
import '../core/gdextension_ffi_bindings.dart';

export 'vector2.dart';
export 'vector3.dart';

typedef GDExtensionVariantFromType = void Function(
    GDExtensionVariantPtr, GDExtensionTypePtr);
typedef GDExtensionTypeFromVariant = void Function(
    GDExtensionVariantPtr, GDExtensionTypePtr);
typedef VariantConstructor = void Function(
    GDExtensionVariantPtr, GDExtensionTypePtr);

late List<GDExtensionVariantFromType?> _fromTypeConstructor;
late List<GDExtensionTypeFromVariant?> _toTypeConstructor;

typedef BuiltinConstructor = BuiltinType Function(GDExtensionVariantPtr);
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
  _dartBuiltinConstructors[StringName.sTypeInfo.variantType] =
      StringName.fromVariantPtr;

  // Generate this?
  Vector2.initBindings();
  _dartBuiltinConstructors[Vector2.sTypeInfo.variantType] =
      Vector2.fromVariantPtr;
  Vector2i.initBindings();
  _dartBuiltinConstructors[Vector2i.sTypeInfo.variantType] =
      Vector2i.fromVariantPtr;
  Vector3.initBindings();
  Vector3i.initBindings();
  _dartBuiltinConstructors[Vector3i.sTypeInfo.variantType] =
      Vector3i.fromVariantPtr;
  Vector4.initBindings();
  _dartBuiltinConstructors[Vector4.sTypeInfo.variantType] =
      Vector4.fromVariantPtr;
  Vector4i.initBindings();
  _dartBuiltinConstructors[Vector4i.sTypeInfo.variantType] =
      Vector4i.fromVariantPtr;
  Quaternion.initBindings();
  _dartBuiltinConstructors[Quaternion.sTypeInfo.variantType] =
      Quaternion.fromVariantPtr;
  Rect2.initBindings();
  _dartBuiltinConstructors[Rect2.sTypeInfo.variantType] = Rect2.fromVariantPtr;
  Rect2i.initBindings();
  _dartBuiltinConstructors[Rect2i.sTypeInfo.variantType] =
      Rect2i.fromVariantPtr;
  Transform2D.initBindings();
  _dartBuiltinConstructors[Transform2D.sTypeInfo.variantType] =
      Transform2D.fromVariantPtr;
  Plane.initBindings();
  _dartBuiltinConstructors[Plane.sTypeInfo.variantType] = Plane.fromVariantPtr;
  AABB.initBindings();
  _dartBuiltinConstructors[AABB.sTypeInfo.variantType] = AABB.fromVariantPtr;
  Basis.initBindings();
  _dartBuiltinConstructors[Basis.sTypeInfo.variantType] = Basis.fromVariantPtr;
  Transform3D.initBindings();
  _dartBuiltinConstructors[Transform3D.sTypeInfo.variantType] =
      Transform3D.fromVariantPtr;
  Projection.initBindings();
  _dartBuiltinConstructors[Projection.sTypeInfo.variantType] =
      Projection.fromVariantPtr;
  Color.initBindings();
  _dartBuiltinConstructors[Color.sTypeInfo.variantType] = Color.fromVariantPtr;
  NodePath.initBindings();
  _dartBuiltinConstructors[NodePath.sTypeInfo.variantType] =
      NodePath.fromVariantPtr;
  RID.initBindings();
  _dartBuiltinConstructors[RID.sTypeInfo.variantType] = RID.fromVariantPtr;
  Callable.initBindings();
  _dartBuiltinConstructors[Callable.sTypeInfo.variantType] =
      Callable.fromVariantPtr;
  Signal.initBindings();
  _dartBuiltinConstructors[Signal.sTypeInfo.variantType] =
      Signal.fromVariantPtr;
  Dictionary.initBindings();
  _dartBuiltinConstructors[Dictionary.sTypeInfo.variantType] =
      Dictionary.fromVariantPtr;
  Array.initBindings();
  _dartBuiltinConstructors[Array.sTypeInfo.variantType] = Array.fromVariantPtr;
  PackedByteArray.initBindings();
  _dartBuiltinConstructors[PackedByteArray.sTypeInfo.variantType] =
      PackedByteArray.fromVariantPtr;
  PackedInt32Array.initBindings();
  _dartBuiltinConstructors[PackedInt32Array.sTypeInfo.variantType] =
      PackedInt32Array.fromVariantPtr;
  PackedInt64Array.initBindings();
  _dartBuiltinConstructors[PackedInt64Array.sTypeInfo.variantType] =
      PackedInt64Array.fromVariantPtr;
  PackedFloat32Array.initBindings();
  _dartBuiltinConstructors[PackedFloat32Array.sTypeInfo.variantType] =
      PackedFloat32Array.fromVariantPtr;
  PackedFloat64Array.initBindings();
  _dartBuiltinConstructors[PackedFloat64Array.sTypeInfo.variantType] =
      PackedFloat64Array.fromVariantPtr;
  PackedStringArray.initBindings();
  _dartBuiltinConstructors[PackedStringArray.sTypeInfo.variantType] =
      PackedStringArray.fromVariantPtr;
  PackedVector2Array.initBindings();
  _dartBuiltinConstructors[PackedVector2Array.sTypeInfo.variantType] =
      PackedVector2Array.fromVariantPtr;
  PackedVector3Array.initBindings();
  _dartBuiltinConstructors[PackedVector3Array.sTypeInfo.variantType] =
      PackedVector3Array.fromVariantPtr;
  PackedColorArray.initBindings();
  _dartBuiltinConstructors[PackedColorArray.sTypeInfo.variantType] =
      PackedColorArray.fromVariantPtr;
}

@internal
GDExtensionTypeFromVariant? getToTypeConstructor(int type) {
  return _toTypeConstructor[type];
}

class Variant implements Finalizable {
  static final finalizer = NativeFinalizer(gde.dartBindings.finalizeVariant);

  // TODO: This is supposed to come from the generator, but we
  // may just need to take the max size
  static const int _size = 24;
  static final TypeInfo sTypeInfo = TypeInfo(
    Variant,
    StringName.fromString('Variant'),
    StringName.fromString('Variant'),
    variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_VARIANT_MAX,
    size: _size,
  );

  TypeInfo get typeInfo => sTypeInfo;

  final Pointer<Uint8> _opaque = gde.ffiBindings.gde_mem_alloc(_size).cast();

  Pointer<Uint8> get nativePtr => _opaque;

  Variant([Object? obj]) {
    if (obj == null) {
      gde.ffiBindings.gde_variant_new_nil(nativePtr.cast());
    } else if (obj is Variant) {
      throw ArgumentError.value(
          obj, 'obj', 'Do not construct Variants with Variants.');
    } else {
      _initFromObject(obj);
    }
    _attachFinalizer();
  }

  Variant.fromVariantPtr(Pointer<void> ptr) {
    gde.ffiBindings.gde_variant_new_copy(nativePtr.cast(), ptr.cast());
    _attachFinalizer();
  }

  VariantType getType() {
    final cValue = gde.ffiBindings.gde_variant_get_type(_opaque.cast());
    return VariantType.fromValue(cValue);
  }

  void constructCopy(GDExtensionTypePtr ptr) {
    gde.ffiBindings.gde_variant_new_copy(ptr, nativePtr.cast());
  }

  T? cast<T>() {
    if (<T>[] is List<BuiltinType>) {
      var typeInfo = gde.dartBindings.getGodotTypeInfo(T);
      return convertFromVariant(this, typeInfo) as T?;
    }
    final obj = convertFromVariant(this, GodotObject.sTypeInfo) as GodotObject?;
    return obj?.cast<T>();
  }

  void _attachFinalizer() {
    finalizer.attach(this, _opaque.cast());
  }

  void _initFromObject(Object? obj) {
    if (obj == null) {
      gde.ffiBindings.gde_variant_new_nil(nativePtr.cast());
    } else if (obj is ExtensionType) {
      // Already an Object, but constructor expects a pointer to the object
      Pointer<GDExtensionVariantPtr> ptrToObj = malloc<GDExtensionVariantPtr>();
      ptrToObj.value = obj.nativePtr;
      final c = _fromTypeConstructor[
          GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_OBJECT];
      c!.call(nativePtr.cast(), ptrToObj.cast());
      malloc.free(ptrToObj);
    } else if (obj is Variant) {
      gde.ffiBindings
          .gde_variant_new_copy(nativePtr.cast(), obj.nativePtr.cast());
    } else if (obj is Pointer) {
      // Passed in a pointer, assume we know what we're doing and this is actually a
      // pointer to a Godot object.
      // TODO: Try to find a way to remove this to prevent abuse.
      final c = _fromTypeConstructor[
          GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_OBJECT];
      c!.call(nativePtr.cast(), obj.cast());
    } else if (obj is BuiltinType) {
      // Builtin type
      final typeInfo = obj.typeInfo;
      final c = _fromTypeConstructor[typeInfo.variantType];
      c!.call(nativePtr.cast(), obj.nativePtr.cast());
    } else {
      // Convert built in types
      using((arena) {
        switch (obj) {
          case final bool obj:
            final b =
                arena.allocate<GDExtensionBool>(sizeOf<GDExtensionBool>());
            b.value = obj ? 1 : 0;
            final c = _fromTypeConstructor[
                GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_BOOL];
            c!(nativePtr.cast(), b.cast());
            break;
          case final Enum obj:
            final i = arena.allocate<GDExtensionInt>(sizeOf<GDExtensionInt>());
            i.value = obj.index;
            final c = _fromTypeConstructor[
                GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_INT];
            c!(nativePtr.cast(), i.cast());
            break;
          case final int obj:
            final i = arena.allocate<GDExtensionInt>(sizeOf<GDExtensionInt>());
            i.value = obj;
            final c = _fromTypeConstructor[
                GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_INT];
            c!(nativePtr.cast(), i.cast());
            break;
          case final double obj:
            final d = arena.allocate<Double>(sizeOf<Double>());
            d.value = obj;
            final c = _fromTypeConstructor[
                GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_FLOAT];
            c!(nativePtr.cast(), d.cast());
            break;
          case final String obj:
            final gdString = GDString.fromString(obj);
            final c = _fromTypeConstructor[
                GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_STRING];
            c!(nativePtr.cast(), gdString.nativePtr.cast());
            break;
          case final Future<void> _:
            // Allow FutureOr and Future void to be return types, but not
            // others. This simply returns the variant 'nil'. This is
            // specifically for async signal recievers, which return
            // FutureOr<void>
            gde.ffiBindings.gde_variant_new_nil(nativePtr.cast());
            break;
          // TODO: All the other variant types (dictionary? List?)
          default:
            throw ArgumentError(
                'Trying to create Variant with unsupported object type ${obj.runtimeType}',
                'obj');
        }
      });
    }
  }
}

// Mostly use from C where we don't need to hold a copy of the Variant and
// can copy it directly from its pointer. Prevents an extra constructor / destructor
// call.
@pragma('vm:entry-point')
Object? convertFromVariantPtr(
    GDExtensionVariantPtr variantPtr, TypeInfo? typeInfo) {
  Object? ret;

  int variantType = gde.ffiBindings.gde_variant_get_type(variantPtr.cast());
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
    var builtin = builtinConstructor(variantPtr);
    return builtin;
  }

  // Else, it's probably a dart native type
  ret = using((arena) {
    switch (variantType) {
      // Built-in types
      case GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_BOOL:
        Pointer<GDExtensionBool> ptr =
            arena.allocate(sizeOf<GDExtensionBool>());
        c!(ptr.cast(), variantPtr);
        return ptr.value != 0;
      case GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_INT:
        Pointer<GDExtensionInt> ptr = arena.allocate(sizeOf<GDExtensionInt>());
        c!(ptr.cast(), variantPtr);
        return ptr.value;
      case GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_FLOAT:
        Pointer<Double> ptr = arena.allocate(sizeOf<Double>());
        c!(ptr.cast(), variantPtr);
        return ptr.value;
      case GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_STRING_NAME:
        var gdStringName = StringName();
        c!(gdStringName.nativePtr.cast(), variantPtr);
        return gdStringName.toDartString();
      case GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_STRING:
        var gdString = GDString();
        c!(gdString.nativePtr.cast(), variantPtr);
        return gdString.toDartString();

      // Or a hand-implemented object
      case GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_VECTOR3:
        return Vector3.fromVariantPtr(variantPtr);

      // Or a wrapped object
      case GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_OBJECT:
        Pointer<GDExtensionObjectPtr> ptr =
            arena.allocate(sizeOf<GDExtensionObjectPtr>());
        c!(ptr.cast(), variantPtr);
        if (typeInfo?.scriptInfo != null) {
          final scriptInstance = gde.dartBindings.getScriptInstance(ptr.value);
          if (scriptInstance != nullptr) {
            return gde.dartBindings.objectFromScriptInstance(scriptInstance);
          }
        } else {
          final token =
              typeInfo?.bindingToken ?? GodotObject.sTypeInfo.bindingToken;
          return gde.dartBindings.gdObjectToDartObject(
            ptr.value,
            token,
          );
        }
        break;

      // TODO: all the other variant types
      default:
    }
    return null;
  });

  return ret;
}

// Use in all cases where you already have a Dart Variant.
Object? convertFromVariant(
  Variant variant,
  TypeInfo? typeInfo,
) {
  return convertFromVariantPtr(variant.nativePtr.cast(), typeInfo);
}
