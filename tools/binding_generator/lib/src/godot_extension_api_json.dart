// To parse this JSON data, do
//
//     final godotExtensionApiJson = godotExtensionApiJsonFromJson(jsonString);

import 'dart:convert';

class GodotExtensionApiJson {
  GodotExtensionApiJson({
    required this.header,
    required this.builtinClassSizes,
    required this.builtinClassMemberOffsets,
    required this.globalConstants,
    required this.globalEnums,
    required this.utilityFunctions,
    required this.builtinClasses,
    required this.classes,
    required this.singletons,
    required this.nativeStructures,
  });

  Header header;
  List<BuiltinClassSize> builtinClassSizes;
  List<BuiltinClassMemberOffset> builtinClassMemberOffsets;
  List<dynamic> globalConstants;
  List<GlobalEnumElement> globalEnums;
  List<UtilityFunction> utilityFunctions;
  List<BuiltinClass> builtinClasses;
  List<GodotExtensionApiJsonClass> classes;
  List<Singleton> singletons;
  List<NativeStructure> nativeStructures;

  factory GodotExtensionApiJson.fromRawJson(String str) =>
      GodotExtensionApiJson.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory GodotExtensionApiJson.fromJson(Map<String, dynamic> json) =>
      GodotExtensionApiJson(
        header: Header.fromJson(json['header']),
        builtinClassSizes: List<BuiltinClassSize>.from(
            json['builtin_class_sizes']
                .map((dynamic x) => BuiltinClassSize.fromJson(x))),
        builtinClassMemberOffsets: List<BuiltinClassMemberOffset>.from(
            json['builtin_class_member_offsets']
                .map((dynamic x) => BuiltinClassMemberOffset.fromJson(x))),
        globalConstants: List<dynamic>.from(
            json['global_constants'].map<dynamic>((dynamic x) => x)),
        globalEnums: List<GlobalEnumElement>.from(json['global_enums']
            .map((dynamic x) => GlobalEnumElement.fromJson(x))),
        utilityFunctions: List<UtilityFunction>.from(json['utility_functions']
            .map((dynamic x) => UtilityFunction.fromJson(x))),
        builtinClasses: List<BuiltinClass>.from(json['builtin_classes']
            .map((dynamic x) => BuiltinClass.fromJson(x))),
        classes: List<GodotExtensionApiJsonClass>.from(json['classes']
            .map((dynamic x) => GodotExtensionApiJsonClass.fromJson(x))),
        singletons: List<Singleton>.from(
            json['singletons'].map((dynamic x) => Singleton.fromJson(x))),
        nativeStructures: List<NativeStructure>.from(json['native_structures']
            .map((dynamic x) => NativeStructure.fromJson(x))),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'header': header.toJson(),
        'builtin_class_sizes': List<dynamic>.from(
            builtinClassSizes.map<dynamic>((dynamic x) => x.toJson())),
        'builtin_class_member_offsets': List<dynamic>.from(
            builtinClassMemberOffsets.map<dynamic>((dynamic x) => x.toJson())),
        'global_constants':
            List<dynamic>.from(globalConstants.map<dynamic>((dynamic x) => x)),
        'global_enums': List<dynamic>.from(
            globalEnums.map<dynamic>((dynamic x) => x.toJson())),
        'utility_functions': List<dynamic>.from(
            utilityFunctions.map<dynamic>((dynamic x) => x.toJson())),
        'builtin_classes': List<dynamic>.from(
            builtinClasses.map<dynamic>((dynamic x) => x.toJson())),
        'classes':
            List<dynamic>.from(classes.map<dynamic>((dynamic x) => x.toJson())),
        'singletons': List<dynamic>.from(
            singletons.map<dynamic>((dynamic x) => x.toJson())),
        'native_structures': List<dynamic>.from(
            nativeStructures.map<dynamic>((dynamic x) => x.toJson())),
      };
}

class BuiltinClassMemberOffset {
  BuiltinClassMemberOffset({
    required this.buildConfiguration,
    required this.classes,
  });

  String buildConfiguration;
  List<BuiltinClassMemberOffsetClass> classes;

  factory BuiltinClassMemberOffset.fromRawJson(String str) =>
      BuiltinClassMemberOffset.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory BuiltinClassMemberOffset.fromJson(Map<String, dynamic> json) =>
      BuiltinClassMemberOffset(
        buildConfiguration: json['build_configuration'],
        classes: List<BuiltinClassMemberOffsetClass>.from(json['classes']
            .map((dynamic x) => BuiltinClassMemberOffsetClass.fromJson(x))),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'build_configuration': buildConfiguration,
        'classes':
            List<dynamic>.from(classes.map<dynamic>((dynamic x) => x.toJson())),
      };
}

class BuiltinClassMemberOffsetClass {
  BuiltinClassMemberOffsetClass({
    required this.name,
    required this.members,
  });

  TypeEnum name;
  List<Member> members;

  factory BuiltinClassMemberOffsetClass.fromRawJson(String str) =>
      BuiltinClassMemberOffsetClass.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory BuiltinClassMemberOffsetClass.fromJson(Map<String, dynamic> json) =>
      BuiltinClassMemberOffsetClass(
        name: typeEnumValues.map[json['name']]!,
        members: List<Member>.from(
            json['members'].map((dynamic x) => Member.fromJson(x))),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': typeEnumValues.reverse[name],
        'members':
            List<dynamic>.from(members.map<dynamic>((dynamic x) => x.toJson())),
      };
}

class Member {
  Member({
    required this.member,
    required this.offset,
    required this.meta,
  });

  String member;
  int offset;
  MemberMeta meta;

  factory Member.fromRawJson(String str) => Member.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Member.fromJson(Map<String, dynamic> json) => Member(
        member: json['member'],
        offset: json['offset'],
        meta: memberMetaValues.map[json['meta']]!,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'member': member,
        'offset': offset,
        'meta': memberMetaValues.reverse[meta],
      };
}

enum MemberMeta {
  float,
  int32,
  vector2,
  vector2I,
  vector3,
  basis,
  vector4,
  double
}

final memberMetaValues = EnumValues({
  'Basis': MemberMeta.basis,
  'double': MemberMeta.double,
  'float': MemberMeta.float,
  'int32': MemberMeta.int32,
  'Vector2': MemberMeta.vector2,
  'Vector2i': MemberMeta.vector2I,
  'Vector3': MemberMeta.vector3,
  'Vector4': MemberMeta.vector4
});

enum TypeEnum {
  int,
  vector2,
  vector2I,
  vector3,
  vector3I,
  transform2D,
  vector4,
  vector4I,
  plane,
  quaternion,
  basis,
  transform3D,
  projection,
  color,
  rect2,
  rect2I,
  aabb
}

final typeEnumValues = EnumValues({
  'AABB': TypeEnum.aabb,
  'Basis': TypeEnum.basis,
  'Color': TypeEnum.color,
  'int': TypeEnum.int,
  'Plane': TypeEnum.plane,
  'Projection': TypeEnum.projection,
  'Quaternion': TypeEnum.quaternion,
  'Rect2': TypeEnum.rect2,
  'Rect2i': TypeEnum.rect2I,
  'Transform2D': TypeEnum.transform2D,
  'Transform3D': TypeEnum.transform3D,
  'Vector2': TypeEnum.vector2,
  'Vector2i': TypeEnum.vector2I,
  'Vector3': TypeEnum.vector3,
  'Vector3i': TypeEnum.vector3I,
  'Vector4': TypeEnum.vector4,
  'Vector4i': TypeEnum.vector4I
});

class BuiltinClassSize {
  BuiltinClassSize({
    required this.buildConfiguration,
    required this.sizes,
  });

  String buildConfiguration;
  List<Size> sizes;

  factory BuiltinClassSize.fromRawJson(String str) =>
      BuiltinClassSize.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory BuiltinClassSize.fromJson(Map<String, dynamic> json) =>
      BuiltinClassSize(
        buildConfiguration: json['build_configuration'],
        sizes:
            List<Size>.from(json['sizes'].map((dynamic x) => Size.fromJson(x))),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'build_configuration': buildConfiguration,
        'sizes':
            List<dynamic>.from(sizes.map<dynamic>((dynamic x) => x.toJson())),
      };
}

class Size {
  Size({
    required this.name,
    required this.size,
  });

  String name;
  int size;

  factory Size.fromRawJson(String str) => Size.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Size.fromJson(Map<String, dynamic> json) => Size(
        name: json['name'],
        size: json['size'],
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'size': size,
      };
}

class BuiltinClass {
  BuiltinClass({
    required this.name,
    required this.isKeyed,
    required this.operators,
    required this.constructors,
    required this.hasDestructor,
    this.indexingReturnType,
    this.methods,
    this.members,
    this.constants,
    this.enums,
  });

  String name;
  bool isKeyed;
  List<Operator> operators;
  List<Constructor> constructors;
  bool hasDestructor;
  String? indexingReturnType;
  List<BuiltinClassMethod>? methods;
  List<Singleton>? members;
  List<Constant>? constants;
  List<BuiltinClassEnum>? enums;

  factory BuiltinClass.fromRawJson(String str) =>
      BuiltinClass.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory BuiltinClass.fromJson(Map<String, dynamic> json) => BuiltinClass(
        name: json['name'],
        isKeyed: json['is_keyed'],
        operators: List<Operator>.from(
            json['operators'].map((dynamic x) => Operator.fromJson(x))),
        constructors: List<Constructor>.from(
            json['constructors'].map((dynamic x) => Constructor.fromJson(x))),
        hasDestructor: json['has_destructor'],
        indexingReturnType: json['indexing_return_type'],
        methods: json['methods'] == null
            ? []
            : List<BuiltinClassMethod>.from(json['methods']!
                .map((dynamic x) => BuiltinClassMethod.fromJson(x))),
        members: json['members'] == null
            ? []
            : List<Singleton>.from(
                json['members']!.map((dynamic x) => Singleton.fromJson(x))),
        constants: json['constants'] == null
            ? []
            : List<Constant>.from(
                json['constants']!.map((dynamic x) => Constant.fromJson(x))),
        enums: json['enums'] == null
            ? []
            : List<BuiltinClassEnum>.from(json['enums']!
                .map((dynamic x) => BuiltinClassEnum.fromJson(x))),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'is_keyed': isKeyed,
        'operators': List<dynamic>.from(
            operators.map<dynamic>((dynamic x) => x.toJson())),
        'constructors': List<dynamic>.from(
            constructors.map<dynamic>((dynamic x) => x.toJson())),
        'has_destructor': hasDestructor,
        'indexing_return_type': indexingReturnType,
        'methods': methods == null
            ? <dynamic>[]
            : List<dynamic>.from(
                methods!.map<dynamic>((dynamic x) => x.toJson())),
        'members': members == null
            ? <dynamic>[]
            : List<dynamic>.from(
                members!.map<dynamic>((dynamic x) => x.toJson())),
        'constants': constants == null
            ? <dynamic>[]
            : List<dynamic>.from(
                constants!.map<dynamic>((dynamic x) => x.toJson())),
        'enums': enums == null
            ? <dynamic>[]
            : List<dynamic>.from(
                enums!.map<dynamic>((dynamic x) => x.toJson())),
      };
}

class Constant {
  Constant({
    required this.name,
    required this.type,
    required this.value,
  });

  String name;
  TypeEnum type;
  String value;

  factory Constant.fromRawJson(String str) =>
      Constant.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Constant.fromJson(Map<String, dynamic> json) => Constant(
        name: json['name'],
        type: typeEnumValues.map[json['type']]!,
        value: json['value'],
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'type': typeEnumValues.reverse[type],
        'value': value,
      };
}

class Constructor {
  Constructor({
    required this.index,
    this.arguments,
  });

  int index;
  List<Singleton>? arguments;

  factory Constructor.fromRawJson(String str) =>
      Constructor.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Constructor.fromJson(Map<String, dynamic> json) => Constructor(
        index: json['index'],
        arguments: json['arguments'] == null
            ? []
            : List<Singleton>.from(
                json['arguments']!.map((dynamic x) => Singleton.fromJson(x))),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'index': index,
        'arguments': arguments == null
            ? <dynamic>[]
            : List<dynamic>.from(
                arguments!.map<dynamic>((dynamic x) => x.toJson())),
      };
}

class Singleton {
  Singleton({
    required this.name,
    required this.type,
  });

  String name;
  String type;

  factory Singleton.fromRawJson(String str) =>
      Singleton.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Singleton.fromJson(Map<String, dynamic> json) => Singleton(
        name: json['name'],
        type: json['type'],
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'type': type,
      };
}

class BuiltinClassEnum {
  BuiltinClassEnum({
    required this.name,
    required this.values,
  });

  String name;
  List<Value> values;

  factory BuiltinClassEnum.fromRawJson(String str) =>
      BuiltinClassEnum.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory BuiltinClassEnum.fromJson(Map<String, dynamic> json) =>
      BuiltinClassEnum(
        name: json['name'],
        values: List<Value>.from(
            json['values'].map((dynamic x) => Value.fromJson(x))),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'values':
            List<dynamic>.from(values.map<dynamic>((dynamic x) => x.toJson())),
      };
}

class Value {
  Value({
    required this.name,
    required this.value,
  });

  String name;
  int value;

  factory Value.fromRawJson(String str) => Value.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Value.fromJson(Map<String, dynamic> json) => Value(
        name: json['name'],
        value: json['value'],
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'value': value,
      };
}

class BuiltinClassMethod {
  BuiltinClassMethod({
    required this.name,
    this.returnType,
    required this.isVararg,
    required this.isConst,
    required this.isStatic,
    required this.hash,
    this.arguments,
  });

  String name;
  String? returnType;
  bool isVararg;
  bool isConst;
  bool isStatic;
  int hash;
  List<Argument>? arguments;

  factory BuiltinClassMethod.fromRawJson(String str) =>
      BuiltinClassMethod.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory BuiltinClassMethod.fromJson(Map<String, dynamic> json) =>
      BuiltinClassMethod(
        name: json['name'],
        returnType: json['return_type'],
        isVararg: json['is_vararg'],
        isConst: json['is_const'],
        isStatic: json['is_static'],
        hash: json['hash'],
        arguments: json['arguments'] == null
            ? []
            : List<Argument>.from(
                json['arguments']!.map((dynamic x) => Argument.fromJson(x))),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'return_type': returnType,
        'is_vararg': isVararg,
        'is_const': isConst,
        'is_static': isStatic,
        'hash': hash,
        'arguments': arguments == null
            ? <dynamic>[]
            : List<dynamic>.from(
                arguments!.map<dynamic>((dynamic x) => x.toJson())),
      };
}

class Argument {
  Argument({
    required this.name,
    required this.type,
    this.defaultValue,
    this.meta,
  });

  String name;
  String type;
  String? defaultValue;
  ArgumentMeta? meta;

  factory Argument.fromRawJson(String str) =>
      Argument.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Argument.fromJson(Map<String, dynamic> json) => Argument(
        name: json['name'],
        type: json['type'],
        defaultValue: json['default_value'],
        meta: argumentMetaValues.map[json['meta']],
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'type': type,
        'default_value': defaultValue,
        'meta': argumentMetaValues.reverse[meta],
      };
}

enum ArgumentMeta {
  int64,
  float,
  int32,
  double,
  uint32,
  uint8,
  uint16,
  uint64,
  int8,
  int16
}

final argumentMetaValues = EnumValues({
  'double': ArgumentMeta.double,
  'float': ArgumentMeta.float,
  'int16': ArgumentMeta.int16,
  'int32': ArgumentMeta.int32,
  'int64': ArgumentMeta.int64,
  'int8': ArgumentMeta.int8,
  'uint16': ArgumentMeta.uint16,
  'uint32': ArgumentMeta.uint32,
  'uint64': ArgumentMeta.uint64,
  'uint8': ArgumentMeta.uint8
});

class Operator {
  Operator({
    required this.name,
    this.rightType,
    required this.returnType,
  });

  OperatorName name;
  String? rightType;
  String returnType;

  factory Operator.fromRawJson(String str) =>
      Operator.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Operator.fromJson(Map<String, dynamic> json) => Operator(
        name: operatorNameValues.map[json['name']]!,
        rightType: json['right_type'],
        returnType: json['return_type'],
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': operatorNameValues.reverse[name],
        'right_type': rightType,
        'return_type': returnType,
      };
}

enum OperatorName {
  empty,
  name,
  or,
  not,
  and,
  xor,
  ins,
  purple,
  fluffy,
  unary,
  nameUnary,
  tentacled,
  sticky,
  indigo,
  indecent,
  hilarious,
  ambitious,
  cunning,
  magenta,
  frisky,
  mischievous,
  braggadocious,
  the1,
  the2,
  the3
}

final operatorNameValues = EnumValues({
  '*': OperatorName.ambitious,
  'and': OperatorName.and,
  '>>': OperatorName.braggadocious,
  '/': OperatorName.cunning,
  '==': OperatorName.empty,
  '>': OperatorName.fluffy,
  '**': OperatorName.frisky,
  '-': OperatorName.hilarious,
  'in': OperatorName.ins,
  '+': OperatorName.indecent,
  '>=': OperatorName.indigo,
  '%': OperatorName.magenta,
  '<<': OperatorName.mischievous,
  '!=': OperatorName.name,
  'unary+': OperatorName.nameUnary,
  'not': OperatorName.not,
  'or': OperatorName.or,
  '<': OperatorName.purple,
  '<=': OperatorName.sticky,
  '~': OperatorName.tentacled,
  '&': OperatorName.the1,
  '|': OperatorName.the2,
  '^': OperatorName.the3,
  'unary-': OperatorName.unary,
  'xor': OperatorName.xor
});

class GodotExtensionApiJsonClass {
  GodotExtensionApiJsonClass({
    required this.name,
    required this.isRefcounted,
    required this.isInstantiable,
    this.inherits,
    required this.apiType,
    this.enums,
    this.methods,
    this.properties,
    this.signals,
    this.constants,
  });

  String name;
  bool isRefcounted;
  bool isInstantiable;
  String? inherits;
  ApiType apiType;
  List<GlobalEnumElement>? enums;
  List<ClassMethod>? methods;
  List<Property>? properties;
  List<Signal>? signals;
  List<Value>? constants;

  factory GodotExtensionApiJsonClass.fromRawJson(String str) =>
      GodotExtensionApiJsonClass.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory GodotExtensionApiJsonClass.fromJson(Map<String, dynamic> json) =>
      GodotExtensionApiJsonClass(
        name: json['name'],
        isRefcounted: json['is_refcounted'],
        isInstantiable: json['is_instantiable'],
        inherits: json['inherits'],
        apiType: apiTypeValues.map[json['api_type']]!,
        enums: json['enums'] == null
            ? []
            : List<GlobalEnumElement>.from(json['enums']!
                .map((dynamic x) => GlobalEnumElement.fromJson(x))),
        methods: json['methods'] == null
            ? []
            : List<ClassMethod>.from(
                json['methods']!.map((dynamic x) => ClassMethod.fromJson(x))),
        properties: json['properties'] == null
            ? []
            : List<Property>.from(
                json['properties']!.map((dynamic x) => Property.fromJson(x))),
        signals: json['signals'] == null
            ? []
            : List<Signal>.from(
                json['signals']!.map((dynamic x) => Signal.fromJson(x))),
        constants: json['constants'] == null
            ? []
            : List<Value>.from(
                json['constants']!.map((dynamic x) => Value.fromJson(x))),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'is_refcounted': isRefcounted,
        'is_instantiable': isInstantiable,
        'inherits': inherits,
        'api_type': apiTypeValues.reverse[apiType],
        'enums': enums == null
            ? <dynamic>[]
            : List<dynamic>.from(
                enums!.map<dynamic>((dynamic x) => x.toJson())),
        'methods': methods == null
            ? <dynamic>[]
            : List<dynamic>.from(
                methods!.map<dynamic>((dynamic x) => x.toJson())),
        'properties': properties == null
            ? <dynamic>[]
            : List<dynamic>.from(
                properties!.map<dynamic>((dynamic x) => x.toJson())),
        'signals': signals == null
            ? <dynamic>[]
            : List<dynamic>.from(
                signals!.map<dynamic>((dynamic x) => x.toJson())),
        'constants': constants == null
            ? <dynamic>[]
            : List<dynamic>.from(
                constants!.map<dynamic>((dynamic x) => x.toJson())),
      };
}

enum ApiType { core, editor }

final apiTypeValues =
    EnumValues({'core': ApiType.core, 'editor': ApiType.editor});

class GlobalEnumElement {
  GlobalEnumElement({
    required this.name,
    required this.isBitfield,
    required this.values,
  });

  String name;
  bool isBitfield;
  List<Value> values;

  factory GlobalEnumElement.fromRawJson(String str) =>
      GlobalEnumElement.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory GlobalEnumElement.fromJson(Map<String, dynamic> json) =>
      GlobalEnumElement(
        name: json['name'],
        isBitfield: json['is_bitfield'],
        values: List<Value>.from(
            json['values'].map((dynamic x) => Value.fromJson(x))),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'is_bitfield': isBitfield,
        'values':
            List<dynamic>.from(values.map<dynamic>((dynamic x) => x.toJson())),
      };
}

class ClassMethod {
  ClassMethod({
    required this.name,
    required this.isConst,
    required this.isVararg,
    required this.isStatic,
    required this.isVirtual,
    this.hash,
    this.returnValue,
    this.arguments,
  });

  String name;
  bool isConst;
  bool isVararg;
  bool isStatic;
  bool isVirtual;
  int? hash;
  ReturnValue? returnValue;
  List<Argument>? arguments;

  factory ClassMethod.fromRawJson(String str) =>
      ClassMethod.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory ClassMethod.fromJson(Map<String, dynamic> json) => ClassMethod(
        name: json['name'],
        isConst: json['is_const'],
        isVararg: json['is_vararg'],
        isStatic: json['is_static'],
        isVirtual: json['is_virtual'],
        hash: json['hash'],
        returnValue: json['return_value'] == null
            ? null
            : ReturnValue.fromJson(json['return_value']),
        arguments: json['arguments'] == null
            ? []
            : List<Argument>.from(
                json['arguments']!.map((dynamic x) => Argument.fromJson(x))),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'is_const': isConst,
        'is_vararg': isVararg,
        'is_static': isStatic,
        'is_virtual': isVirtual,
        'hash': hash,
        'return_value': returnValue?.toJson(),
        'arguments': arguments == null
            ? <dynamic>[]
            : List<dynamic>.from(
                arguments!.map<dynamic>((dynamic x) => x.toJson())),
      };
}

class ReturnValue {
  ReturnValue({
    required this.type,
    this.meta,
  });

  String type;
  ArgumentMeta? meta;

  factory ReturnValue.fromRawJson(String str) =>
      ReturnValue.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory ReturnValue.fromJson(Map<String, dynamic> json) => ReturnValue(
        type: json['type'],
        meta: argumentMetaValues.map[json['meta']],
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'meta': argumentMetaValues.reverse[meta],
      };
}

class Property {
  Property({
    required this.type,
    required this.name,
    this.setter,
    required this.getter,
    this.index,
  });

  String type;
  String name;
  String? setter;
  String getter;
  int? index;

  factory Property.fromRawJson(String str) =>
      Property.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Property.fromJson(Map<String, dynamic> json) => Property(
        type: json['type'],
        name: json['name'],
        setter: json['setter'],
        getter: json['getter'],
        index: json['index'],
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'name': name,
        'setter': setter,
        'getter': getter,
        'index': index,
      };
}

class Signal {
  Signal({
    required this.name,
    this.arguments,
  });

  String name;
  List<Singleton>? arguments;

  factory Signal.fromRawJson(String str) => Signal.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Signal.fromJson(Map<String, dynamic> json) => Signal(
        name: json['name'],
        arguments: json['arguments'] == null
            ? []
            : List<Singleton>.from(
                json['arguments']!.map((dynamic x) => Singleton.fromJson(x))),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'arguments': arguments == null
            ? <dynamic>[]
            : List<dynamic>.from(
                arguments!.map<dynamic>((dynamic x) => x.toJson())),
      };
}

class Header {
  Header({
    required this.versionMajor,
    required this.versionMinor,
    required this.versionPatch,
    required this.versionStatus,
    required this.versionBuild,
    required this.versionFullName,
  });

  int versionMajor;
  int versionMinor;
  int versionPatch;
  String versionStatus;
  String versionBuild;
  String versionFullName;

  factory Header.fromRawJson(String str) => Header.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Header.fromJson(Map<String, dynamic> json) => Header(
        versionMajor: json['version_major'],
        versionMinor: json['version_minor'],
        versionPatch: json['version_patch'],
        versionStatus: json['version_status'],
        versionBuild: json['version_build'],
        versionFullName: json['version_full_name'],
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version_major': versionMajor,
        'version_minor': versionMinor,
        'version_patch': versionPatch,
        'version_status': versionStatus,
        'version_build': versionBuild,
        'version_full_name': versionFullName,
      };
}

class NativeStructure {
  NativeStructure({
    required this.name,
    required this.format,
  });

  String name;
  String format;

  factory NativeStructure.fromRawJson(String str) =>
      NativeStructure.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory NativeStructure.fromJson(Map<String, dynamic> json) =>
      NativeStructure(
        name: json['name'],
        format: json['format'],
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'format': format,
      };
}

class UtilityFunction {
  UtilityFunction({
    required this.name,
    this.returnType,
    required this.category,
    required this.isVararg,
    required this.hash,
    this.arguments,
  });

  String name;
  ReturnType? returnType;
  Category category;
  bool isVararg;
  int hash;
  List<Singleton>? arguments;

  factory UtilityFunction.fromRawJson(String str) =>
      UtilityFunction.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory UtilityFunction.fromJson(Map<String, dynamic> json) =>
      UtilityFunction(
        name: json['name'],
        returnType: returnTypeValues.map[json['return_type']],
        category: categoryValues.map[json['category']]!,
        isVararg: json['is_vararg'],
        hash: json['hash'],
        arguments: json['arguments'] == null
            ? []
            : List<Singleton>.from(
                json['arguments']!.map((dynamic x) => Singleton.fromJson(x))),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'name': name,
        'return_type': returnTypeValues.reverse[returnType],
        'category': categoryValues.reverse[category],
        'is_vararg': isVararg,
        'hash': hash,
        'arguments': arguments == null
            ? <dynamic>[]
            : List<dynamic>.from(
                arguments!.map<dynamic>((dynamic x) => x.toJson())),
      };
}

enum Category { math, random, general }

final categoryValues = EnumValues({
  'general': Category.general,
  'math': Category.math,
  'random': Category.random
});

enum ReturnType {
  float,
  int,
  variant,
  bool,
  packedInt64Array,
  string,
  packedByteArray,
  object,
  rid
}

final returnTypeValues = EnumValues({
  'bool': ReturnType.bool,
  'float': ReturnType.float,
  'int': ReturnType.int,
  'Object': ReturnType.object,
  'PackedByteArray': ReturnType.packedByteArray,
  'PackedInt64Array': ReturnType.packedInt64Array,
  'RID': ReturnType.rid,
  'String': ReturnType.string,
  'Variant': ReturnType.variant
});

class EnumValues<T> {
  Map<String, T> map;
  late Map<T, String> reverseMap;

  EnumValues(this.map);

  Map<T, String> get reverse {
    reverseMap = map.map((k, v) => MapEntry(v, k));
    return reverseMap;
  }
}
