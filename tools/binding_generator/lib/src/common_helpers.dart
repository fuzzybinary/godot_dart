import 'dart:io';

import 'godot_api_info.dart';
import 'string_extensions.dart';
import 'type_helpers.dart';
import 'type_info.dart';

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

void writeImports(IOSink out, GodotApiInfo api, Map<String, dynamic> classApi,
    bool forVariant) {
  final String className = classApi['name'];

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

  final usedClasses = getUsedTypes(classApi);
  for (var used in usedClasses) {
    if (used != className) {
      if (used == 'Variant') {
        out.write("import '../../variant/variant.dart';\n");
      } else if (used == 'TypedArray') {
        out.write("import '../../variant/typed_array.dart';\n");
      } else if (used == 'GlobalConstants') {
        out.write("import '../global_constants.dart';\n");
      } else {
        var prefix = api.builtinClasses.containsKey(used)
            ? builtinPreface
            : enginePreface;
        out.write("import '$prefix${used.toSnakeCase()}.dart';\n");
      }
    }
  }
}

void argumentAllocation(ArgumentInfo typeInfo, IOSink out) {
  if (!typeInfo.needsAllocation) return;

  var ffiType = getFFIType(typeInfo);
  out.write(
      '      final ${typeInfo.name}Ptr = arena.allocate<$ffiType>(sizeOf<$ffiType>())..value = ${typeInfo.name};\n');
}

bool writeReturnAllocation(
    GodotApiInfo info, ArgumentInfo returnType, IOSink out) {
  // TODO check for types other than engine and builtins
  String indent = '      ';
  out.write(indent);
  if (returnType.typeInfo.typeCategory == TypeCategory.engineClass) {
    // Need a pointer to a pointer
    out.write(
        'final retPtr = arena.allocate<GDExtensionObjectPtr>(sizeOf<GDExtensionObjectPtr>());\n');
    return true;
  } else {
    final nativeType = getFFIType(returnType);
    if (nativeType == null) {
      out.write('final retPtr = retVal.nativePtr;\n');
      return false;
    } else {
      out.write(
          'final retPtr = arena.allocate<$nativeType>(sizeOf<$nativeType>());\n');
      return true;
    }
  }
}

void withAllocationBlock(
  List<ArgumentInfo> arguments,
  ArgumentInfo? retInfo,
  IOSink out,
  void Function(String indent) writeBlock,
) {
  var indent = '';
  var needsArena = retInfo?.typeInfo.typeCategory != TypeCategory.voidType ||
      arguments.any((arg) => arg.needsAllocation);
  if (needsArena) {
    indent = '  ';
    out.write('''
    using((arena) {
''');
    for (final arg in arguments) {
      argumentAllocation(arg, out);
    }
  }
  writeBlock(indent);
  if (needsArena) {
    out.write('    });\n');
  }
}

void argumentFree(ArgumentInfo argument, IOSink out) {
  if (!argument.needsAllocation) return;

  out.write('    malloc.free(${argument.name!.toLowerCamelCase()}Ptr);\n');
}

/// Generate a constructor name from arguments types. In the case
/// of a single argument constructor of the same type, the constructor
/// is called 'copy'. Otherwise it is named '.from{ArgType1}{ArgType2}'
String getConstructorName(String type, Map<String, dynamic> constructor) {
  var arguments = constructor['arguments'] as List?;
  if (arguments != null) {
    if (arguments.length == 1) {
      var argument = arguments[0] as Map<String, dynamic>;
      final argType = argument['type'] as String;
      if (argType == type) {
        return '.copy';
      } else if (argType == 'String') {
        return '.fromGDString';
      }
      return '.from${argument['type']}';
    } else {
      var name = '.from';
      for (final arg in arguments) {
        var argName = escapeName((arg['name'] as String)).toLowerCamelCase();
        name += argName[0].toUpperCase() + argName.substring(1);
      }
      return name;
    }
  }

  return '';
}

String getDartMethodName(Map<String, dynamic> functionData) {
  bool isVirtual = functionData['is_virtual'] ?? false;
  var methodName = functionData['name'] as String;

  if (isVirtual && methodName.startsWith('_')) {
    methodName = methodName.replaceFirst('_', 'v_');
  }

  methodName = escapeMethodName(methodName).toLowerCamelCase();
  return methodName;
}

String makeSignature(GodotApiInfo api, Map<String, dynamic> functionData) {
  var modifiers = '';
  var returnInfo = api.getReturnInfo(functionData);

  final methodName = getDartMethodName(functionData);

  var signature = '$modifiers${returnInfo.fullDartType} $methodName(';

  final List<dynamic>? parameters = functionData['arguments'];
  if (parameters != null) {
    List<String> paramSignature = [];

    for (int i = 0; i < parameters.length; ++i) {
      Map<String, dynamic> parameter = parameters[i];
      final type = api.getArgumentInfo(parameter);

      // TODO: Default values
      paramSignature.add('${type.fullDartType} ${type.name}');
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

  if (api.containsKey('constructors')) {
    for (Map<String, dynamic> constructor in api['constructors']) {
      if (constructor.containsKey('arguments')) {
        for (Map<String, dynamic> arg in constructor['arguments']) {
          usedTypes.add(nakedType(arg['type']));
        }
      }
    }
  }

  if (api.containsKey('methods')) {
    for (Map<String, dynamic> method in api['methods']) {
      if (method.containsKey('arguments')) {
        for (Map<String, dynamic> arg in method['arguments']) {
          usedTypes.add(nakedType(arg['type']));
        }
      }
      if (method.containsKey('return_type')) {
        usedTypes.add(nakedType(method['return_type']));
      } else if (method.containsKey('return_value')) {
        final returnValue = method['return_value'] as Map<String, dynamic>;
        usedTypes.add(nakedType(returnValue['type']));
      }
    }
  }

  if (api.containsKey('members')) {
    if (api.containsKey('members')) {
      for (Map<String, dynamic> member in api['members']) {
        usedTypes.add(nakedType(member['type']));
      }
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

String convertPtrArgument(
  int index,
  ArgumentInfo argument, {
  String indent = '    ',
}) {
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

  var ret = '${indent}final ${argument.fullDartType} ${argument.name} = ';
  switch (argument.typeInfo.typeCategory) {
    case TypeCategory.engineClass:
      ret += '${argument.dartType}.fromOwner(args.elementAt($index).value)';
      break;
    case TypeCategory.builtinClass:
      ret += '${argument.dartType}.fromPointer(args.elementAt($index).value)';
      break;
    case TypeCategory.primitive:
      final castType =
          argument.isPointer ? argument.fullDartType : getFFIType(argument);
      ret += 'args.elementAt($index).cast<Pointer<$castType>>().value.value';
      break;
    case TypeCategory.nativeStructure:
      if (argument.isOptional) {
        // Completely rewrite for native structures because of optionals
        ret =
            '${indent}final ${argument.name}Ptr = args.elementAt($index).cast<Pointer<${argument.dartType}>>().value;\n';
        ret +=
            '${indent}final ${argument.fullDartType} ${argument.name} = ${argument.name}Ptr == nullptr ? null : ${argument.name}Ptr.ref';
      } else if (argument.isPointer) {
        ret +=
            'args.elementAt($index).cast<Pointer<${argument.dartType}>>().value.value';
      } else {
        ret +=
            'args.elementAt($index).cast<Pointer<${argument.dartType}>>().value.ref';
      }
      break;
    case TypeCategory.enumType:
      ret +=
          '${argument.dartType}.fromValue(args.elementAt($index).cast<Pointer<Int32>>().value.value)';
      break;
    case TypeCategory.typedArray:
      ret += '${argument.dartType}.fromPointer(args.elementAt($index).value)';
      break;
    case TypeCategory.voidType:
      if (argument.dartType.startsWith('Pointer')) {
        ret += 'args.elementAt($index).value';
      }
      break;
  }

  ret += ';\n';

  return ret;
}

String writePtrReturn(ArgumentInfo argument, {String indent = '    '}) {
  if (argument.typeInfo.godotType == 'String') {
    var ret = '${indent}final retGdString = GDString.fromString(ret);\n';
    ret +=
        '${indent}gde.dartBindings.variantCopyToNative(retPtr, retGdString);\n';
    return ret;
  }

  var ret = indent;
  switch (argument.typeInfo.typeCategory) {
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
      return '';
  }

  ret += ';\n';

  return ret;
}

void writeEnum(Map<String, dynamic> godotEnum, String? inClass, IOSink out) {
  var enumName = getEnumName(godotEnum['name'], inClass);
  out.write('enum $enumName {\n');
  List<String> values = [];
  for (Map<String, dynamic> value in godotEnum['values']) {
    final name = (value['name'] as String).toLowerCamelCase();
    values.add('  $name(${value['value']})');
  }
  out.write(values.join(',\n'));
  out.write(';\n');

  out.write('''

  final int value;
  const $enumName(this.value);
  factory $enumName.fromValue(int value) {
    return values.firstWhere((e) => e.value == value);
  }
}

''');
}
