import 'package:tuple/tuple.dart';

import 'godot_extension_api_json.dart';
import 'type_helpers.dart';
import 'type_info.dart';

class GodotApiInfo {
  static GodotApiInfo? _instance;
  factory GodotApiInfo.instance() {
    return _instance!;
  }

  late final GodotExtensionApiJson api;

  Map<String, BuiltinClass> builtinClasses = {};
  Map<String, GodotExtensionApiJsonClass> engineClasses = {};
  Map<String, NativeStructure> nativeStructures = {};
  Set<String> singletons = {};

  late final BuiltinClassSize classSize;

  GodotApiInfo.fromJson(Map<String, dynamic> json) {
    api = GodotExtensionApiJson.fromJson(json);

    builtinClasses = {for (final e in api.builtinClasses) e.name: e};
    engineClasses = {for (final e in api.classes) e.name: e};
    nativeStructures = {for (final e in api.nativeStructures) e.name: e};
    singletons = {for (final e in api.singletons) e.name};

    classSize = api.builtinClassSizes
        .firstWhere((e) => e.buildConfiguration == 'float64');

    _instance = this;
  }

  ArgumentInfo getArgumentInfo(dynamic argument) {
    final String rawType;
    final ArgumentMeta? meta;
    if (argument is Singleton) {
      rawType = argument.type;
      meta = null;
    } else if (argument is Argument) {
      rawType = argument.name;
      meta = argument.meta;
    } else {
      throw ArgumentError(
          'getArgument only accepts Singleton or Argument as parameters');
    }

    final typeCategory = getTypeCategory(rawType);
    final pointerType = _getPointerType(rawType);

    return ArgumentInfo(
      godotType: rawType,
      isOptional:
          pointerType == null && typeCategory == TypeCategory.engineClass,
      pointerType: pointerType,
      rawName: argument['name'],
      meta: meta,
    );
  }

  TypeCategory getTypeCategory(String? godotType) {
    if (godotType == null) return TypeCategory.voidType;

    Tuple2 strippedType = _getStrippedType(godotType);
    if (builtinClasses.containsKey(strippedType.item1)) {
      return TypeCategory.builtinClass;
    } else if (engineClasses.containsKey(strippedType.item1)) {
      return TypeCategory.engineClass;
    } else if (nativeStructures.containsKey(strippedType.item1)) {
      return TypeCategory.nativeStructure;
    } else if (godotType == 'Void' && strippedType.item2 == 0) {
      return TypeCategory.voidType;
    } else if (godotType.startsWith('typedarray::')) {
      return TypeCategory.typedArray;
    } else if (godotType.startsWith('enum') ||
        godotType.startsWith('bitfield')) {
      return TypeCategory.enumType;
    } else if (hasDartType(godotType)) {
      return TypeCategory.primitive;
    } else if (godotType == 'Variant') {
      return TypeCategory.builtinClass;
    }

    throw ArgumentError('Unknown type: `$godotType`');
  }

  // ArgumentInfo getReturnInfo(Map<String, dynamic> methodData) {
  //   String? meta;
  //   String rawType;
  //   if (methodData.containsKey('return_type')) {
  //     rawType = methodData['return_type'];
  //   } else if (methodData.containsKey('return_value')) {
  //     final returnValue = methodData['return_value'] as Map<String, dynamic>;
  //     rawType = returnValue['type'] ?? 'Void';
  //     if (returnValue.containsKey('meta')) {
  //       meta = methodData['return_value']['meta'];
  //     }
  //   } else {
  //     rawType = 'Void';
  //   }

  //   final strippedType = _getStrippedType(rawType);

  //   final typeInfo = _findTypeInfo(strippedType.item1, strippedType.item2 > 0);
  //   final pointerType = _getPointerType(rawType);

  //   return ArgumentInfo(
  //     typeInfo: typeInfo,
  //     isOptional: pointerType == null &&
  //         typeInfo.typeCategory == TypeCategory.engineClass,
  //     pointerType: pointerType,
  //     rawName: null,
  //     meta: meta,
  //   );
  // }

  // ArgumentInfo getMemberInfo(Map<String, dynamic> member) {
  //   final rawType = member['type'] as String;
  //   final meta = member['meta'] as String?;
  //   final strippedType = _getStrippedType(rawType);

  //   final typeInfo = _findTypeInfo(strippedType.item1, strippedType.item2 > 0);
  //   final pointerType = _getPointerType(rawType);

  //   return ArgumentInfo(
  //     typeInfo: typeInfo,
  //     isOptional: pointerType == null && strippedType.item2 > 0,
  //     pointerType: pointerType,
  //     rawName: member['name'],
  //     meta: meta,
  //   );
  // }

  // TypeInfo _findTypeInfo(String type, bool isPointer) {
  //   var typeInfo =
  //       builtinClasses[type] ?? engineClasses[type] ?? nativeStructures[type];
  //   if (typeInfo == null) {
  //     if (type == 'Void' && !isPointer) {
  //       typeInfo = TypeInfo.voidType();
  //     } else if (type.startsWith('enum::') || type.startsWith('bitfield::')) {
  //       typeInfo = TypeInfo(
  //         typeCategory: TypeCategory.enumType,
  //         godotType: type,
  //         api: <String, dynamic>{},
  //       );
  //     } else if (type.startsWith('typedarray::')) {
  //       typeInfo = TypeInfo(
  //         typeCategory: TypeCategory.typedArray,
  //         godotType: type,
  //         api: <String, dynamic>{},
  //       );
  //     } else if (hasDartType(type)) {
  //       typeInfo = TypeInfo.primitiveType(type);
  //     } else if (type == 'Variant') {
  //       return TypeInfo(
  //         typeCategory: TypeCategory.builtinClass,
  //         godotType: 'Variant',
  //         api: <String, dynamic>{},
  //       );
  //     }
  //   }

  //   return typeInfo!;
  // }

  /// If this is a pointer, get the Dart FFI Pointer<> type
  /// that would correctly wrap it.
  String? _getPointerType(String rawGodotType) {
    if (!rawGodotType.endsWith('*')) {
      return null;
    }

    final typeTuple = _getStrippedType(rawGodotType);
    final type = typeTuple.item1;
    final pointerCount = typeTuple.item2;

    final ffiType =
        nativeStructures.containsKey(type) ? type : getFFITypeFromString(type);
    String dartType = type;
    if (ffiType != null) {
      dartType = 'Pointer<' * pointerCount;
      dartType += ffiType;
      dartType += '>' * pointerCount;
    } else {
      return null;
    }
    return dartType;
  }
}

// Extensions for getting common info
extension DartBuiltinExtensions on BuiltinClass {
  String get dartName => getCorrectedType(name);
}

extension DartGodotExtensionApiJsonClassExtension
    on GodotExtensionApiJsonClass {
  String get dartName => getCorrectedType(name);
}

extension DartNativeStructureExtensions on NativeStructure {
  String get dartName => getCorrectedType(name);
}

abstract class ArgumentProxy {
  String get name;
  String get type;
  String get dartType;

  bool get needsAllocation;
  bool get isOptional;
  bool get isPointer;

  TypeCategory get typeCategory;

  ArgumentMeta? get meta;

  String getDefaultValue();
}

class SingletonArgumentProxy implements ArgumentProxy {
  final Singleton _singleton;

  SingletonArgumentProxy(this._singleton);

  @override
  String get dartType => godotTypeToDartType(type);

  @override
  String getDefaultValue() {
    if (isOptional) {
      return 'null';
    } else if (defaultValueForType.containsKey(dartType)) {
      return defaultValueForType[dartType]!;
    } else if (dartType == 'String') {
      return "''";
    } else if (type.startsWith('enum::') || type.startsWith('bitfield::')) {
      // TODO: I'd rather this gave a real value
      return '$dartType.values[0]';
    } else if (dartType.contains('Pointer<')) {
      return 'nullptr';
    } else {
      return '$dartType()';
    }
  }

  @override
  bool get isOptional {
    return !isPointer && typeCategory == TypeCategory.engineClass;
  }

  @override
  bool get isPointer {
    return type.endsWith('*');
  }

  @override
  String get name => _singleton.name;

  @override
  bool get needsAllocation => dartType.contains(type);

  @override
  String get type => _singleton.type;

  @override
  TypeCategory get typeCategory =>
      GodotApiInfo.instance().getTypeCategory(type);

  @override
  ArgumentMeta? get meta => null;
}

extension DartSingletonExtensions on Singleton {
  SingletonArgumentProxy get proxy => SingletonArgumentProxy(this);
}

class ArgumentArgumentProxy implements ArgumentProxy {
  final Argument _argument;

  ArgumentArgumentProxy(this._argument);

  @override
  String get dartType => godotTypeToDartType(type);

  @override
  String getDefaultValue() {
    if (isOptional) {
      return 'null';
    } else if (defaultValueForType.containsKey(dartType)) {
      return defaultValueForType[dartType]!;
    } else if (dartType == 'String') {
      return "''";
    } else if (type.startsWith('enum::') || type.startsWith('bitfield::')) {
      // TODO: I'd rather this gave a real value
      return '$dartType.values[0]';
    } else if (dartType.contains('Pointer<')) {
      return 'nullptr';
    } else {
      return '$dartType()';
    }
  }

  @override
  bool get isOptional {
    return !isPointer && typeCategory == TypeCategory.engineClass;
  }

  @override
  bool get isPointer {
    return type.endsWith('*');
  }

  @override
  String get name => _argument.name;

  @override
  bool get needsAllocation => dartType.contains(type);

  @override
  String get type => _argument.type;

  @override
  TypeCategory get typeCategory =>
      GodotApiInfo.instance().getTypeCategory(type);

  @override
  ArgumentMeta? get meta => _argument.meta;
}

extension DartArgumentExtension on Argument {
  ArgumentArgumentProxy get proxy => ArgumentArgumentProxy(this);
}

class ReturnValueArgumentProxy implements ArgumentProxy {
  final ReturnValue _returnValue;

  ReturnValueArgumentProxy(this._returnValue);

  @override
  String get dartType => godotTypeToDartType(type);

  @override
  String getDefaultValue() {
    if (isOptional) {
      return 'null';
    } else if (defaultValueForType.containsKey(dartType)) {
      return defaultValueForType[dartType]!;
    } else if (dartType == 'String') {
      return "''";
    } else if (type.startsWith('enum::') || type.startsWith('bitfield::')) {
      // TODO: I'd rather this gave a real value
      return '$dartType.values[0]';
    } else if (dartType.contains('Pointer<')) {
      return 'nullptr';
    } else {
      return '$dartType()';
    }
  }

  @override
  bool get isOptional {
    return !isPointer && typeCategory == TypeCategory.engineClass;
  }

  @override
  bool get isPointer {
    return type.endsWith('*');
  }

  @override
  String get name => '';

  @override
  bool get needsAllocation => dartType.contains(type);

  @override
  String get type => _returnValue.type;

  @override
  TypeCategory get typeCategory =>
      GodotApiInfo.instance().getTypeCategory(type);

  @override
  ArgumentMeta? get meta => _returnValue.meta;
}

extension DartReturnValueExtension on ReturnValue {
  ReturnValueArgumentProxy get proxy => ReturnValueArgumentProxy(this);
}

String godotTypeToDartType(String? godotType) {
  if (godotType == null) return 'void';

  final strippedType = _getStrippedType(godotType);
  final rawDartType = getCorrectedType(strippedType.item1);
  final typeCategory =
      GodotApiInfo.instance().getTypeCategory(strippedType.item1);
  final isPointer = strippedType.item2 > 0;
  final isOptional = !isPointer && typeCategory == TypeCategory.engineClass;

  if (isPointer) {
    final ffiType =
        GodotApiInfo.instance().nativeStructures.containsKey(strippedType.item1)
            ? strippedType.item1
            : getFFITypeFromString(strippedType.item1);
    var dartType = strippedType.item1;
    if (ffiType != null) {
      dartType = 'Pointer<' * strippedType.item2;
      dartType += ffiType;
      dartType += '>' * strippedType.item2;
      return dartType;
    } else {
      throw Error();
    }
  }

  return '$rawDartType${isOptional ? '?' : ''}';
}

// Stripped type with the number of pointers
Tuple2<String, int> _getStrippedType(String rawGodotType) {
  int pointerCount = 0;
  var strippedType = rawGodotType.replaceFirst('const ', '');
  while (strippedType.endsWith('*')) {
    pointerCount++;
    strippedType = strippedType.substring(0, strippedType.length - 1);
  }
  strippedType = strippedType.trim();

  return Tuple2(strippedType, pointerCount);
}

Singleton argumentFromType(String? type) {
  return Singleton(name: '', type: type ?? 'Void');
}
