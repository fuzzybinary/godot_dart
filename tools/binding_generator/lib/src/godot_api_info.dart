import 'package:tuple/tuple.dart';

import 'godot_extension_api_json.dart';
import 'type_helpers.dart';

enum TypeCategory {
  voidType,
  primitive,
  engineClass,
  builtinClass,
  nativeStructure,
  enumType,
  typedArray,
}

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
        .firstWhere((e) => e.buildConfiguration == 'float_64');

    _instance = this;
  }

  bool isRefCounted(String godotType) {
    final strippedType = _getStrippedType(godotType);
    final engineType = engineClasses[strippedType.item1];
    return engineType?.isRefcounted ?? false;
  }

  TypeCategory getTypeCategory(String? godotType) {
    if (godotType == null) return TypeCategory.voidType;

    final strippedType = _getStrippedType(godotType);
    if (hasDartType(strippedType.item1)) {
      return TypeCategory.primitive;
    } else if (builtinClasses.containsKey(strippedType.item1)) {
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
    } else if (godotType == 'Variant') {
      return TypeCategory.builtinClass;
    }

    throw ArgumentError('Unknown type: `$godotType`');
  }
}

// Extensions for getting common info
extension DartBuiltinExtensions on BuiltinClass {
  String get dartName {
    if (name == 'String') {
      return 'GDString';
    } else if (name == 'StringName') {
      return name;
    }
    return getCorrectedType(name);
  }
}

extension DartGodotExtensionApiJsonClassExtension
    on GodotExtensionApiJsonClass {
  String get dartName => getCorrectedType(name);
}

extension DartNativeStructureExtensions on NativeStructure {
  String get dartName => getCorrectedType(name);
}

class ArgumentProxy {
  final String name;
  final String type;
  final String rawDartType;
  final String dartType;

  final bool needsAllocation;
  final bool isOptional;
  final bool isPointer;
  final bool isRefCounted;

  final TypeCategory typeCategory;
  final ArgumentMeta? meta;

  final String defaultValue;

  ArgumentProxy._({
    required this.name,
    required this.type,
    required this.rawDartType,
    required this.dartType,
    required this.needsAllocation,
    required this.isOptional,
    required this.isPointer,
    required this.isRefCounted,
    required this.typeCategory,
    required this.meta,
    required this.defaultValue,
  });

  ArgumentProxy renamed(String newName) {
    return ArgumentProxy._(
        name: newName,
        type: type,
        rawDartType: rawDartType,
        dartType: dartType,
        needsAllocation: needsAllocation,
        isOptional: isOptional,
        isPointer: isPointer,
        isRefCounted: isRefCounted,
        typeCategory: typeCategory,
        meta: meta,
        defaultValue: defaultValue);
  }

  factory ArgumentProxy.fromSingleton(Singleton singleton) {
    final dartType = godotTypeToDartType(singleton.type);
    final isPointer = singleton.type.endsWith('*');
    final typeCategory =
        GodotApiInfo.instance().getTypeCategory(singleton.type);
    final isRefCounted = !isPointer &&
        typeCategory == TypeCategory.engineClass &&
        GodotApiInfo.instance().isRefCounted(singleton.type);
    final isOptional = !isPointer && typeCategory == TypeCategory.engineClass;
    return ArgumentProxy._(
      name: singleton.name,
      type: singleton.type,
      rawDartType: godotTypeToRawDartType(singleton.type),
      dartType: dartType,
      needsAllocation: dartTypes.contains(singleton.type),
      isOptional: isOptional,
      isPointer: isPointer,
      isRefCounted: isRefCounted,
      typeCategory: typeCategory,
      meta: null,
      defaultValue:
          _getDefaultValue(singleton.type, dartType, isOptional, isRefCounted),
    );
  }

  factory ArgumentProxy.fromArgument(Argument argument) {
    final dartType = godotTypeToDartType(argument.type);
    final isPointer = argument.type.endsWith('*');
    final typeCategory = GodotApiInfo.instance().getTypeCategory(argument.type);
    final isRefCounted = !isPointer &&
        typeCategory == TypeCategory.engineClass &&
        GodotApiInfo.instance().isRefCounted(argument.type);
    final isOptional = !isPointer && typeCategory == TypeCategory.engineClass;
    return ArgumentProxy._(
      name: argument.name,
      type: argument.type,
      rawDartType: godotTypeToRawDartType(argument.type),
      dartType: dartType,
      needsAllocation: dartTypes.contains(argument.type),
      isOptional: isOptional,
      isPointer: isPointer,
      isRefCounted: isRefCounted,
      typeCategory: typeCategory,
      meta: argument.meta,
      defaultValue:
          _getDefaultValue(argument.type, dartType, isOptional, isRefCounted),
    );
  }

  factory ArgumentProxy.fromReturnValue(ReturnValue returnValue) {
    final dartType = godotTypeToDartType(returnValue.type);
    final isPointer = returnValue.type.endsWith('*');
    final typeCategory =
        GodotApiInfo.instance().getTypeCategory(returnValue.type);
    final isRefCounted = !isPointer &&
        typeCategory == TypeCategory.engineClass &&
        GodotApiInfo.instance().isRefCounted(returnValue.type);
    final isOptional = !isPointer && typeCategory == TypeCategory.engineClass;
    return ArgumentProxy._(
      name: '',
      type: returnValue.type,
      rawDartType: godotTypeToRawDartType(returnValue.type),
      dartType: dartType,
      needsAllocation: dartTypes.contains(returnValue.type),
      isOptional: isOptional,
      isPointer: isPointer,
      isRefCounted: isRefCounted,
      typeCategory: typeCategory,
      meta: returnValue.meta,
      defaultValue: _getDefaultValue(
          returnValue.type, dartType, isOptional, isRefCounted),
    );
  }

  static String _getDefaultValue(
      String godotType, String dartType, bool isOptional, bool isRefCounted) {
    final myDartType = dartType;
    if (isRefCounted) {
      return '$dartType(null)';
    } else if (isOptional) {
      return 'null';
    } else if (defaultValueForType.containsKey(myDartType)) {
      return defaultValueForType[myDartType]!;
    } else if (myDartType == 'String') {
      return "''";
    } else if (godotType.startsWith('enum::') ||
        godotType.startsWith('bitfield::')) {
      // TODO: I'd rather this gave a real value
      return '$myDartType.values[0]';
    } else if (myDartType.contains('Pointer<')) {
      return 'nullptr';
    } else {
      return '$myDartType()';
    }
  }
}

extension DartSingletonExtensions on Singleton {
  ArgumentProxy get proxy => ArgumentProxy.fromSingleton(this);
}

extension DartArgumentExtension on Argument {
  ArgumentProxy get proxy => ArgumentProxy.fromArgument(this);
}

extension DartReturnValueExtension on ReturnValue {
  ArgumentProxy get proxy => ArgumentProxy.fromReturnValue(this);
}

String godotTypeToRawDartType(String? godotType) {
  if (godotType == null) return 'void';

  final strippedType = _getStrippedType(godotType);
  return getCorrectedType(strippedType.item1);
}

String godotTypeToDartType(String? godotType) {
  if (godotType == null) return 'void';

  final strippedType = _getStrippedType(godotType);
  final rawDartType = getCorrectedType(strippedType.item1);
  final typeCategory =
      GodotApiInfo.instance().getTypeCategory(strippedType.item1);
  final isPointer = strippedType.item2 > 0;
  final isRefCounted = !isPointer &&
      typeCategory == TypeCategory.engineClass &&
      GodotApiInfo.instance().isRefCounted(strippedType.item1);
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
  } else if (isRefCounted) {
    return 'Ref<$rawDartType>';
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
