import 'dart:ffi';

import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import '../gen/builtins.dart';
import '../gen/global_constants.dart';
import '../variant/variant.dart';
import 'core.dart';

// In order to avoid having to place @pragma('vm:entry-point') on
// every method in Godot, use a function that we can get and invoke
// without having to invoke the method by name
typedef GodotMethodCall<T> = dynamic Function(T self, List<Object?> args);
typedef ConstructFromGodotObject<T> = T Function(Pointer<Void>);
typedef ConstructObjectDefault<T> = T Function();
typedef ConstructCopy<T> = T Function(GDExtensionConstTypePtr);
typedef FromPointer<T> = T Function(Pointer<Void> ptr);
typedef ToPointer<T> = void Function(T self, Pointer<Void> ptr);

abstract interface class TypeInfo {
  Type get type;
  StringName get className;
  int get variantType;
}

@immutable
class PrimitiveTypeInfo<T> implements TypeInfo {
  @override
  @pragma('vm:entry-point')
  final Type type = T;

  @override
  @pragma('vm:entry-point')
  final StringName className;

  @override
  @pragma('vm:entry-point')
  final int variantType;

  final FromPointer<T> fromPointer;
  final ToPointer<T> toPointer;

  PrimitiveTypeInfo({
    required this.className,
    required this.variantType,
    required this.fromPointer,
    required this.toPointer,
  });

  static late Map<Type?, PrimitiveTypeInfo<dynamic>> _typeMapping;
  static void initTypeMappings() {
    _typeMapping = {
      null: PrimitiveTypeInfo<void>(
        className: StringName.fromString('void'),
        variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_NIL,
        fromPointer: (ptr) {},
        toPointer: (self, ptr) {},
      ),
      bool: PrimitiveTypeInfo<bool>(
        className: StringName.fromString('bool'),
        variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_BOOL,
        fromPointer: (ptr) => ptr.cast<Bool>().value,
        toPointer: (self, ptr) => ptr.cast<Bool>().value = self,
      ),

      // Integer types
      int: PrimitiveTypeInfo<int>(
        className: StringName.fromString('int'),
        variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_INT,
        fromPointer: (ptr) => ptr.cast<Int64>().value,
        toPointer: (self, ptr) => ptr.cast<Int64>().value = self,
      ),
      Int8: PrimitiveTypeInfo<int>(
        className: StringName.fromString('int8'),
        variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_INT,
        fromPointer: (ptr) => ptr.cast<Int8>().value,
        toPointer: (self, ptr) => ptr.cast<Int8>().value = self,
      ),
      Uint8: PrimitiveTypeInfo<int>(
        className: StringName.fromString('uint8'),
        variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_INT,
        fromPointer: (ptr) => ptr.cast<Uint8>().value,
        toPointer: (self, ptr) => ptr.cast<Uint8>().value = self,
      ),
      Int16: PrimitiveTypeInfo<int>(
        className: StringName.fromString('int16'),
        variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_INT,
        fromPointer: (ptr) => ptr.cast<Int16>().value,
        toPointer: (self, ptr) => ptr.cast<Int16>().value = self,
      ),
      Uint16: PrimitiveTypeInfo<int>(
        className: StringName.fromString('uint16'),
        variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_INT,
        fromPointer: (ptr) => ptr.cast<Uint16>().value,
        toPointer: (self, ptr) => ptr.cast<Uint16>().value = self,
      ),
      Int32: PrimitiveTypeInfo<int>(
        className: StringName.fromString('int32'),
        variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_INT,
        fromPointer: (ptr) => ptr.cast<Int32>().value,
        toPointer: (self, ptr) => ptr.cast<Int32>().value = self,
      ),
      Uint32: PrimitiveTypeInfo<int>(
        className: StringName.fromString('uint32'),
        variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_INT,
        fromPointer: (ptr) => ptr.cast<Uint32>().value,
        toPointer: (self, ptr) => ptr.cast<Uint32>().value = self,
      ),
      Int64: PrimitiveTypeInfo<int>(
        className: StringName.fromString('int64'),
        variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_INT,
        fromPointer: (ptr) => ptr.cast<Int64>().value,
        toPointer: (self, ptr) => ptr.cast<Int64>().value = self,
      ),
      // TODO: This actually would need to be `bigint` to be correct
      Uint64: PrimitiveTypeInfo<int>(
        className: StringName.fromString('uint64'),
        variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_INT,
        fromPointer: (ptr) => ptr.cast<Uint64>().value,
        toPointer: (self, ptr) => ptr.cast<Uint64>().value = self,
      ),

      // Floating point types
      double: PrimitiveTypeInfo<double>(
        className: StringName.fromString('double'),
        variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_FLOAT,
        fromPointer: (ptr) => ptr.cast<Double>().value,
        toPointer: (self, ptr) => ptr.cast<Double>().value = self,
      ),
      Float: PrimitiveTypeInfo<double>(
        className: StringName.fromString('float'),
        variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_FLOAT,
        fromPointer: (ptr) => ptr.cast<Float>().value,
        toPointer: (self, ptr) => ptr.cast<Float>().value = self,
      ),
      Double: PrimitiveTypeInfo<double>(
        className: StringName.fromString('double'),
        variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_FLOAT,
        fromPointer: (ptr) => ptr.cast<Double>().value,
        toPointer: (self, ptr) => ptr.cast<Double>().value = self,
      ),

      String: PrimitiveTypeInfo<String>(
        className: StringName.fromString('String'),
        variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_STRING,
        fromPointer: (ptr) => throw InvalidPrimitiveCastException('unknown'),
        toPointer: (self, ptr) =>
            throw InvalidPrimitiveCastException('unknown'),
      ),

      Pointer<Void>: PrimitiveTypeInfo<Pointer<Void>>(
        className: StringName.fromString('Pointer<Void>'),
        variantType: GDExtensionVariantType
            .GDEXTENSION_VARIANT_TYPE_VARIANT_MAX, // Not supported!
        fromPointer: (ptr) => ptr.cast<Pointer<Void>>().value,
        toPointer: (self, ptr) => ptr.cast<Pointer<Void>>().value = ptr,
      )
    };
  }

  static PrimitiveTypeInfo<dynamic>? forType(Type? type) {
    return _typeMapping[type];
  }
}

@immutable
class NativeStructureTypeInfo<T> implements TypeInfo {
  @override
  final StringName className;

  @override
  final Type type = T;

  // Native structures can't be stored in variants.
  @override
  int get variantType => GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_NIL;

  final FromPointer<T> fromPointer;
  final ToPointer<T> toPointer;

  NativeStructureTypeInfo({
    required this.className,
    required this.fromPointer,
    required this.toPointer,
  });
}

/// Type
@immutable
class BuiltinTypeInfo<T> implements TypeInfo {
  @override
  @pragma('vm:entry-point')
  final Type type = T;

  @override
  @pragma('vm:entry-point')
  final StringName className;

  /// The size of the builtin type.
  final int size;

  @override
  @pragma('vm:entry-point')
  final int variantType;

  /// Construct a default version of this object. Called from [TypeResolver]
  @pragma('vm:entry-point')
  final ConstructObjectDefault<T> constructObjectDefault;

  /// Copy this object from Godot. Called from [TypeResolver].
  @pragma('vm:entry-point')
  final ConstructCopy<T> constructCopy;

  BuiltinTypeInfo({
    required this.className,
    required this.size,
    required this.variantType,
    required this.constructObjectDefault,
    required this.constructCopy,
  });
}

class MethodInfo<T> {
  @pragma('vm:entry-point')
  final String name;
  @pragma('vm:entry-point')
  final GodotMethodCall<T> dartMethodCall;
  @pragma('vm:entry-point')
  final List<PropertyInfo> args;
  @pragma('vm:entry-point')
  final PropertyInfo? returnInfo;
  @pragma('vm:entry-point')
  final MethodFlags flags;

  MethodInfo({
    required this.name,
    required this.dartMethodCall,
    required this.args,
    this.returnInfo,
    this.flags = MethodFlags.methodFlagsDefault,
  });

  dynamic call(dynamic self, List<Object?> args) {
    return dartMethodCall(self as T, args);
  }

  @pragma('vm:entry-point')
  Dictionary asDict() {
    var dict = Dictionary();
    dict[Variant('name')] = Variant(name);
    var argsArray = Array();
    for (int i = 0; i < args.length; ++i) {
      argsArray.append(Variant(args[i].asDict()));
    }
    dict[Variant('args')] = Variant(argsArray);
    if (returnInfo != null) {
      dict[Variant('return')] = Variant(returnInfo?.asDict());
    }
    dict[Variant('flags')] = Variant(flags);

    return dict;
  }
}

class SignalInfo {
  @pragma('vm:entry-point')
  final String name;
  final List<PropertyInfo> args;
  final MethodFlags flags;

  SignalInfo({
    required this.name,
    required this.args,
    this.flags = MethodFlags.methodFlagsDefault,
  });

  @pragma('vm:entry-point')
  Dictionary asDict() {
    var dict = Dictionary();
    dict[Variant('name')] = Variant(name);
    var argsArray = Array();
    for (int i = 0; i < args.length; ++i) {
      argsArray.append(Variant(args[i].asDict()));
    }
    dict[Variant('args')] = Variant(argsArray);
    dict[Variant('flags')] = Variant(flags);

    return dict;
  }
}

/// [ExtensionTypeInfo] contains information about the type meant to
/// be used in binding. It is used for both ClassDB registered classes
/// and for Script classes.
///
/// Most Godot bound classes have this generated for them as a static member
/// (Object.sTypeInfo) but for classes you create, you will need to add it.
///
/// For types assignable to Variants, use [BuiltinTypeInfo]. For Dart pimitive
/// types, use [PrimitiveTypeInfo].
class ExtensionTypeInfo<T> implements TypeInfo {
  @override
  @pragma('vm:entry-point')
  final Type type = T;

  /// The name of the class
  @override
  @pragma('vm:entry-point')
  final StringName className;

  @override
  @pragma('vm:entry-point')
  int get variantType => GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_OBJECT;

  @pragma('vm:entry-point')
  final ExtensionTypeInfo<dynamic>? parentTypeInfo;

  /// The first class in the inheritance tree that is implemented
  /// natively in Godot. Can be the class itself.
  @pragma('vm:entry-point')
  final StringName nativeTypeName;

  // Whether or not this extension type inherits from RefCounted. If it is, It's
  // always passed to Dart wrapped in a Ref object (not a straight pointer)
  final bool isRefCounted;

  /// Construct this object from Godot with its default constructor.
  /// Called from [TypeResolver].
  @pragma('vm:entry-point')
  final ConstructObjectDefault<T> constructObjectDefault;

  /// Cosntruct this object with a Godot created owner.
  /// Called from [TypeResolver].
  @pragma('vm:entry-point')
  final ConstructFromGodotObject<T> constructFromGodotObject;

  /// A list of Dart methods callable from Godot. For the Godot
  /// standard library, this will be empty, as Godot will never
  /// call into Dart for non-virtal methods.
  @pragma('vm:entry-point')
  List<MethodInfo<T>> methods;

  /// A list of Dart Signals callable from Godot. For the Godot
  /// standard library, this will be empty.
  @pragma('vm:entry-point')
  final List<SignalInfo> signals;

  /// A list of Dart Properties usable from Godot. For the Godot
  /// standard library, this will be empty.
  @pragma('vm:entry-point')
  final List<DartPropertyInfo<T, dynamic>> properties;

  @pragma('vm:entry-point')
  final List<RpcInfo> rpcInfo;

  @pragma('vm:entry-point')
  final bool isGlobalClass;

  // TODO: We can likely make this work better by having a ScriptTypeInfo that
  // inherits from ExtensionTypeInfo instead of this flag.
  @pragma('vm:entry-point')
  final bool isScript;

  ExtensionTypeInfo({
    required this.className,
    required this.parentTypeInfo,
    required this.nativeTypeName,
    required this.isRefCounted,
    required this.constructObjectDefault,
    required this.constructFromGodotObject,
    this.methods = const [],
    this.signals = const [],
    this.properties = const [],
    this.rpcInfo = const [],
    this.isGlobalClass = false,
    this.isScript = false,
  });

  @pragma('vm:entry-point')
  bool hasMethod(String methodName) => getMethodInfo(methodName) != null;
  @pragma('vm:entry-point')
  bool hasSignal(String signalName) => getSignalInfo(signalName) != null;

  @pragma('vm:entry-point')
  MethodInfo<T>? getMethodInfo(String methodName) {
    return methods.firstWhereOrNull((e) => e.name == methodName);
  }

  @pragma('vm:entry-point')
  SignalInfo? getSignalInfo(String signalName) {
    return signals.firstWhereOrNull((e) => e.name == signalName);
  }

  @pragma('vm:entry-point')
  PropertyInfo? getPropertyInfo(String propertyName) {
    return properties.firstWhereOrNull((e) => e.name == propertyName);
  }
}
