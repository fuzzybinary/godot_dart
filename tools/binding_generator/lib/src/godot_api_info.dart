import 'string_extensions.dart';
import 'type_helpers.dart';

class GodotApiInfo {
  Map<String, dynamic> raw = <String, dynamic>{};

  Map<String, Map<String, dynamic>> builtinClasses = {};
  Map<String, Map<String, dynamic>> engineClasses = {};
  Set<String> singletons = {};
  Map<String, Map<String, dynamic>> nativeStructures = {};

  GodotApiInfo.fromJson(Map<String, dynamic> api) {
    raw = api;

    for (Map<String, dynamic> builtin in api['builtin_classes']) {
      final String name = builtin['name'];
      builtinClasses[name] = builtin;
    }

    for (Map<String, dynamic> engine in api['classes']) {
      final String name = engine['name'];
      engineClasses[name] = engine;
    }

    for (Map<String, dynamic> singleton in api['singletons']) {
      final String name = singleton['name'];
      singletons.add(name);
    }

    for (Map<String, dynamic> nativeStructure in api['native_structures']) {
      // TODO: These probably need special processing
      final String name = nativeStructure['name'];
      nativeStructures[name] = nativeStructure;
    }
  }
}

TypeCategory _getTypeCategory(GodotApiInfo api, String type) {
  bool isPointer = false;
  String trimmedType = type.replaceFirst('const ', '');
  while (trimmedType.endsWith('*')) {
    trimmedType = trimmedType.substring(0, trimmedType.length - 1);
    isPointer = true;
  }
  trimmedType = trimmedType.trim();

  if (trimmedType == 'void' && !isPointer) {
    return TypeCategory.voidType;
  } else if (trimmedType.startsWith('enum::') ||
      trimmedType.startsWith('bitfield::')) {
    return TypeCategory.enumType;
  } else if (trimmedType.startsWith('typedarray::')) {
    return TypeCategory.typedArray;
  } else if (hasDartType(trimmedType)) {
    return TypeCategory.primitive;
  } else if (api.engineClasses.containsKey(trimmedType)) {
    return TypeCategory.engineClass;
  } else if (api.builtinClasses.containsKey(trimmedType) ||
      trimmedType == 'Variant') {
    return TypeCategory.builtinClass;
  } else if (api.nativeStructures.containsKey(trimmedType)) {
    return TypeCategory.nativeStructure;
  } else if (trimmedType.startsWith('enum::') ||
      trimmedType.startsWith('bitfield::')) {
    // TODO:
    return TypeCategory.voidType;
  } else if (trimmedType.startsWith('typedarray::')) {
    // TODO:
    return TypeCategory.voidType;
  }

  //assert(false);

  return TypeCategory.voidType;
}

enum TypeCategory {
  voidType,
  primitive,
  engineClass,
  builtinClass,
  nativeStructure,
  enumType,
  typedArray,
}

class TypeInfo {
  late bool isOptional;
  late TypeCategory typeCategory;
  late String dartType;
  late String godotType;
  bool isPointer = false;

  late String? rawName;
  late String? name;
  late String? meta;

  // Type including optional
  String get fullType => '$dartType${isOptional ? '?' : ''}';

  bool get needsAllocation {
    return dartTypes.contains(godotType);
  }

  static String? getPointerType(GodotApiInfo api, String type) {
    int pointerCount = 0;
    var dartType = type;
    while (dartType.endsWith('*')) {
      pointerCount++;
      dartType = dartType.substring(0, dartType.length - 1);
    }
    dartType = dartType.trim();

    final ffiType = api.nativeStructures.containsKey(dartType)
        ? dartType
        : getFFITypeFromString(dartType);
    if (ffiType != null) {
      dartType = 'Pointer<' * pointerCount;
      dartType += ffiType;
      dartType += '>' * pointerCount;
    } else {
      return null;
    }
    return dartType;
  }

  // Simple types, used by members
  TypeInfo.forType(GodotApiInfo api, String type) {
    godotType = type;
    meta = null;
    isOptional = false;

    typeCategory = _getTypeCategory(api, type);
    isOptional = typeCategory == TypeCategory.engineClass;

    dartType = godotType.replaceFirst('const ', '');
    if (dartType.endsWith('*')) {
      final pointerType = getPointerType(api, dartType);
      if (pointerType != null) {
        dartType = pointerType;
        isPointer = true;
      } else {
        isOptional = true;
        dartType = dartType.substring(0, dartType.length - 1);
      }
    }

    // Handle typed arrays?
    dartType = getCorrectedType(dartType, meta: meta);

    rawName = 'value';
    name = 'value';
  }

  TypeInfo.fromArgument(GodotApiInfo api, Map<String, dynamic> argument) {
    godotType = argument['type'];
    meta = argument['meta'];
    isOptional = false;

    typeCategory = _getTypeCategory(api, godotType);
    isOptional = typeCategory == TypeCategory.engineClass;

    dartType = godotType.replaceFirst('const ', '');
    if (dartType.endsWith('*')) {
      final pointerType = getPointerType(api, dartType);
      if (pointerType != null) {
        dartType = pointerType;
        isPointer = true;
      } else {
        isOptional = true;
        dartType = dartType.substring(0, dartType.length - 1);
      }
    }

    // Handle typed arrays?
    dartType = getCorrectedType(dartType, meta: meta);

    rawName = argument['name'];
    name = escapeName(rawName!.toLowerCamelCase());
  }

  TypeInfo.forReturnType(GodotApiInfo api, Map<String, dynamic> method) {
    isOptional = false;
    meta = null;
    if (method.containsKey('return_type')) {
      godotType = method['return_type'];
    } else if (method.containsKey('return_value')) {
      final returnValue = method['return_value'] as Map<String, dynamic>;
      godotType = returnValue['type'];
      if (returnValue.containsKey('meta')) {
        meta = method['return_value']['meta'];
      }
    } else {
      godotType = 'Void';
    }

    if (godotType == 'Void') {
      dartType = 'void';
      typeCategory = TypeCategory.voidType;
    } else {
      typeCategory = _getTypeCategory(api, godotType);
      isOptional = typeCategory == TypeCategory.engineClass;

      dartType = getCorrectedType(godotType, meta: meta);
      if (godotType == 'String') {
        dartType = 'String';
      }

      if (dartType.startsWith('const')) {
        dartType = dartType.replaceFirst('const ', '');
      }

      if (dartType.endsWith('*')) {
        final pointerType = getPointerType(api, dartType);
        if (pointerType != null) {
          dartType = pointerType;
          isPointer = true;
        } else {
          isOptional = true;
          dartType = dartType.substring(0, dartType.length - 1);
        }
      }
    }
  }
}
