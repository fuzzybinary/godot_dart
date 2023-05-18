import 'dart:ffi';

import '../../godot_dart.dart';
import 'gdextension_ffi_bindings.dart';

/// [TypeInfo] contains information about the type meant to send to Godot
/// binding methods. Because Type.toString() in Dart doesn't have to return the
/// actual name of the type, we use this instead.
///
/// Most Godot bound classes have this generated for them as a static member
/// (Object.typeInfo) but for classes you create, you will need to add it.
///
/// For Dart builtin types, use [TypeInfo.forType]
class TypeInfo {
  final Type type;

  /// The name of the class
  final StringName className;

  /// The Parent Class of the class
  final StringName? parentClass;

  /// The Variant type of this class. This is set to
  /// [GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_OBJECT] by default which
  /// is usually correct for most user created classes
  final int variantType;

  /// The size of the variant type. Zero for non-variants
  final int size;

  /// The token for binding callbacks for a given type. Actually a Dart persistent
  /// handle to the type istelf.
  final Pointer<Void>? bindingToken;

  /// Whether or not this is a Ref<T> type of the specified object
  final bool isReference;

  TypeInfo(
    this.type,
    this.className, {
    this.parentClass,
    this.variantType = GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_OBJECT,
    this.size = 0,
    this.bindingToken,
    this.isReference = false,
  });

  static late Map<Type?, TypeInfo> _typeMapping;
  static void initTypeMappings() {
    _typeMapping = {
      null: TypeInfo(
        Pointer<void>, // Not sure if this is right.
        StringName.fromString('void'),
        variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_NIL,
      ),
      bool: TypeInfo(
        bool,
        StringName.fromString('bool'),
        variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_BOOL,
      ),
      int: TypeInfo(
        int,
        StringName.fromString('int'),
        variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_INT,
      ),
      double: TypeInfo(
        double,
        StringName.fromString('double'),
        variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_FLOAT,
      ),
      String: TypeInfo(
        String,
        StringName.fromString('String'),
        variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_STRING,
      ),
      Variant: TypeInfo(
        Variant,
        StringName.fromString('Variant'),
        variantType:
            GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_VARIANT_MAX,
      )
    };
  }

  /// Return a copy of this class's typeInfo with [isReference] set to `true`
  TypeInfo asRef() {
    return TypeInfo(
      type,
      className,
      parentClass: parentClass,
      variantType: variantType,
      size: size,
      bindingToken: bindingToken,
      isReference: true,
    );
  }

  static TypeInfo? forType(Type? type) {
    return _typeMapping[type];
  }
}
