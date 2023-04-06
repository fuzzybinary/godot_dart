import 'dart:io';

import 'package:path/path.dart' as path;

import '../common_helpers.dart';
import '../gdstring_additional.dart';
import '../godot_api_info.dart';
import '../string_extensions.dart';
import '../type_helpers.dart';
import '../type_info.dart';

Future<void> generateBuiltinBindings(
  GodotApiInfo api,
  String targetDir,
  String buildConfig,
) async {
  targetDir = path.join(targetDir, 'variant');
  var directory = Directory(targetDir);
  if (!directory.existsSync()) {
    await directory.create(recursive: true);
  }

  // Holds all the exports an initializations for the builtins, written as
  // 'builtins.dart' at the end of generation
  var exportsString = '';

  var builtinSizes = <String, int>{};

  for (Map<String, dynamic> sizeList in api.raw['builtin_class_sizes']) {
    if (sizeList['build_configuration'] == buildConfig) {
      for (Map<String, dynamic> size in sizeList['sizes']) {
        builtinSizes[size['name']] = size['size'];
      }
    }
  }

  for (final builtin in api.builtinClasses.values) {
    if (hasDartType(builtin.godotType)) {
      continue;
    }
    // Check for types we've implemented ourselves

    final size = builtinSizes[builtin.godotType]!;

    final destPath =
        path.join(targetDir, '${builtin.godotType.toSnakeCase()}.dart');
    final out = File(destPath).openWrite();

    out.write(header);

    // Imports
    writeImports(out, api, builtin.api, true);

    // Class
    out.write('''

class ${builtin.dartType} extends BuiltinType {
  static const int _size = $size;
  static final _${builtin.godotType}Bindings _bindings = _${builtin.godotType}Bindings();
  static late TypeInfo typeInfo;
  
  @override
  TypeInfo get staticTypeInfo => typeInfo;
  
  final Pointer<Uint8> _opaque = calloc<Uint8>(_size);

  @override
  Pointer<Uint8> get nativePtr => _opaque;

  static void initBindingsConstructorDestructor() {
''');

    for (Map<String, dynamic> constructor in builtin.api['constructors']) {
      int index = constructor['index'];
      out.write('''    _bindings.constructor_$index = gde.variantGetConstructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_${builtin.godotType.toUpperSnakeCase()}, $index);
''');
    }
    if (builtin.api['has_destructor'] == true) {
      out.write('''    _bindings.destructor = gde.variantGetDestructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_${builtin.godotType.toUpperSnakeCase()});
''');
    }

    out.write('''
}

  static void initBindings() {
    initBindingsConstructorDestructor();

    typeInfo = TypeInfo(
      StringName.fromString('${builtin.godotType}'), 
      variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_${builtin.godotType.toUpperSnakeCase()},
      size: _size,
    );
''');

    final members = builtin.api['members'] as List<dynamic>? ?? <dynamic>[];
    for (Map<String, dynamic> member in members) {
      var memberName = member['name'] as String;
      out.write(
          '''  _bindings.member${memberName.toUpperCamelCase()}Getter = gde.variantGetPtrGetter(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_${builtin.godotType.toUpperSnakeCase()},
        StringName.fromString('$memberName'),
      );''');
      out.write(
          '''  _bindings.member${memberName.toUpperCamelCase()}Setter = gde.variantGetPtrSetter(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_${builtin.godotType.toUpperSnakeCase()},
        StringName.fromString('$memberName'),
      );''');
    }

    for (Map<String, dynamic> method in builtin.api['methods']) {
      var methodName = method['name'] as String;
      var dartMethodName = escapeMethodName(methodName);
      out.write(
          '''    _bindings.method${dartMethodName.toUpperCamelCase()} = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_${builtin.godotType.toUpperSnakeCase()}, 
      StringName.fromString('$methodName'), 
      ${method['hash']},
    );
''');
    }

    out.write('  }\n');

    // Constructors
    out.write('''
  ${builtin.dartType}.fromPointer(Pointer<Void> ptr) {
    gde.dartBindings.variantCopyFromNative(this, ptr);
  }
''');

    for (Map<String, dynamic> constructor in builtin.api['constructors']) {
      int index = constructor['index'];
      final constructorName =
          getConstructorName(builtin.godotType, constructor);
      out.write('\n  ${builtin.dartType}$constructorName(');
      final arguments =
          (constructor['arguments'] as List<dynamic>? ?? <dynamic>[])
              .map((dynamic e) => api.getArgumentInfo(e))
              .toList();
      if (arguments.isNotEmpty) {
        out.write('\n');
        // Parameter list
        for (final argument in arguments) {
          out.write('    final ${argument.fullDartType} ${argument.name},\n');
        }
        out.write('  ) {\n');
      } else {
        out.write(') {\n');
      }

      withAllocationBlock(arguments, null, out, (ei) {
        out.write('''
    ${ei}gde.callBuiltinConstructor(_bindings.constructor_$index!, nativePtr.cast(), [
''');
        for (final argument in arguments) {
          if (argument.needsAllocation) {
            out.write('      $ei${argument.name}Ptr.cast(),\n');
          } else if (argument.isOptional) {
            out.write(
                '      $ei${argument.name}?.nativePtr.cast() ?? nullptr,\n');
          } else {
            out.write('      $ei${argument.name}.nativePtr.cast(),\n');
          }
        }
        out.write('''
    $ei]); 
''');
      });

      out.write('  }\n');
    }

    if (builtin.godotType == 'String') {
      out.write(gdStringFromString());
      out.write(gdStringToDartString());
    } else if (builtin.godotType == 'StringName') {
      out.write(stringNameFromString());
    }

    // Members
    for (Map<String, dynamic> member in members) {
      final memberInfo = api.getMemberInfo(member);
      out.write('''

  ${memberInfo.dartType} get ${memberInfo.name} {
''');
      if (memberInfo.typeInfo.godotType == 'String') {
        out.write('    GDString retVal = GDString();\n');
      } else {
        out.write(
            '    ${memberInfo.dartType} retVal = ${getDefaultValueForAgument(memberInfo)};\n');
      }
      withAllocationBlock([], memberInfo, out, (ei) {
        bool extractReturnValue = writeReturnAllocation(api, memberInfo, out);
        out.write('''
    ${ei}final f = _bindings.member${memberInfo.name!.toUpperCamelCase()}Getter!.asFunction<void Function(GDExtensionConstTypePtr, GDExtensionTypePtr)>(isLeaf: true);
    ${ei}f(nativePtr.cast(), retPtr.cast());
''');
        if (extractReturnValue) {
          if (memberInfo.typeInfo.typeCategory == TypeCategory.engineClass) {
            out.write(
                '      retVal = retPtr == nullptr ? null : ${memberInfo.dartType}.fromOwner(retPtr.value);\n');
          } else {
            out.write('      retVal = retPtr.value;\n');
          }
        }
      });

      if (memberInfo.typeInfo.godotType == 'String') {
        out.write('    return retVal.toDartString();\n');
      } else {
        out.write('    return retVal;\n');
      }
      out.write('''
  }
''');

      out.write('''

  set ${memberInfo.name}(${memberInfo.dartType} value) {
''');
      withAllocationBlock([memberInfo], null, out, (ei) {
        String valueCast;
        if (memberInfo.needsAllocation) {
          valueCast = '${memberInfo.name}Ptr.cast()';
        } else if (memberInfo.typeInfo.godotType == 'String') {
          valueCast =
              'GDString.fromString(${memberInfo.name}).nativePtr.cast()';
        } else if (memberInfo.isOptional) {
          valueCast = '${memberInfo.name}?.nativePtr.cast() ?? nullptr';
        } else {
          valueCast = '${memberInfo.name}.nativePtr.cast()';
        }
        out.write('''
    ${ei}final f = _bindings.member${memberInfo.name!.toUpperCamelCase()}Setter!.asFunction<void Function(GDExtensionConstTypePtr, GDExtensionTypePtr)>(isLeaf: true);
    ${ei}f(nativePtr.cast(), $valueCast);
''');
      });

      out.write('''
  }
''');
    }

    // Methods
    for (Map<String, dynamic> method in builtin.api['methods']) {
      var methodName = escapeMethodName(method['name'] as String);
      final signature = makeSignature(api, method);
      out.write('''
  $signature {
''');

      final arguments = (method['arguments'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => api.getArgumentInfo(e))
          .toList();

      final retInfo = api.getReturnInfo(method);
      if (retInfo.typeInfo.typeCategory != TypeCategory.voidType) {
        if (retInfo.typeInfo.godotType == 'String') {
          out.write('    GDString retVal = GDString();\n');
        } else {
          out.write(
              '    ${retInfo.fullDartType} retVal = ${getDefaultValueForAgument(retInfo)};\n');
        }
      }
      withAllocationBlock(arguments, retInfo, out, (ei) {
        bool extractReturnValue = false;
        if (retInfo.typeInfo.typeCategory != TypeCategory.voidType) {
          extractReturnValue = writeReturnAllocation(api, retInfo, out);
        }
        final retParam = retInfo.typeInfo.typeCategory == TypeCategory.voidType
            ? 'nullptr'
            : 'retPtr.cast()';
        final thisParam =
            method['is_static'] == true ? 'nullptr' : 'nativePtr.cast()';
        out.write('''
    ${ei}gde.callBuiltinMethodPtr(_bindings.method${methodName.toUpperCamelCase()}, $thisParam, $retParam, [
''');
        for (final argument in arguments) {
          if (argument.needsAllocation) {
            out.write('      $ei${argument.name}Ptr.cast(),\n');
          } else if (argument.isOptional) {
            out.write(
                '      $ei${argument.name}?.nativePtr.cast() ?? nullptr,\n');
          } else {
            out.write('      $ei${argument.name}.nativePtr.cast(),\n');
          }
        }

        out.write('''
    $ei]);
''');
        if (retInfo.typeInfo.typeCategory != TypeCategory.voidType &&
            extractReturnValue) {
          if (retInfo.typeInfo.typeCategory == TypeCategory.engineClass) {
            out.write(
                '      retVal = retPtr == nullptr ? null : ${retInfo.dartType}.fromOwner(retPtr.value);\n');
          } else {
            out.write('      retVal = retPtr.value;\n');
          }
        }
      });

      if (retInfo.typeInfo.typeCategory != TypeCategory.voidType) {
        if (retInfo.typeInfo.godotType == 'String') {
          out.write('    return retVal.toDartString();\n');
        } else {
          out.write('    return retVal;\n');
        }
      }

      out.write('  }\n\n');
    }

    out.write('}\n');

    // Class Enums
    List<dynamic> enums = builtin.api['enums'] ?? <dynamic>[];
    for (Map<String, dynamic> classEnum in enums) {
      writeEnum(classEnum, builtin.godotType, out);
    }

    // Binding Class
    out.write('''

class _${builtin.godotType}Bindings {\n''');
    for (Map<String, dynamic> constructor in builtin.api['constructors']) {
      out.write(
          '''  GDExtensionPtrConstructor? constructor_${constructor['index']};\n''');
    }
    if (builtin.api['has_destructor'] == true) {
      out.write('''  GDExtensionPtrDestructor? destructor;\n''');
    }
    for (Map<String, dynamic> member in members) {
      var memberName = member['name'] as String;
      memberName = memberName.toUpperCamelCase();
      out.write('''  GDExtensionPtrGetter? member${memberName}Getter;\n''');
      out.write('''  GDExtensionPtrSetter? member${memberName}Setter;\n''');
    }
    for (Map<String, dynamic> method in builtin.api['methods']) {
      var methodName = method['name'] as String;
      methodName = methodName.toUpperCamelCase();
      out.write('''  GDExtensionPtrBuiltInMethod? method$methodName;\n''');
    }
    out.write('}\n');

    await out.close();

    exportsString += "export '${builtin.godotType.toSnakeCase()}.dart';\n";
  }

  var exportsFile = File(path.join(targetDir, 'builtins.dart'));
  var out = exportsFile.openWrite();
  out.write(header);
  out.write(exportsString);

  await out.close();
}
