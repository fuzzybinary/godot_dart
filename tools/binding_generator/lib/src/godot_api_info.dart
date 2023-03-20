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

class TypeInfo {
  late bool isVoid;
  late bool isOptional;
  late bool isEngineClass;
  late bool isBuiltinClass;
  late String dartType;
  late String godotType;

  late String? rawName;
  late String? name;
  late String? meta;

  // Type including optional
  String get fullType => '$dartType${isOptional ? '?' : ''}';

  static String? getPointerType(String type) {
    int pointerCount = 0;
    var dartType = type;
    while (dartType.endsWith('*')) {
      pointerCount++;
      dartType = dartType.substring(0, dartType.length - 1);
    }
    dartType = dartType.trim();

    final ffiType = getFFITypeFromString(dartType);
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
    isVoid = false;
    godotType = type;
    meta = null;
    isOptional = false;

    isEngineClass = api.engineClasses.containsKey(godotType);
    isBuiltinClass = api.builtinClasses.containsKey(godotType);
    isOptional = isEngineClass;

    dartType = godotType.replaceFirst('const ', '');
    if (dartType.endsWith('*')) {
      final pointerType = getPointerType(dartType);
      if (pointerType != null) {
        dartType = pointerType;
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
    isVoid = false;
    godotType = argument['type'];
    meta = argument['meta'];
    isOptional = false;

    isEngineClass = api.engineClasses.containsKey(godotType);
    isBuiltinClass = api.builtinClasses.containsKey(godotType);
    isOptional = isEngineClass;

    dartType = godotType.replaceFirst('const ', '');
    if (dartType.endsWith('*')) {
      final pointerType = getPointerType(dartType);
      if (pointerType != null) {
        dartType = pointerType;
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
    isVoid = false;
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
      isVoid = true;
    }

    if (godotType == 'Void') {
      dartType = 'void';
    } else {
      isEngineClass = api.engineClasses.containsKey(godotType);
      isBuiltinClass = api.builtinClasses.containsKey(godotType);
      isOptional = isEngineClass;

      dartType = getCorrectedType(godotType, meta: meta);
      if (godotType == 'String') {
        dartType = 'String';
      }

      if (dartType.startsWith('const')) {
        dartType = dartType.replaceFirst('const ', '');
      }

      if (dartType.endsWith('*')) {
        final pointerType = getPointerType(dartType);
        if (pointerType != null) {
          dartType = pointerType;
        } else {
          isOptional = true;
          dartType = dartType.substring(0, dartType.length - 1);
        }
      }
    }
  }
}
