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
import '${forVariant ? '' : '../variant/'}string.dart';
import '${forVariant ? '' : '../variant/'}string_name.dart';
import '../../variant/variant.dart';

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
      } else if (hasCustomImplementation(used)) {
        // Should be exported in variant.dart
        continue;
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
  if (arg.needsAllocation) {
    var ffiType = getFFIType(arg);
    final argName = escapeName(arg.name).toLowerCamelCase();
    return 'final ${argName}Ptr = arena.allocate<$ffiType>(sizeOf<$ffiType>())..value = $argName;';
  } else if (arg.typeCategory == TypeCategory.engineClass) {
    final argName = escapeName(arg.name).toLowerCamelCase();
    return 'final ${argName}Ptr = arena.allocate<GDExtensionObjectPtr>(sizeOf<GDExtensionObjectPtr>())..value = ($argName?.nativePtr ?? nullptr);';
  }
  return null;
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

void writeArgumentAllocations(List<ArgumentProxy> arguments, CodeSink out) {
  for (final arg in arguments) {
    final alloc = argumentAllocation(arg);
    if (alloc != null) out.p(alloc);
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

String getArgumentDefaultValue(Argument arg, String defaultValue) {
  if (arg.proxy.typeCategory == TypeCategory.enumType) {
    return GodotApiInfo.instance()
        .findEnumValue(arg.proxy.dartType, arg.defaultValue!);
  }

  final argumentCapture = RegExp(r'.+\((?<args>.+)\)');
  switch (arg.type) {
    case 'Variant':
      if (defaultValue == 'null') return 'Variant()';
      if (defaultValue == '0') return 'Variant.fromObject(0)';
      break;
    case 'Vector2':
    case 'Vector2i':
      final args = argumentCapture.firstMatch(defaultValue)?.namedGroup('args');
      if (args != null) {
        return '${arg.type}.fromXY($args)';
      }
      break;
    case 'Vector3':
      final args = argumentCapture.firstMatch(defaultValue)?.namedGroup('args');
      if (args != null) {
        final parts = args.split(',');
        return 'Vector3(x: ${parts[0]}, y: ${parts[1]}, z: ${parts[2]})';
      }
      break;
    case 'Transform2D':
      // Transform2d says its default value is 6 values then doesn't have a constructor
      // that takes 6 values, go figure
      final args = argumentCapture.firstMatch(defaultValue)?.namedGroup('args');
      if (args != null) {
        final parts = args.split(',');
        return 'Transform2D.fromXAxisYAxisOrigin('
            'Vector2.fromXY(${parts[0]}, ${parts[1]}), '
            'Vector2.fromXY(${parts[2]}, ${parts[3]}), '
            'Vector2.fromXY(${parts[4]}, ${parts[5]}),)';
      }
      break;
    case 'Transform3D':
      // Transform2d says its default value is 12 values then doesn't have a constructor
      // that takes 12 values, go figure
      final args = argumentCapture.firstMatch(defaultValue)?.namedGroup('args');
      if (args != null) {
        final parts = args.split(',');
        return 'Transform3D.fromXAxisYAxisZAxisOrigin('
            'Vector3(x: ${parts[0]}, y: ${parts[1]}, z: ${parts[2]}), '
            'Vector3(x: ${parts[3]}, y: ${parts[4]}, z: ${parts[5]}), '
            'Vector3(x: ${parts[6]}, y: ${parts[7]}, z: ${parts[8]}), '
            'Vector3(x: ${parts[9]}, y: ${parts[10]}, z: ${parts[11]}),)';
      }
      break;
    case 'NodePath':
      // Transform2d says its default value is 6 values then doesn't have a constructor
      // that takes 6 values, go figure
      final args = argumentCapture.firstMatch(defaultValue)?.namedGroup('args');
      if (args != null) {
        // TOOD: Replace with NodePath.fromString when possible
        return 'NodePath.fromGDString(GDString.fromString(${args.replaceAll('"', "'")}))';
      }
      break;
    case 'Color':
      final args = argumentCapture.firstMatch(defaultValue)?.namedGroup('args');
      if (args != null) {
        return 'Color.fromRGBA($args)';
      }
      break;
    case 'Rect2':
    case 'Rect2i':
      final args = argumentCapture.firstMatch(defaultValue)?.namedGroup('args');
      if (args != null) {
        return '${arg.type}.fromXYWidthHeight($args)';
      }
      break;
    case 'String':
    case 'StringName':
      if (defaultValue == '&""') return "''";
      return defaultValue.replaceAll('"', "'");
    case 'Array':
      if (defaultValue == '[]') return 'Array()';
      break;
    case 'Dictionary':
      if (defaultValue == '{}') return 'Dictionary()';
      break;
  }

  if (arg.type.startsWith('typedarray::')) {
    final typedArrayArgumentCapture =
        RegExp(r'Array\[(?<type>.+)\]\((?<arg>.+)\)');
    final arrayArguments =
        typedArrayArgumentCapture.firstMatch(arg.defaultValue!);
    if (arrayArguments?.namedGroup('arg') == '[]' || arg.defaultValue == '[]') {
      return '${arg.proxy.dartType}()';
    }
  }

  return defaultValue;
}

void assignMethodDefaults(List<Argument> arguments, CodeSink o) {
  bool needsDefaultAssignment(Argument a) {
    return a.defaultValue != null &&
        !isPrimitiveType(a.proxy.dartType) &&
        !a.proxy.isOptional;
  }

  for (final arg in arguments.where((a) => needsDefaultAssignment(a))) {
    final argName = escapeName(arg.name).toLowerCamelCase();
    final defaultValue = getArgumentDefaultValue(arg, arg.defaultValue!);
    o.p('$argName ??= $defaultValue;');
  }
}

extension ClassMethodConverter on BuiltinClassMethod {
  ClassMethod asMethodData() {
    return ClassMethod(
      name: name,
      isConst: isConst,
      isVararg: isVararg,
      isStatic: isStatic,
      isVirtual: false,
      hash: hash,
      returnValue: returnType == null ? null : ReturnValue(type: returnType!),
      arguments: arguments,
    );
  }
}

String makeSignature(dynamic functionData, {bool useGodotStringTypes = false}) {
  assert(functionData is BuiltinClassMethod || functionData is ClassMethod);
  ClassMethod methodData;
  if (functionData is ClassMethod) {
    methodData = functionData;
  } else if (functionData is BuiltinClassMethod) {
    methodData = functionData.asMethodData();
  } else {
    return '';
  }

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
  List<String> positionalParamSignature = [];
  List<String> namedParamSignature = [];
  if (parameters != null) {
    for (int i = 0; i < parameters.length; ++i) {
      final parameter = parameters[i];

      var type = parameter.proxy.dartType;
      if (useGodotStringTypes && type == 'String') {
        type = parameter.proxy.type;
      }

      if (parameter.defaultValue == null) {
        positionalParamSignature
            .add('$type ${escapeName(parameter.name).toLowerCamelCase()}');
      } else {
        if (parameter.proxy.isOptional) {
          // Don't double opt.
          namedParamSignature
              .add('$type ${escapeName(parameter.name).toLowerCamelCase()}');
        } else {
          if (isPrimitiveType(parameter.proxy.dartType)) {
            namedParamSignature.add(
                '$type ${escapeName(parameter.name).toLowerCamelCase()} = ${getArgumentDefaultValue(parameter, parameter.defaultValue!)}');
          } else {
            namedParamSignature
                .add('$type? ${escapeName(parameter.name).toLowerCamelCase()}');
          }
        }
      }
    }
  }

  if (methodData.isVararg) {
    namedParamSignature.add('List<Variant> vargs = const []');
  }

  if (positionalParamSignature.isNotEmpty) {
    signature += positionalParamSignature.join(', ');
  }
  if (namedParamSignature.isNotEmpty) {
    if (positionalParamSignature.isNotEmpty) signature += ', ';
    signature += '{${namedParamSignature.join(', ')}}';
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
    final constructors = api['constructors'] as List<dynamic>;
    for (Map<String, dynamic> constructor
        in constructors.map((e) => e as Map<String, dynamic>)) {
      if (constructor['arguments'] != null) {
        final args = constructor['arguments'] as List<dynamic>;
        for (Map<String, dynamic> arg
            in args.map((e) => e as Map<String, dynamic>)) {
          usedTypes.add(nakedType(arg['type'] as String));
        }
      }
    }
  }

  if (api['methods'] != null) {
    final methods = api['methods'] as List<dynamic>;
    for (Map<String, dynamic> method
        in methods.map((e) => e as Map<String, dynamic>)) {
      if (method['arguments'] != null) {
        final args = method['arguments'] as List<dynamic>;
        for (Map<String, dynamic> arg
            in args.map((e) => e as Map<String, dynamic>)) {
          usedTypes.add(nakedType(arg['type'] as String));
        }
      }
      if (method['return_type'] != null) {
        usedTypes.add(nakedType(method['return_type'] as String));
      } else if (method['return_value'] != null) {
        final returnValue = method['return_value'] as Map<String, dynamic>;
        usedTypes.add(nakedType(returnValue['type'] as String));
      }
    }
  }

  if (api['members'] != null) {
    final members = api['members'] as List<dynamic>;
    for (Map<String, dynamic> member
        in members.map((e) => e as Map<String, dynamic>)) {
      usedTypes.add(nakedType(member['type'] as String));
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
  // Special case, converting to Dart strings from GDString or StringName
  final varName = escapeName(argument.name).toLowerCamelCase();
  var decl = 'final ${argument.dartType} $varName';
  if (argument.type == 'String') {
    o.p('final GDString gd$varName = GDString.copyPtr((args + $index).value);');
    o.p('$decl = gd$varName.toDartString();');
    return;
  } else if (argument.type == 'StringName') {
    o.p('final StringName gd$varName = StringName.copyPtr((args + $index).value);');
    o.p('$decl = GDString.fromStringName(gd$varName).toDartString();');
    return;
  }

  switch (argument.typeCategory) {
    case TypeCategory.engineClass:
      if (argument.isRefCounted) {
        o.p('$decl = ${argument.rawDartType}.fromOwner(gde.ffiBindings.gde_ref_get_object((args + $index).value));');
      } else {
        o.p('$decl = ${argument.rawDartType}.fromOwner((args + $index).cast<Pointer<Pointer<Void>>>().value.value);');
      }
      break;
    case TypeCategory.builtinClass:
      if (argument.type == 'Variant') {
        o.p('$decl = Variant.fromVariantPtr((args + $index).value);');
      } else {
        o.p('$decl = ${argument.rawDartType}.copyPtr((args + $index).value);');
      }
      break;
    case TypeCategory.primitive:
      final castType =
          argument.isPointer ? argument.dartType : getFFIType(argument);
      o.p('$decl = (args + $index).cast<Pointer<$castType>>().value.value;');
      break;
    case TypeCategory.nativeStructure:
      if (argument.isOptional) {
        o.p('final ${argument.name}Ptr = (args + $index).cast<Pointer<${argument.dartType}>>().value;');
        o.p('$decl = ${argument.name}Ptr == nullptr ? null : ${argument.name}Ptr.ref;');
      } else if (argument.isPointer) {
        o.p('$decl = (args + $index).cast<Pointer<${argument.dartType}>>().value.value;');
      } else {
        o.p('$decl = (args + $index).cast<Pointer<${argument.dartType}>>().value.ref;');
      }
      break;
    case TypeCategory.enumType:
      o.p('$decl = ${argument.dartType}.fromValue((args + $index).cast<Pointer<Uint32>>().value.value);');
      break;
    case TypeCategory.bitfieldType:
      o.p('$decl = (args + $index).cast<Pointer<Uint32>>().value.value;');
      break;
    case TypeCategory.typedArray:
      o.p('$decl = ${argument.dartType}.copyPtr((args + $index).value);');
      break;
    case TypeCategory.voidType:
      if (argument.dartType.startsWith('Pointer')) {
        o.p('$decl = (args + $index).value;');
      }
      break;
  }
}

void writePtrReturn(ArgumentProxy argument, CodeSink o) {
  if (argument.type == 'String') {
    o.p('final retGdString = GDString.fromString(ret);');
    o.p('retGdString.constructCopy(retPtr);');
    return;
  } else if (argument.type == 'StringName') {
    o.p('final retGdStringName = StringName.fromString(ret);');
    o.p('retGdStringName.constructCopy(retPtr);');
    return;
  }

  var ret = '';
  switch (argument.typeCategory) {
    case TypeCategory.engineClass:
      ret += 'retPtr.cast<GDExtensionTypePtr>().value = ';
      ret +=
          argument.isOptional ? 'ret?.nativePtr ?? nullptr' : 'ret.nativePtr';
      break;
    case TypeCategory.builtinClass:
      ret += 'ret.constructCopy(retPtr)';
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
      // TODO: Determine if enums and bitfields are variable width?
      ret += 'retPtr.cast<Uint32>().value = ret.value';
      break;
    case TypeCategory.bitfieldType:
      // TODO: Determine if enums and bitfields are variable width?
      ret += 'retPtr.cast<Uint32>().value = ret';
      break;
    case TypeCategory.typedArray:
      ret += 'ret.constructCopy(retPtr)';
      break;
    case TypeCategory.voidType:
      return;
  }

  o.p('$ret;');
}

void writeEnum(dynamic godotEnum, String? inClass, CodeSink o) {
  String name;
  List<Value> valueList;
  bool isBitfield = false;
  if (godotEnum is BuiltinClassEnum) {
    name = godotEnum.name;
    valueList = godotEnum.values;
  } else if (godotEnum is GlobalEnumElement) {
    name = godotEnum.name;
    valueList = godotEnum.values;
    isBitfield = godotEnum.isBitfield;
  } else {
    throw ArgumentError(
        'Trying to write an enum that is of type ${godotEnum.runtimeType}');
  }

  var enumName = getEnumName(name, inClass);
  o.b('enum $enumName {', () {
    if (isBitfield) {
      o.p('none(0),');
    }
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
