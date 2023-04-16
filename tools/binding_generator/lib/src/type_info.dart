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

class TypeInfo {
  final TypeCategory typeCategory;
  late final String dartType;
  final String godotType;
  late final String? typeMeta;

  final Map<String, dynamic> api;

  TypeInfo({
    required this.typeCategory,
    required this.godotType,
    required this.api,
  }) {
    typeMeta = api['meta'] as String?;
    dartType = getCorrectedType(godotType, meta: typeMeta);
  }

  factory TypeInfo.voidType() {
    return TypeInfo(
      typeCategory: TypeCategory.voidType,
      godotType: 'void',
      api: <String, dynamic>{},
    );
  }

  factory TypeInfo.primitiveType(String type) {
    return TypeInfo(
      typeCategory: TypeCategory.primitive,
      godotType: type,
      api: <String, dynamic>{},
    );
  }
}

class ArgumentInfo {
  final String godotType;
  final bool isOptional;
  final String? pointerType;
  final ArgumentMeta? meta;

  final String? rawName;
  late final String? name;

  // String get fullDartType => '$dartType${isOptional ? '?' : ''}';

  // bool get isPointer => pointerType != null;
  // String get dartType {
  //   if (isPointer) {
  //     return pointerType!;
  //   } else if (name == null && typeInfo.dartType == 'GDString') {
  //     // HACK: no name means return type. Need to make this work for all parameters, not just returns.
  //     return 'String';
  //   }
  //   return typeInfo.dartType;
  // }

  bool get needsAllocation {
    return dartTypes.contains(godotType);
  }

  ArgumentInfo({
    required this.godotType,
    required this.isOptional,
    required this.pointerType,
    required this.rawName,
    required this.meta,
  }) {
    name = rawName != null ? escapeName(rawName!) : null;
  }
}
