import 'dart:io';

import 'package:path/path.dart' as path;

import 'common_helpers.dart';
import 'gdstring_additional.dart';
import 'string_extensions.dart';
import 'type_helpers.dart';

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

  for (Map<String, dynamic> builtinApi in api.builtinClasses.values) {
    String className = builtinApi['name'];
    String correctedName = getCorrectedType(className);
    if (hasDartType(className)) {
      continue;
    }
    // Check for types we've implemented ourselves

    final size = builtinSizes[className]!;

    final destPath = path.join(targetDir, '${className.toSnakeCase()}.dart');
    final out = File(destPath).openWrite();

    out.write(header);

    // Imports
    writeImports(out, api, builtinApi, true);

    // Class
    out.write('''

class $correctedName extends BuiltinType {
  static const int _size = $size;
  static final _${className}Bindings _bindings = _${className}Bindings();
  static late TypeInfo typeInfo;
  
  @override
  TypeInfo get staticTypeInfo => typeInfo;
  
  final Pointer<Uint8> _opaque = calloc<Uint8>(_size);
  @override
  Pointer<Uint8> get nativePtr => _opaque;

  static void initBindingsConstructorDestructor() {
''');

    for (Map<String, dynamic> constructor in builtinApi['constructors']) {
      int index = constructor['index'];
      out.write(
          '''    _bindings.constructor_$index = gde.variantGetConstructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_${className.toUpperSnakeCase()}, $index);
''');
    }
    if (builtinApi['has_destructor'] == true) {
      out.write('''    _bindings.destructor = gde.variantGetDestructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_${className.toUpperSnakeCase()});
''');
    }

    out.write('''
}

  static void initBindings() {
    initBindingsConstructorDestructor();

    typeInfo = TypeInfo(StringName.fromString('$className'), 
      variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_${className.toUpperSnakeCase()});
''');
    out.write('    StringName name;\n');
    for (Map<String, dynamic> method in builtinApi['methods']) {
      var methodName = method['name'] as String;
      var dartMethodName = escapeMethodName(methodName);
      out.write('''    name = StringName.fromString('$methodName');\n''');
      out.write(
          '''    _bindings.method${dartMethodName.toUpperCamelCase()} = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_${className.toUpperSnakeCase()}, 
      name, 
      ${method['hash']},
    );
''');
    }

    out.write('  }\n');

    // Constructors
    for (Map<String, dynamic> constructor in builtinApi['constructors']) {
      int index = constructor['index'];
      final constructorName = getConstructorName(className, constructor);
      out.write('\n  $correctedName$constructorName(');
      final arguments =
          constructor['arguments'] as List<dynamic>? ?? <dynamic>[];
      if (arguments.isNotEmpty) {
        out.write('\n');
        // Parameter list
        for (Map<String, dynamic> argument in arguments) {
          final argumentDecl = getArgumentDeclaration(argument);
          out.write('    final $argumentDecl,\n');
        }
        out.write('  ) {\n');
      } else {
        out.write(') {\n');
      }

      withAllocationBlock(arguments, null, out, (ei) {
        out.write('''
    ${ei}gde.callBuiltinConstructor(_bindings.constructor_$index!, nativePtr.cast(), [
''');
        for (Map<String, dynamic> argument in arguments) {
          final name = escapeName(argument['name'] as String);
          if (argumentNeedsAllocation(argument)) {
            out.write('      $ei${name.toLowerCamelCase()}Ptr.cast(),\n');
          } else {
            out.write(
                '      $ei${name.toLowerCamelCase()}.nativePtr.cast(),\n');
          }
        }
        out.write('''
    $ei]); 
''');
      });

      out.write('  }\n');
    }

    if (className == 'String') {
      out.write(gdStringFromString());
    } else if (className == 'StringName') {
      out.write(stringNameFromString());
    }

    // Methods
    for (Map<String, dynamic> method in builtinApi['methods']) {
      var methodName = escapeMethodName(method['name'] as String);
      final signature = makeSignature(method);
      out.write('''
  $signature {
''');

      List<dynamic> arguments = method['arguments'] ?? <Map<String, dynamic>>[];

      final dartReturnType = getDartReturnType(method);
      if (dartReturnType != null) {
        out.write(
            '    $dartReturnType retVal = ${getDefaultValueForType(dartReturnType)};\n');
      }
      withAllocationBlock(arguments, dartReturnType, out, (ei) {
        bool extractReturnValue = false;
        if (dartReturnType != null) {
          extractReturnValue = writeReturnAllocation(api, dartReturnType, out);
        }
        final retParam = dartReturnType != null ? 'retPtr.cast()' : 'nullptr';
        final thisParam =
            method['is_static'] == true ? 'nullptr' : 'nativePtr.cast()';
        out.write('''
    ${ei}gde.callBuiltinMethodPtr(_bindings.method${methodName.toUpperCamelCase()}, $thisParam, $retParam, [
''');
        for (Map<String, dynamic> argument in arguments) {
          final name = escapeName(argument['name'] as String);
          if (argumentNeedsAllocation(argument)) {
            out.write('      $ei${name.toLowerCamelCase()}Ptr.cast(),\n');
          } else {
            out.write(
                '      $ei${name.toLowerCamelCase()}.nativePtr.cast(),\n');
          }
        }

        out.write('''
    $ei]);
''');
        if (dartReturnType != null && extractReturnValue) {
          out.write('      retVal = retPtr.value;\n');
        }
      });

      if (dartReturnType != null) {
        out.write('    return retVal;\n');
      }

      out.write('  }\n\n');
    }

    out.write('}\n');

    // Class Enums
    List<dynamic> enums = builtinApi['enums'] ?? <dynamic>[];
    for (Map<String, dynamic> classEnum in enums) {
      writeEnum(classEnum, className, out);
    }

    // Binding Class
    out.write('''

class _${className}Bindings {\n''');
    for (Map<String, dynamic> constructor in builtinApi['constructors']) {
      out.write(
          '''  GDExtensionPtrConstructor? constructor_${constructor['index']};\n''');
    }
    if (builtinApi['has_destructor'] == true) {
      out.write('''  GDExtensionPtrDestructor? destructor;\n''');
    }
    for (Map<String, dynamic> method in builtinApi['methods']) {
      var methodName = method['name'] as String;
      methodName = methodName.toUpperCamelCase();
      out.write('''  GDExtensionPtrBuiltInMethod? method$methodName;\n''');
    }
    out.write('}\n');

    await out.close();

    exportsString += "export '${className.toSnakeCase()}.dart';\n";
  }

  var exportsFile = File(path.join(targetDir, 'builtins.dart'));
  var out = exportsFile.openWrite();
  out.write(header);
  out.write(exportsString);

  await out.close();
}
