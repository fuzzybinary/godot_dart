import 'dart:ffi';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../../godot_dart.dart';
import 'gdextension_ffi_bindings.dart';

class MethodInfo {
  final String name;
  final String? dartMethodName;
  final List<PropertyInfo> args;
  final PropertyInfo? returnInfo;
  final MethodFlags flags;

  MethodInfo({
    required this.name,
    this.dartMethodName,
    required this.args,
    this.returnInfo,
    this.flags = MethodFlags.methodFlagsDefault,
  });

  Dictionary asDict() {
    var dict = Dictionary();
    dict[Variant.fromObject('name')] = Variant.fromObject(name);
    var argsArray = Array();
    for (int i = 0; i < args.length; ++i) {
      argsArray.append(Variant.fromObject(args[i].asDict()));
    }
    dict[Variant.fromObject('args')] = Variant.fromObject(argsArray);
    if (returnInfo != null) {
      dict[Variant.fromObject('return')] =
          Variant.fromObject(returnInfo?.asDict());
    }
    dict[Variant.fromObject('flags')] = Variant.fromObject(flags);

    return dict;
  }
}

/// ScriptInfo contains information about types accessible as Scripts
@immutable
class ScriptInfo {
  final List<MethodInfo> methods;
  final List<MethodInfo> signals;
  final List<PropertyInfo> properties;

  const ScriptInfo({
    required this.methods,
    required this.signals,
    required this.properties,
  });

  MethodInfo? getMethodInfo(String methodName) {
    return methods.firstWhereOrNull((e) => e.name == methodName);
  }

  PropertyInfo? getPropertyInfo(String propertyName) {
    return properties.firstWhereOrNull((e) => e.name == propertyName);
  }
}

/// [TypeInfo] contains information about the type meant to send to Godot
/// binding methods.
///
/// Most Godot bound classes have this generated for them as a static member
/// (Object.sTypeInfo) but for classes you create, you will need to add it.
///
/// For Dart builtin types, use [TypeInfo.forType]
@immutable
class TypeInfo {
  /// The Type for this info
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
  late final Pointer<Void>? bindingToken;

  /// The Type's vTable (a table of virutal methods).
  final Map<String, Pointer<GodotVirtualFunction>> vTable;

  /// Information about this class if it is a Godot "Script". Can be null if this
  /// class is not a script resource
  final ScriptInfo? scriptInfo;

  TypeInfo(
    this.type,
    this.className, {
    this.parentClass,
    this.variantType = GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_OBJECT,
    this.size = 0,
    Pointer<Void>? bindingToken,
    this.vTable = const {},
    this.scriptInfo,
  }) {
    if (variantType == GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_OBJECT &&
        bindingToken == null) {
      // Default to the type as the binding token for objects
      this.bindingToken = gde.dartBindings.toPersistentHandle(type);
    } else {
      this.bindingToken = bindingToken;
    }
  }

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

  static TypeInfo? forType(Type? type) {
    return _typeMapping[type];
  }
}
