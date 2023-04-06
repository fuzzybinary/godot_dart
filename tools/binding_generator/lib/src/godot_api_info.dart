import 'package:tuple/tuple.dart';

import 'type_helpers.dart';
import 'type_info.dart';

class GodotApiInfo {
  Map<String, dynamic> raw = <String, dynamic>{};

  Set<String> singletons = {};

  Map<String, TypeInfo> builtinClasses = {};
  Map<String, TypeInfo> engineClasses = {};
  Map<String, TypeInfo> nativeStructures = {};

  GodotApiInfo.fromJson(Map<String, dynamic> api) {
    raw = api;

    for (Map<String, dynamic> builtin in api['builtin_classes']) {
      final String name = builtin['name'];
      if (hasDartType(name)) continue;
      builtinClasses[name] = TypeInfo(
        typeCategory: TypeCategory.builtinClass,
        godotType: name,
        api: builtin,
      );
    }

    for (Map<String, dynamic> engine in api['classes']) {
      final String name = engine['name'];
      engineClasses[name] = TypeInfo(
        typeCategory: TypeCategory.engineClass,
        godotType: name,
        api: engine,
      );
    }

    for (Map<String, dynamic> singleton in api['singletons']) {
      final String name = singleton['name'];
      singletons.add(name);
    }

    for (Map<String, dynamic> nativeStructure in api['native_structures']) {
      // TODO: These probably need special processing
      final String name = nativeStructure['name'];
      nativeStructures[name] = TypeInfo(
        typeCategory: TypeCategory.nativeStructure,
        godotType: name,
        api: nativeStructure,
      );
    }
  }

  ArgumentInfo getArgumentInfo(Map<String, dynamic> argument) {
    final rawType = argument['type'] as String;
    final meta = argument['meta'] as String?;
    final strippedType = _getStrippedType(rawType);

    final typeInfo = _findTypeInfo(strippedType.item1, strippedType.item2 > 0);
    final pointerType = _getPointerType(rawType);

    return ArgumentInfo(
      typeInfo: typeInfo,
      isOptional: pointerType == null &&
          typeInfo.typeCategory == TypeCategory.engineClass,
      pointerType: pointerType,
      rawName: argument['name'],
      meta: meta,
    );
  }

  ArgumentInfo getReturnInfo(Map<String, dynamic> methodData) {
    String? meta;
    String rawType;
    if (methodData.containsKey('return_type')) {
      rawType = methodData['return_type'];
    } else if (methodData.containsKey('return_value')) {
      final returnValue = methodData['return_value'] as Map<String, dynamic>;
      rawType = returnValue['type'] ?? 'Void';
      if (returnValue.containsKey('meta')) {
        meta = methodData['return_value']['meta'];
      }
    } else {
      rawType = 'Void';
    }

    final strippedType = _getStrippedType(rawType);

    final typeInfo = _findTypeInfo(strippedType.item1, strippedType.item2 > 0);
    final pointerType = _getPointerType(rawType);

    return ArgumentInfo(
      typeInfo: typeInfo,
      isOptional: pointerType == null &&
          typeInfo.typeCategory == TypeCategory.engineClass,
      pointerType: pointerType,
      rawName: null,
      meta: meta,
    );
  }

  ArgumentInfo getMemberInfo(Map<String, dynamic> member) {
    final rawType = member['type'] as String;
    final meta = member['meta'] as String?;
    final strippedType = _getStrippedType(rawType);

    final typeInfo = _findTypeInfo(strippedType.item1, strippedType.item2 > 0);
    final pointerType = _getPointerType(rawType);

    return ArgumentInfo(
      typeInfo: typeInfo,
      isOptional: pointerType == null && strippedType.item2 > 0,
      pointerType: pointerType,
      rawName: member['name'],
      meta: meta,
    );
  }

  // Stripped type with the number of pointers
  static Tuple2<String, int> _getStrippedType(String rawGodotType) {
    int pointerCount = 0;
    var strippedType = rawGodotType.replaceFirst('const ', '');
    while (strippedType.endsWith('*')) {
      pointerCount++;
      strippedType = strippedType.substring(0, strippedType.length - 1);
    }
    strippedType = strippedType.trim();

    return Tuple2(strippedType, pointerCount);
  }

  TypeInfo _findTypeInfo(String type, bool isPointer) {
    var typeInfo =
        builtinClasses[type] ?? engineClasses[type] ?? nativeStructures[type];
    if (typeInfo == null) {
      if (type == 'Void' && !isPointer) {
        typeInfo = TypeInfo.voidType();
      } else if (type.startsWith('enum::') || type.startsWith('bitfield::')) {
        typeInfo = TypeInfo(
          typeCategory: TypeCategory.enumType,
          godotType: type,
          api: <String, dynamic>{},
        );
      } else if (type.startsWith('typedarray::')) {
        typeInfo = TypeInfo(
          typeCategory: TypeCategory.typedArray,
          godotType: type,
          api: <String, dynamic>{},
        );
      } else if (hasDartType(type)) {
        typeInfo = TypeInfo.primitiveType(type);
      } else if (type == 'Variant') {
        return TypeInfo(
          typeCategory: TypeCategory.builtinClass,
          godotType: 'Variant',
          api: <String, dynamic>{},
        );
      }
    }

    return typeInfo!;
  }

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
