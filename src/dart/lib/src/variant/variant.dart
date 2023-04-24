import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../../godot_dart.dart';
import '../core/gdextension_ffi_bindings.dart';

typedef GDExtensionVariantFromType = void Function(
    GDExtensionVariantPtr, GDExtensionTypePtr);

late List<GDExtensionVariantFromType?> _fromTypeConstructor;
late List<GDExtensionTypeFromVariantConstructorFunc?> _toTypeConstructor;

typedef BuiltinConstructor = BuiltinType Function();
Map<int, BuiltinConstructor> _dartBuiltinConstructors = {};

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
  // because everything else relies on them being done.
  GDString.initBindingsConstructorDestructor();
  StringName.initBindingsConstructorDestructor();
  GDString.initBindings();

  StringName.initBindings();
  _dartBuiltinConstructors[StringName.typeInfo.variantType] = StringName.new;

  // Generate this?
  Vector2.initBindings();
  _dartBuiltinConstructors[Vector2.typeInfo.variantType] = Vector2.new;
  Vector2i.initBindings();
  _dartBuiltinConstructors[Vector2i.typeInfo.variantType] = Vector2i.new;
  Vector3.initBindings();
  _dartBuiltinConstructors[Vector3.typeInfo.variantType] = Vector3.new;
  Vector3i.initBindings();
  _dartBuiltinConstructors[Vector3i.typeInfo.variantType] = Vector3i.new;
  Vector4.initBindings();
  _dartBuiltinConstructors[Vector4.typeInfo.variantType] = Vector4.new;
  Vector4i.initBindings();
  _dartBuiltinConstructors[Vector4i.typeInfo.variantType] = Vector4i.new;
  Quaternion.initBindings();
  _dartBuiltinConstructors[Quaternion.typeInfo.variantType] = Quaternion.new;
  Rect2.initBindings();
  _dartBuiltinConstructors[Rect2.typeInfo.variantType] = Rect2.new;
  Rect2i.initBindings();
  _dartBuiltinConstructors[Rect2i.typeInfo.variantType] = Rect2i.new;
  Transform2D.initBindings();
  _dartBuiltinConstructors[Transform2D.typeInfo.variantType] = Transform2D.new;
  Plane.initBindings();
  _dartBuiltinConstructors[Plane.typeInfo.variantType] = Plane.new;
  AABB.initBindings();
  _dartBuiltinConstructors[AABB.typeInfo.variantType] = AABB.new;
  Basis.initBindings();
  _dartBuiltinConstructors[Basis.typeInfo.variantType] = Basis.new;
  Transform3D.initBindings();
  _dartBuiltinConstructors[Transform3D.typeInfo.variantType] = Transform3D.new;
  Projection.initBindings();
  _dartBuiltinConstructors[Projection.typeInfo.variantType] = Projection.new;
  Color.initBindings();
  _dartBuiltinConstructors[Color.typeInfo.variantType] = Color.new;
  NodePath.initBindings();
  _dartBuiltinConstructors[NodePath.typeInfo.variantType] = NodePath.new;
  RID.initBindings();
  _dartBuiltinConstructors[RID.typeInfo.variantType] = RID.new;
  Callable.initBindings();
  _dartBuiltinConstructors[Callable.typeInfo.variantType] = Callable.new;
  Signal.initBindings();
  _dartBuiltinConstructors[Signal.typeInfo.variantType] = Signal.new;
  Dictionary.initBindings();
  _dartBuiltinConstructors[Dictionary.typeInfo.variantType] = Dictionary.new;
  Array.initBindings();
  _dartBuiltinConstructors[Array.typeInfo.variantType] = Array.new;
  PackedByteArray.initBindings();
  _dartBuiltinConstructors[PackedByteArray.typeInfo.variantType] =
      PackedByteArray.new;
  PackedInt32Array.initBindings();
  _dartBuiltinConstructors[PackedInt32Array.typeInfo.variantType] =
      PackedInt32Array.new;
  PackedInt64Array.initBindings();
  _dartBuiltinConstructors[PackedInt64Array.typeInfo.variantType] =
      PackedInt64Array.new;
  PackedFloat32Array.initBindings();
  _dartBuiltinConstructors[PackedFloat32Array.typeInfo.variantType] =
      PackedFloat32Array.new;
  PackedFloat64Array.initBindings();
  _dartBuiltinConstructors[PackedFloat64Array.typeInfo.variantType] =
      PackedFloat64Array.new;
  PackedStringArray.initBindings();
  _dartBuiltinConstructors[PackedStringArray.typeInfo.variantType] =
      PackedStringArray.new;
  PackedVector2Array.initBindings();
  _dartBuiltinConstructors[PackedVector2Array.typeInfo.variantType] =
      PackedVector2Array.new;
  PackedVector3Array.initBindings();
  _dartBuiltinConstructors[PackedVector3Array.typeInfo.variantType] =
      PackedVector3Array.new;
  PackedColorArray.initBindings();
  _dartBuiltinConstructors[PackedColorArray.typeInfo.variantType] =
      PackedColorArray.new;
}

// TODO: Variant probably shouldn't extend BuiltinType?
class Variant extends BuiltinType {
  // TODO: This is supposed to come from the generator, but we
  // may just need to take the max size
  static const int _size = 24;
  static final TypeInfo typeInfo = TypeInfo(
    StringName.fromString('Variant'),
    variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_VARIANT_MAX,
    size: _size,
  );

  @override
  TypeInfo get staticTypeInfo => typeInfo;

  final Pointer<Uint8> _opaque = calloc<Uint8>(_size);
  @override
  Pointer<Uint8> get nativePtr => _opaque;

  Variant() : super();

  Variant.fromPointer(Pointer<void> ptr) {
    gde.dartBindings.variantCopyFromNative(this, ptr.cast());
  }

  int getType() {
    int Function(Pointer<Void>) getType =
        gde.interface.ref.variant_get_type.asFunction();
    return getType(_opaque.cast());
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
            isLeaf: true)(ret.nativePtr.cast());
  } else if (obj is ExtensionType) {
    // Already an Object, but constructor expects a pointer to the object
    Pointer<GDExtensionVariantPtr> ptrToObj = malloc<GDExtensionVariantPtr>();
    ptrToObj.value = obj.nativePtr;
    c = _fromTypeConstructor[
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_OBJECT];
    c?.call(ret.nativePtr.cast(), ptrToObj.cast());
    malloc.free(ptrToObj);
  } else if (obj is BuiltinType) {
    // Builtin type
    var typeInfo = obj.staticTypeInfo;
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
          GodotDart.instance!.interface.ref.variant_new_nil
              .asFunction<void Function(GDExtensionVariantPtr)>(
                  isLeaf: true)(ret.nativePtr.cast());
      }
    });
  }

  return ret;
}

Object? convertFromVariant(
  Variant variant,
  Pointer<GDExtensionInstanceBindingCallbacks>? bindingCallbacks,
) {
  Object? ret;
  int variantType = variant.getType();
  void Function(GDExtensionTypePtr, GDExtensionVariantPtr)? c;
  if (variantType > 0 && variantType < _toTypeConstructor.length) {
    c = _toTypeConstructor[variantType]?.asFunction();
  }

  if (c == null) {
    // TODO: Output an error message
    return null;
  }

  // To we have a CoreType that we can use to match?
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
      case GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_STRING:
        var gdString = GDString();
        c!(gdString.nativePtr.cast(), variant.nativePtr.cast());
        ret = gde.dartBindings.gdStringToString(gdString);
        break;

      // Or a wrapped object
      case GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_OBJECT:
        Pointer<GDExtensionObjectPtr> ptr =
            arena.allocate(sizeOf<GDExtensionObjectPtr>());
        c!(ptr.cast(), variant.nativePtr.cast());
        ret = gde.dartBindings.gdObjectToDartObject(
          ptr.value,
          bindingCallbacks,
        );
        break;

      // TODO: all the other variant types
      default:
        ret = null;
    }
  });
  return ret;
}
