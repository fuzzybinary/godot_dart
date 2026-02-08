import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../core/core_types.dart';
import '../core/gdextension.dart';
import '../core/gdextension_ffi_bindings.dart';
import '../core/godot_dart_native_bridge.dart';
import '../core/type_info.dart';
import '../core/type_resolver.dart';
import '../gen/builtins.dart';
import '../gen/classes/graph_edit.dart';
import '../gen/global_constants.dart';
import 'array.dart';
import 'vector2.dart';
import 'vector3.dart';

export 'vector2.dart';
export 'vector3.dart';
export 'array.dart';
export 'typed_array.dart';

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

void initVariantBindings(
    GDExtensionFFI ffIinterface, TypeResolver typeResolver) {
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
  typeResolver.addType(GDString.sTypeInfo);

  StringName.initBindings();
  typeResolver.addType(StringName.sTypeInfo);
  _dartBuiltinConstructors[StringName.sTypeInfo.variantType] =
      StringName.fromVariantPtr;
  // Generate this?
  Vector2.initBindings();
  typeResolver.addType(Vector2.sTypeInfo);
  _dartBuiltinConstructors[Vector2.sTypeInfo.variantType] =
      Vector2.fromVariantPtr;
  Vector2i.initBindings();
  typeResolver.addType(Vector2i.sTypeInfo);
  _dartBuiltinConstructors[Vector2i.sTypeInfo.variantType] =
      Vector2i.fromVariantPtr;
  Vector3.initBindings();
  typeResolver.addType(Vector3.sTypeInfo);
  _dartBuiltinConstructors[Vector3.sTypeInfo.variantType] =
      Vector3.fromVariantPtr;
  Vector3i.initBindings();
  typeResolver.addType(Vector3i.sTypeInfo);
  _dartBuiltinConstructors[Vector3i.sTypeInfo.variantType] =
      Vector3i.fromVariantPtr;
  Vector4.initBindings();
  typeResolver.addType(Vector4.sTypeInfo);
  _dartBuiltinConstructors[Vector4.sTypeInfo.variantType] =
      Vector4.fromVariantPtr;
  Vector4i.initBindings();
  typeResolver.addType(Vector4i.sTypeInfo);
  _dartBuiltinConstructors[Vector4i.sTypeInfo.variantType] =
      Vector4i.fromVariantPtr;
  Quaternion.initBindings();
  typeResolver.addType(Quaternion.sTypeInfo);
  _dartBuiltinConstructors[Quaternion.sTypeInfo.variantType] =
      Quaternion.fromVariantPtr;
  Rect2.initBindings();
  typeResolver.addType(Rect2.sTypeInfo);
  _dartBuiltinConstructors[Rect2.sTypeInfo.variantType] = Rect2.fromVariantPtr;
  Rect2i.initBindings();
  typeResolver.addType(Rect2i.sTypeInfo);
  _dartBuiltinConstructors[Rect2i.sTypeInfo.variantType] =
      Rect2i.fromVariantPtr;
  Transform2D.initBindings();
  typeResolver.addType(Transform2D.sTypeInfo);
  _dartBuiltinConstructors[Transform2D.sTypeInfo.variantType] =
      Transform2D.fromVariantPtr;
  Plane.initBindings();
  typeResolver.addType(Plane.sTypeInfo);
  _dartBuiltinConstructors[Plane.sTypeInfo.variantType] = Plane.fromVariantPtr;
  AABB.initBindings();
  typeResolver.addType(AABB.sTypeInfo);
  _dartBuiltinConstructors[AABB.sTypeInfo.variantType] = AABB.fromVariantPtr;
  Basis.initBindings();
  typeResolver.addType(Basis.sTypeInfo);
  _dartBuiltinConstructors[Basis.sTypeInfo.variantType] = Basis.fromVariantPtr;
  Transform3D.initBindings();
  typeResolver.addType(Transform3D.sTypeInfo);
  _dartBuiltinConstructors[Transform3D.sTypeInfo.variantType] =
      Transform3D.fromVariantPtr;
  Projection.initBindings();
  typeResolver.addType(Projection.sTypeInfo);
  _dartBuiltinConstructors[Projection.sTypeInfo.variantType] =
      Projection.fromVariantPtr;
  Color.initBindings();
  typeResolver.addType(Color.sTypeInfo);
  _dartBuiltinConstructors[Color.sTypeInfo.variantType] = Color.fromVariantPtr;
  NodePath.initBindings();
  typeResolver.addType(NodePath.sTypeInfo);
  _dartBuiltinConstructors[NodePath.sTypeInfo.variantType] =
      NodePath.fromVariantPtr;
  RID.initBindings();
  typeResolver.addType(RID.sTypeInfo);
  _dartBuiltinConstructors[RID.sTypeInfo.variantType] = RID.fromVariantPtr;
  Callable.initBindings();
  typeResolver.addType(Callable.sTypeInfo);
  _dartBuiltinConstructors[Callable.sTypeInfo.variantType] =
      Callable.fromVariantPtr;
  Signal.initBindings();
  typeResolver.addType(Signal.sTypeInfo);
  _dartBuiltinConstructors[Signal.sTypeInfo.variantType] =
      Signal.fromVariantPtr;
  Dictionary.initBindings();
  typeResolver.addType(Dictionary.sTypeInfo);
  _dartBuiltinConstructors[Dictionary.sTypeInfo.variantType] =
      Dictionary.fromVariantPtr;
  GDBaseArray.initBindings();
  typeResolver.addType(GDBaseArray.sTypeInfo);
  _dartBuiltinConstructors[GDBaseArray.sTypeInfo.variantType] =
      GDArray.fromVariantPtr; // NB: requests for Godot Array create GDArray
  PackedByteArray.initBindings();
  typeResolver.addType(PackedByteArray.sTypeInfo);
  _dartBuiltinConstructors[PackedByteArray.sTypeInfo.variantType] =
      PackedByteArray.fromVariantPtr;
  PackedInt32Array.initBindings();
  typeResolver.addType(PackedInt32Array.sTypeInfo);
  _dartBuiltinConstructors[PackedInt32Array.sTypeInfo.variantType] =
      PackedInt32Array.fromVariantPtr;
  PackedInt64Array.initBindings();
  typeResolver.addType(PackedInt64Array.sTypeInfo);
  _dartBuiltinConstructors[PackedInt64Array.sTypeInfo.variantType] =
      PackedInt64Array.fromVariantPtr;
  PackedFloat32Array.initBindings();
  typeResolver.addType(PackedFloat32Array.sTypeInfo);
  _dartBuiltinConstructors[PackedFloat32Array.sTypeInfo.variantType] =
      PackedFloat32Array.fromVariantPtr;
  PackedFloat64Array.initBindings();
  typeResolver.addType(PackedFloat64Array.sTypeInfo);
  _dartBuiltinConstructors[PackedFloat64Array.sTypeInfo.variantType] =
      PackedFloat64Array.fromVariantPtr;
  PackedStringArray.initBindings();
  typeResolver.addType(PackedStringArray.sTypeInfo);
  _dartBuiltinConstructors[PackedStringArray.sTypeInfo.variantType] =
      PackedStringArray.fromVariantPtr;
  PackedVector2Array.initBindings();
  typeResolver.addType(PackedVector2Array.sTypeInfo);
  _dartBuiltinConstructors[PackedVector2Array.sTypeInfo.variantType] =
      PackedVector2Array.fromVariantPtr;
  PackedVector3Array.initBindings();
  typeResolver.addType(PackedVector3Array.sTypeInfo);
  _dartBuiltinConstructors[PackedVector3Array.sTypeInfo.variantType] =
      PackedVector3Array.fromVariantPtr;
  PackedColorArray.initBindings();
  typeResolver.addType(PackedColorArray.sTypeInfo);
  _dartBuiltinConstructors[PackedColorArray.sTypeInfo.variantType] =
      PackedColorArray.fromVariantPtr;
}

@internal
@pragma('vm:entry-point')
GDExtensionTypeFromVariant? getToTypeConstructor(int type) {
  return _toTypeConstructor[type];
}

@pragma('vm:entry-point')
class Variant implements Finalizable {
  static final finalizer =
      NativeFinalizer(Native.addressOf(GDNativeInterface.finalizeVariant));

  // TODO: This is supposed to come from the generator, but we
  // may just need to take the max size
  static const int _size = 24;
  static final sTypeInfo = BuiltinTypeInfo<Variant>(
    className: StringName.fromString('Variant'),
    variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_VARIANT_MAX,
    size: _size,
    constructObjectDefault: () => Variant(),
    constructCopy: (ptr) => Variant.fromVariantPtr(ptr),
  );

  @pragma('vm:entry-point')
  TypeInfo get typeInfo => sTypeInfo;

  final Pointer<Uint8> _opaque = gde.ffiBindings.gde_mem_alloc(_size).cast();

  Pointer<Uint8> get nativePtr => _opaque;
  @pragma('vm:entry-point')
  int get nativePointerAddress => nativePtr.address;

  @pragma('vm:entry-point')
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

  @pragma('vm:entry-point')
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

  T cast<T>() {
    final value = convertFromVariantPtr(nativePtr.cast());
    // Allow weak conversion from StringName / GDString to Dart Strings
    if (T == String) {
      if (value is StringName) return value.toDartString() as T;
      if (value is GDString) return value.toDartString() as T;
    }
    return value as T;
  }

  T? as<T>() {
    final value = convertFromVariantPtr(nativePtr.cast());
    // Allow weak conversion from StringName / GDString to Dart Strings
    if (T == String) {
      if (value is StringName) return value.toDartString() as T;
      if (value is GDString) return value.toDartString() as T;
    }
    if (value is T) {
      return value;
    }
    return null;
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
            // Allow FutureOr<void> and Future<void> to be return types, but not
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
Object? convertFromVariantPtr(GDExtensionVariantPtr variantPtr) {
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
      case GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_VECTOR2:
        return Vector2.fromVariantPtr(variantPtr);

      // Or a wrapped object
      case GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_OBJECT:
        Pointer<GDExtensionObjectPtr> ptr =
            arena.allocate(sizeOf<GDExtensionObjectPtr>());
        c!(ptr.cast(), variantPtr);
        final scriptInstance = GDNativeInterface.getScriptInstance(ptr.value);
        if (scriptInstance != nullptr) {
          return GDNativeInterface.objectFromScriptInstance(scriptInstance);
        }

        return ptr.value.toDart();

      // TODO: all the other variant types
      default:
    }
    return null;
  });

  return ret;
}
