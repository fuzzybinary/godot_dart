import 'package:collection/collection.dart';
import 'package:tuple/tuple.dart';

import 'common_helpers.dart';
import 'godot_extension_api_json.dart';
import 'string_extensions.dart';
import 'type_helpers.dart';

enum TypeCategory {
  voidType,
  primitive,
  engineClass,
  builtinClass,
  nativeStructure,
  enumType,
  bitfieldType,
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
  Map<String, Object> enumMap = {};

  late final BuiltinClassSize classSize;

  GodotApiInfo.fromJson(Map<String, dynamic> json) {
    api = GodotExtensionApiJson.fromJson(json);

    builtinClasses = {for (final e in api.builtinClasses) e.name: e};
    engineClasses = {for (final e in api.classes) e.name: e};
    nativeStructures = {for (final e in api.nativeStructures) e.name: e};
    singletons = {for (final e in api.singletons) e.name};

    for (final builtin in builtinClasses.values) {
      builtin.enums?.forEach((element) {
        var enumName = getEnumName(element.name, builtin.name);
        enumMap[enumName] = element;
      });
    }

    for (final engineClass in engineClasses.values) {
      engineClass.enums?.forEach((element) {
        var enumName = getEnumName(element.name, engineClass.name);
        enumMap[enumName] = element;
      });
    }

    for (final globalEnum in api.globalEnums) {
      enumMap[getEnumName(globalEnum.name, null)] = globalEnum;
    }

    classSize = api.builtinClassSizes
        .firstWhere((e) => e.buildConfiguration == 'float_64');

    _instance = this;
  }

  List<String> findImportForType(String type) {
    final typeCategory = getTypeCategory(type);
    final strippedType = _getStrippedType(type).item1;
    switch (typeCategory) {
      case TypeCategory.voidType:
        return [];
      case TypeCategory.primitive:
        return [];
      case TypeCategory.engineClass:
        return ['src/gen/classes/${strippedType.toSnakeCase()}.dart'];
      case TypeCategory.builtinClass:
        // Special case, included in every file
        if (strippedType.toLowerCase() == 'variant') return [];

        // Special case, array is generated as BaseArray then extended
        // as Array and TypedArray.
        if (strippedType.toLowerCase() == 'array') {
          return ['src/variant/array.dart'];
        }

        if (hasCustomImplementation(strippedType)) {
          return ['src/variant/${strippedType.toSnakeCase()}.dart'];
        } else {
          return ['src/gen/variant/${strippedType.toSnakeCase()}.dart'];
        }
      case TypeCategory.nativeStructure:
        return ['src/gen/structs/${strippedType.toSnakeCase()}.dart'];
      case TypeCategory.enumType:
      case TypeCategory.bitfieldType:
        final split = strippedType
            .replaceAll('enum::', '')
            .replaceAll('bitfield::', '')
            .split('.');
        if (split.length > 1) {
          return findImportForType(split[0]);
        }
        return [];
      case TypeCategory.typedArray:
        final innerType = strippedType.replaceAll('typedarray::', '');
        final innerImport = findImportForType(innerType);
        return ['src/variant/typed_array.dart', ...innerImport];
    }
  }

  bool isRefCounted(String godotType) {
    final strippedType = _getStrippedType(godotType);
    final engineType = engineClasses[strippedType.item1];
    return engineType?.isRefcounted ?? false;
  }

  TypeCategory getTypeCategory(String? godotType) {
    if (godotType == null) return TypeCategory.voidType;

    final strippedType = _getStrippedType(godotType);
    if (godotType.toLowerCase() == 'void' && strippedType.item2 == 0) {
      return TypeCategory.voidType;
    } else if (hasDartType(strippedType.item1)) {
      return TypeCategory.primitive;
    } else if (builtinClasses.containsKey(strippedType.item1)) {
      return TypeCategory.builtinClass;
    } else if (engineClasses.containsKey(strippedType.item1)) {
      return TypeCategory.engineClass;
    } else if (nativeStructures.containsKey(strippedType.item1)) {
      return TypeCategory.nativeStructure;
    } else if (godotType.startsWith('typedarray::')) {
      return TypeCategory.typedArray;
    } else if (godotType.startsWith('enum')) {
      return TypeCategory.enumType;
    } else if (godotType.startsWith('bitfield')) {
      return TypeCategory.bitfieldType;
    } else if (godotType == 'Variant') {
      return TypeCategory.builtinClass;
    }

    throw ArgumentError('Unknown type: `$godotType`');
  }

  String findEnumValue(String type, String value) {
    final godotEnum = enumMap[type];
    if (godotEnum == null) return value;

    List<Value> valueList;
    if (godotEnum is BuiltinClassEnum) {
      valueList = godotEnum.transformedValues();
    } else if (godotEnum is GlobalEnumElement) {
      valueList = godotEnum.transformedValues();
    } else {
      throw ArgumentError(
          'Trying to write an enum that is of type ${godotEnum.runtimeType}');
    }

    final foundValue = valueList
        .firstWhereOrNull((element) => element.value.toString() == value);
    if (foundValue != null) {
      return '$type.${foundValue.name}';
    }

    return value;
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

  final bool isOptional;
  final bool isPointer;
  final bool isRefCounted;

  final TypeCategory typeCategory;
  final ArgumentMeta? meta;

  final String? defaultArgumentValue;

  final String defaultReturnValue;

  ArgumentProxy._({
    required this.name,
    required this.type,
    required this.rawDartType,
    required this.dartType,
    required this.isOptional,
    required this.isPointer,
    required this.isRefCounted,
    required this.typeCategory,
    required this.meta,
    required this.defaultArgumentValue,
    required this.defaultReturnValue,
  });

  ArgumentProxy renamed(String newName) {
    return ArgumentProxy._(
        name: newName,
        type: type,
        rawDartType: rawDartType,
        dartType: dartType,
        isOptional: isOptional,
        isPointer: isPointer,
        isRefCounted: isRefCounted,
        typeCategory: typeCategory,
        meta: meta,
        defaultArgumentValue: defaultArgumentValue,
        defaultReturnValue: defaultReturnValue);
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
      isOptional: isOptional,
      isPointer: isPointer,
      isRefCounted: isRefCounted,
      typeCategory: typeCategory,
      meta: null,
      defaultArgumentValue: null,
      defaultReturnValue:
          _getDefaultReturnValue(singleton.type, dartType, isOptional),
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
      isOptional: isOptional,
      isPointer: isPointer,
      isRefCounted: isRefCounted,
      typeCategory: typeCategory,
      meta: argument.meta,
      defaultArgumentValue: argument.defaultValue,
      defaultReturnValue:
          _getDefaultReturnValue(argument.type, dartType, isOptional),
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
      name: 'ret',
      type: returnValue.type,
      rawDartType: godotTypeToRawDartType(returnValue.type),
      dartType: dartType,
      isOptional: isOptional,
      isPointer: isPointer,
      isRefCounted: isRefCounted,
      typeCategory: typeCategory,
      meta: returnValue.meta,
      defaultArgumentValue: null,
      defaultReturnValue:
          _getDefaultReturnValue(returnValue.type, dartType, isOptional),
    );
  }

  factory ArgumentProxy.fromReturnType(ReturnType? returnType) {
    if (returnType == null) return ArgumentProxy.fromTypeName('void');

    final typeName = returnTypeValues.reverse[returnType]!;
    final dartType = godotTypeToDartType(typeName);
    final typeCategory = GodotApiInfo.instance().getTypeCategory(typeName);
    final isRefCounted = typeCategory == TypeCategory.engineClass &&
        GodotApiInfo.instance().isRefCounted(typeName);
    final isOptional = typeCategory == TypeCategory.engineClass;
    return ArgumentProxy._(
      name: 'ret',
      type: typeName,
      rawDartType: godotTypeToRawDartType(typeName),
      dartType: dartType,
      isOptional: isOptional,
      isPointer: false,
      isRefCounted: isRefCounted,
      typeCategory: typeCategory,
      meta: null,
      defaultArgumentValue: null,
      defaultReturnValue:
          _getDefaultReturnValue(typeName, dartType, isOptional),
    );
  }

  factory ArgumentProxy.fromTypeName(String? typeName) {
    final dartType = godotTypeToDartType(typeName);
    final isPointer = typeName?.endsWith('*') ?? false;
    final typeCategory = GodotApiInfo.instance().getTypeCategory(typeName);
    final isRefCounted = typeName != null &&
        !isPointer &&
        typeCategory == TypeCategory.engineClass &&
        GodotApiInfo.instance().isRefCounted(typeName);
    final isOptional = !isPointer && typeCategory == TypeCategory.engineClass;
    return ArgumentProxy._(
      name: 'ret',
      type: typeName ?? '',
      rawDartType: godotTypeToRawDartType(typeName),
      dartType: dartType,
      isOptional: isOptional,
      isPointer: isPointer,
      isRefCounted: isRefCounted,
      typeCategory: typeCategory,
      meta: null,
      defaultArgumentValue: null,
      defaultReturnValue: typeName != null
          ? _getDefaultReturnValue(typeName, dartType, isOptional)
          : '',
    );
  }

  static String _getDefaultReturnValue(
      String godotType, String dartType, bool isOptional) {
    final myDartType = dartType;
    if (isOptional) {
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

  bool get needsAllocation {
    return typeCategory == TypeCategory.primitive ||
        typeCategory == TypeCategory.bitfieldType ||
        typeCategory == TypeCategory.enumType ||
        typeCategory == TypeCategory.nativeStructure;
  }

  String get typeInfo {
    switch (typeCategory) {
      case TypeCategory.builtinClass:
        if (rawDartType == 'String') {
          return 'GDString.sTypeInfo';
        } else {
          return '$rawDartType.sTypeInfo';
        }
      case TypeCategory.typedArray:
        return 'TypedArray.sTypeInfo';
      case TypeCategory.engineClass:
      case TypeCategory.enumType:
        return '$rawDartType.sTypeInfo';
      case TypeCategory.nativeStructure:
        return 's${rawDartType}TypeInfo';
      case TypeCategory.primitive:
        if (isPointer) {
          return 'PrimitiveTypeInfo.forType(Pointer<Void>)!';
        } else {
          return 'PrimitiveTypeInfo.forType($dartType)!';
        }
      case TypeCategory.bitfieldType:
        return 'PrimitiveTypeInfo.forType(Int32)!';
      default:
        return 'unknown';
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
