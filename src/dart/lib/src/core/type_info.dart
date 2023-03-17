import 'dart:ffi';

import '../../godot_dart.dart';
import '../gen/variant/string_name.dart';
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
  /// The name of the class
  final StringName className;

  /// The Parent Class of the class
  final StringName? parentClass;

  /// The Variant type of this class. This is set to
  /// [GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_OBJECT] by default which
  /// is usually correct for most user created classes
  final int variantType;

  /// Callbacks that create the proper Dart type from the C type. Mostly
  /// only used by core engine classes. Pass null to use the default.
  final Pointer<GDExtensionInstanceBindingCallbacks>? bindingCallbacks;

  TypeInfo(
    this.className, {
    this.parentClass,
    this.variantType = GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_OBJECT,
    this.bindingCallbacks,
  });

  static late Map<Type?, TypeInfo> _typeMapping;
  static void initTypeMappings() {
    _typeMapping = {
      null: TypeInfo(
        StringName.fromString('void'),
        variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_NIL,
      ),
      bool: TypeInfo(
        StringName.fromString('bool'),
        variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_BOOL,
      ),
      int: TypeInfo(
        StringName.fromString('int'),
        variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_INT,
      ),
      double: TypeInfo(
        StringName.fromString('double'),
        variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_FLOAT,
      ),
      String: TypeInfo(
        StringName.fromString('String'),
        variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_STRING,
      ),
    };
  }

  static TypeInfo? forType(Type? type) {
    return _typeMapping[type];
  }
}
