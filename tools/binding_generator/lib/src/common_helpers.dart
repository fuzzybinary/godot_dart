import 'code_sink.dart';
import 'godot_api_info.dart';
import 'godot_extension_api_json.dart';
import 'string_extensions.dart';
import 'type_helpers.dart';

const String header = '''// AUTO GENERATED FILE, DO NOT EDIT.
//
// Generated by `godot_dart binding_generator`.
// ignore_for_file: duplicate_import
// ignore_for_file: unused_import
// ignore_for_file: unnecessary_import
// ignore_for_file: unused_field
// ignore_for_file: non_constant_identifier_names
// ignore_for_file: unused_local_variable
// ignore_for_file: unused_element
''';

void writeImports(
    CodeSink out, GodotApiInfo api, dynamic classApi, bool forVariant) {
  final String className;
  // Convert the class back to json, as that's easier to process for finding used classes
  Map<String, dynamic> json;
  if (classApi is BuiltinClass) {
    json = classApi.toJson();
    className = classApi.name;
  } else if (classApi is GodotExtensionApiJsonClass) {
    json = classApi.toJson();
    className = classApi.name;
  } else {
    throw ArgumentError(
        'invalid class passed to writeImports: ${classApi.runtimeType}');
  }

  out.write('''
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../../core/core_types.dart';
import '../../core/gdextension_ffi_bindings.dart';
import '../../core/gdextension.dart';
import '../../core/type_info.dart';
import '${forVariant ? '' : '../variant/'}string_name.dart';
${forVariant ? '' : "import '../../variant/variant.dart';"}

''');

  final builtinPreface = forVariant ? '' : '../variant/';
  final enginePreface = forVariant ? '../classes/' : '';

  final usedClasses = getUsedTypes(json);
  for (var used in usedClasses) {
    if (used != className) {
      if (used == 'Variant') {
        out.p("import '../../variant/variant.dart';");
      } else if (used == 'TypedArray') {
        out.p("import '../../variant/typed_array.dart';");
      } else if (used == 'GlobalConstants') {
        out.p("import '../global_constants.dart';");
      } else {
        var prefix = api.builtinClasses.containsKey(used)
            ? builtinPreface
            : enginePreface;
        out.p("import '$prefix${used.toSnakeCase()}.dart';");
      }
    }
  }
}

String? argumentAllocation(ArgumentProxy arg) {
  if (!arg.needsAllocation) return null;

  var ffiType = getFFIType(arg);
  final argName = escapeName(arg.name).toLowerCamelCase();
  return 'final ${argName}Ptr = arena.allocate<$ffiType>(sizeOf<$ffiType>())..value = $argName;';
}

bool writeReturnAllocation(ArgumentProxy returnType, CodeSink o) {
  if (returnType.typeCategory == TypeCategory.engineClass) {
    // Need a pointer to a pointer
    o.p('final retPtr = arena.allocate<GDExtensionObjectPtr>(sizeOf<GDExtensionObjectPtr>());');
    return true;
  } else {
    final nativeType = getFFIType(returnType);
    if (nativeType == null) {
      o.p('final retPtr = retVal.nativePtr;');
      return false;
    } else {
      o.p('final retPtr = arena.allocate<$nativeType>(sizeOf<$nativeType>());');
      return true;
    }
  }
}

void withAllocationBlock(
  List<ArgumentProxy> arguments,
  ArgumentProxy? retInfo,
  CodeSink out,
  void Function() writeBlock,
) {
  var needsArena = retInfo?.typeCategory != TypeCategory.voidType ||
      arguments.any((arg) => arg.needsAllocation);
  if (needsArena) {
    out.b('using((arena) {', () {
      for (final arg in arguments) {
        final alloc = argumentAllocation(arg);
        if (alloc != null) out.p(alloc);
      }
      writeBlock();
    }, '});');
  } else {
    writeBlock();
  }
}

/// Generate a constructor name from arguments types. In the case
/// of a single argument constructor of the same type, the constructor
/// is called 'copy'. Otherwise it is named '.from{ArgType1}{ArgType2}'
String getConstructorName(String type, Constructor constructor) {
  final arguments = constructor.arguments;
  if (arguments != null && arguments.isNotEmpty) {
    if (arguments.length == 1) {
      var argument = arguments[0];
      if (argument.type == type) {
        return '.copy';
      } else if (argument.type == 'String') {
        return '.fromGDString';
      }
      return '.from${argument.type}';
    } else {
      var name = '.from';
      for (final arg in arguments) {
        var argName = escapeName(arg.name).toLowerCamelCase();
        name += argName[0].toUpperCase() + argName.substring(1);
      }
      return name;
    }
  }

  return '';
}

String getDartMethodName(String name, bool isVirtual) {
  if (isVirtual && name.startsWith('_')) {
    name = name.replaceFirst('_', 'v_');
  }

  name = escapeMethodName(name).toLowerCamelCase();
  return name;
}

String makeSignature(BuiltinClassMethod functionData) {
  var modifiers = '';
  if (functionData.isStatic) {
    modifiers += 'static ';
  }
  final methodName = getDartMethodName(functionData.name, false);

  var signature =
      '$modifiers${godotTypeToDartType(functionData.returnType)} $methodName(';

  final parameters = functionData.arguments;
  if (parameters != null) {
    List<String> paramSignature = [];

    for (int i = 0; i < parameters.length; ++i) {
      final parameter = parameters[i];

      // TODO: Default values
      paramSignature.add(
          '${parameter.proxy.dartType} ${escapeName(parameter.name).toLowerCamelCase()}');
    }
    signature += paramSignature.join(', ');
  }

  signature += ')';

  return signature;
}

String makeEngineMethodSignature(ClassMethod methodData) {
  var modifiers = '';
  if (methodData.isStatic) {
    modifiers += 'static ';
  }
  final methodName = getDartMethodName(methodData.name, methodData.isVirtual);

  var returnType = 'void';
  if (methodData.returnValue != null) {
    returnType = methodData.returnValue!.proxy.dartType;
  }

  var signature = '$modifiers$returnType $methodName(';

  final parameters = methodData.arguments;
  if (parameters != null) {
    List<String> paramSignature = [];

    for (int i = 0; i < parameters.length; ++i) {
      final parameter = parameters[i];

      // TODO: Default values
      paramSignature.add(
          '${parameter.proxy.dartType} ${escapeName(parameter.name).toLowerCamelCase()}');
    }
    signature += paramSignature.join(', ');
  }

  signature += ')';

  return signature;
}

String nakedType(String type) {
  if (type.startsWith('const')) {
    type = type.replaceFirst('const', '');
  }
  while (type.endsWith('*')) {
    type = type.substring(0, type.length - 1);
  }

  return type.trim();
}

List<String> getUsedTypes(Map<String, dynamic> api) {
  var usedTypes = <String>{};
  var inherits = api['inherits'] as String?;
  if (inherits != null) {
    usedTypes.add(inherits);
  }

  if (api['constructors'] != null) {
    for (Map<String, dynamic> constructor in api['constructors']) {
      if (constructor['arguments'] != null) {
        for (Map<String, dynamic> arg in constructor['arguments']) {
          usedTypes.add(nakedType(arg['type']));
        }
      }
    }
  }

  if (api['methods'] != null) {
    for (Map<String, dynamic> method in api['methods']) {
      if (method['arguments'] != null) {
        for (Map<String, dynamic> arg in method['arguments']) {
          usedTypes.add(nakedType(arg['type']));
        }
      }
      if (method['return_type'] != null) {
        usedTypes.add(nakedType(method['return_type']));
      } else if (method['return_value'] != null) {
        final returnValue = method['return_value'] as Map<String, dynamic>;
        usedTypes.add(nakedType(returnValue['type']));
      }
    }
  }

  if (api['members'] != null) {
    for (Map<String, dynamic> member in api['members']) {
      usedTypes.add(nakedType(member['type']));
    }
  }

  // Typed arrays and enums
  if (usedTypes.any((e) => e.startsWith('typedarray::'))) {
    final typedArraySet = <String>{};
    for (var type in usedTypes) {
      if (type.startsWith('typedarray::')) {
        final typeParameter = type.split('::')[1];
        typedArraySet.add(typeParameter);
      }
    }
    usedTypes.removeWhere((e) => e.startsWith('typedarray::'));
    usedTypes.addAll(typedArraySet);
    usedTypes.add('TypedArray');
  }

  final enumAndBitfieldTypes = <String>[];
  for (var type in usedTypes
      .where((e) => e.startsWith('enum::') || e.startsWith('bitfield::'))) {
    if (type.contains('.')) {
      final parentClass = type
          .replaceAll('enum::', '')
          .replaceAll('bitfield::', '')
          .split('.')
          .first;
      // Special case -- enum::Variant.Type is held in GlobalConstants
      if (parentClass == 'Variant') {
        enumAndBitfieldTypes.add('GlobalConstants');
      } else {
        enumAndBitfieldTypes.add(parentClass);
      }
    } else {
      enumAndBitfieldTypes.add('GlobalConstants');
    }
  }
  usedTypes
      .removeWhere((e) => e.startsWith('enum::') || e.startsWith('bitfield::'));
  usedTypes.addAll(enumAndBitfieldTypes);

  usedTypes.remove('void');

  usedTypes.removeAll(dartTypes);
  // Already included
  usedTypes.remove('StringName');

  return usedTypes.toList();
}

void convertPtrArgument(int index, ArgumentProxy argument, CodeSink o) {
  // TODO: Parameters mostly currently take 'GDString' whereas returns are 'String'
  // I need to figure out how to make it String across the board.
  // if (argument.godotType == 'String') {
  //   // Very sepecial -- needs to be converted to a Dart String
  //   var ret =
  //       '${indent}final GDString gd${argument.name} = GDString.fromPointer(args.elementAt($index).value);\n';
  //   ret +=
  //       '${indent}final ${argument.name} = gde.dartBindings.gdStringToString(gd${argument.name});\n';
  //   return ret;
  // }

  var decl =
      'final ${argument.dartType} ${escapeName(argument.name).toLowerCamelCase()}';
  switch (argument.typeCategory) {
    case TypeCategory.engineClass:
      o.p('$decl = ${argument.rawDartType}.fromOwner(args.elementAt($index).value);');
      break;
    case TypeCategory.builtinClass:
      o.p('$decl = ${argument.rawDartType}.fromPointer(args.elementAt($index).value);');
      break;
    case TypeCategory.primitive:
      final castType =
          argument.isPointer ? argument.dartType : getFFIType(argument);
      o.p('$decl = args.elementAt($index).cast<Pointer<$castType>>().value.value;');
      break;
    case TypeCategory.nativeStructure:
      if (argument.isOptional) {
        o.p('final ${argument.name}Ptr = args.elementAt($index).cast<Pointer<${argument.dartType}>>().value;');
        o.p('$decl = ${argument.name}Ptr == nullptr ? null : ${argument.name}Ptr.ref;');
      } else if (argument.isPointer) {
        o.p('$decl = args.elementAt($index).cast<Pointer<${argument.dartType}>>().value.value;');
      } else {
        o.p('$decl = args.elementAt($index).cast<Pointer<${argument.dartType}>>().value.ref;');
      }
      break;
    case TypeCategory.enumType:
      o.p('$decl = ${argument.dartType}.fromValue(args.elementAt($index).cast<Pointer<Int32>>().value.value);');
      break;
    case TypeCategory.typedArray:
      o.p('$decl = ${argument.dartType}.fromPointer(args.elementAt($index).value);');
      break;
    case TypeCategory.voidType:
      if (argument.dartType.startsWith('Pointer')) {
        o.p('$decl = args.elementAt($index).value;');
      }
      break;
  }
}

void writePtrReturn(ArgumentProxy argument, CodeSink o) {
  // if (argument.type == 'String') {
  //   o.p('final retGdString = GDString.fromString(ret);');
  //   o.p('gde.dartBindings.variantCopyToNative(retPtr, retGdString);');
  //   return;
  // }

  var ret = '';
  switch (argument.typeCategory) {
    case TypeCategory.engineClass:
      ret += 'retPtr.cast<GDExtensionTypePtr>().value = ';
      ret +=
          argument.isOptional ? 'ret?.nativePtr ?? nullptr' : 'ret.nativePtr';
      break;
    case TypeCategory.builtinClass:
      ret += 'gde.dartBindings.variantCopyToNative(retPtr, ret)';
      break;
    case TypeCategory.primitive:
      final castType =
          argument.isPointer ? argument.dartType : getFFIType(argument);
      ret += 'retPtr.cast<$castType>().value = ret';
      break;
    case TypeCategory.nativeStructure:
      if (argument.isPointer) {
        ret += 'retPtr.cast<${argument.dartType}>().value = ret';
      } else {
        ret += 'retPtr.cast<${argument.dartType}>().ref = ret';
      }
      break;
    case TypeCategory.enumType:
      // TODO: Determine if enums are variable width?
      ret += 'retPtr.cast<Int32>().value = ret.value';
      break;
    case TypeCategory.typedArray:
      ret += 'gde.dartBindings.variantCopyToNative(retPtr, ret)';
      break;
    case TypeCategory.voidType:
      return;
  }

  o.p('$ret;');
}

void writeEnum(dynamic godotEnum, String? inClass, CodeSink o) {
  String name;
  List<Value> valueList;
  if (godotEnum is BuiltinClassEnum) {
    name = godotEnum.name;
    valueList = godotEnum.values;
  } else if (godotEnum is GlobalEnumElement) {
    name = godotEnum.name;
    valueList = godotEnum.values;
  } else {
    throw ArgumentError(
        'Tring to write an enum that is of type ${godotEnum.runtimeType}');
  }

  var enumName = getEnumName(name, inClass);
  o.b('enum $enumName {', () {
    for (int i = 0; i < valueList.length; ++i) {
      final value = valueList[i];
      final end = i == valueList.length - 1 ? ';' : ',';
      o.p('${value.name.toLowerCamelCase()}(${value.value})$end');
    }
    o.nl();

    o.p('final int value;');
    o.p('const $enumName(this.value);');
    o.b('factory $enumName.fromValue(int value) {', () {
      o.p('return values.firstWhere((e) => e.value == value);');
    }, '}');
  }, '}');
}
