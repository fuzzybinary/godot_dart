import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'src/code_sink.dart';
import 'src/common_helpers.dart';
import 'src/generators/builtin_type_generator.dart';
import 'src/generators/engine_type_generator.dart';
import 'src/generators/native_structures_generator.dart';
import 'src/godot_api_info.dart';
import 'src/string_extensions.dart';
import 'src/type_helpers.dart';

class GenerationOptions {
  final String apiJsonLocation;
  final String outputDirectory;
  final String buildConfig;

  GenerationOptions({
    required this.apiJsonLocation,
    required this.outputDirectory,
    required this.buildConfig,
  });
}

Future<void> generate(GenerationOptions options) async {
  var file = File(options.apiJsonLocation);
  if (!file.existsSync()) {
    print("Couldn't find file: ${file.path}");
    return;
  }
  var directory = Directory(options.outputDirectory);
  if (!directory.existsSync()) {
    await directory.create(recursive: true);
  }

  var jsonString = await file.readAsString();

  var jsonApi = json.decode(jsonString) as Map<String, dynamic>;

  // TODO: Remove Output Directory
  final apiInfo = GodotApiInfo.fromJson(jsonApi);
  print('Generating builtins...');
  await generateBuiltinBindings(
      apiInfo, options.outputDirectory, options.buildConfig);

  print('Generating engine bindings...');
  await generateEngineBindings(
      apiInfo, options.outputDirectory, options.buildConfig);

  print('Generating global constants...');
  await generateGlobalConstants(
      apiInfo, options.outputDirectory, options.buildConfig);

  print('Generating utility functions...');
  await generateUtilityFunctions(
      apiInfo, options.outputDirectory, options.buildConfig);

  print('Generating native structures...');
  await generateNativeStructures(
      apiInfo, options.outputDirectory, options.buildConfig);
}

Future<void> generateGlobalConstants(
    GodotApiInfo apiInfo, String outputDirectory, String buildConfig) async {
  final file = File(path.join(outputDirectory, 'global_constants.dart'));
  final o = CodeSink(file);

  o.write(header);

  final globalConstants = apiInfo.api.globalConstants;
  for (Map<String, dynamic> constant
      in globalConstants.map((e) => e as Map<String, dynamic>)) {
    final name = constant['name'] as String;
    o.p('const int ${escapeName(name).toLowerCamelCase()} = ${constant['value']};');
  }
  o.nl();

  for (final godotEnum in apiInfo.api.globalEnums) {
    writeEnum(godotEnum, null, o);
  }

  await o.close();
}

Future<void> generateUtilityFunctions(
    GodotApiInfo apiInfo, String outputDirectory, String buildConfig) async {
  final file = File(path.join(outputDirectory, 'utility_functions.dart'));
  final o = CodeSink(file);

  o.p(header);
  o.p("import 'dart:ffi';");
  o.nl();
  o.p("import 'package:ffi/ffi.dart';");
  o.nl();
  o.p("import '../core/gdextension_ffi_bindings.dart';");
  o.p("import '../core/gdextension.dart';");
  o.p("import '../variant/variant.dart';");
  o.p("import 'classes/object.dart';");
  o.p("import 'variant/packed_int64_array.dart';");
  o.p("import 'variant/packed_byte_array.dart';");
  o.p("import 'variant/rid.dart';");
  o.p("import 'variant/string.dart';");
  o.p("import 'variant/string_name.dart';");

  o.nl();
  o.b('class GD {', () {
    // Functions
    for (final utilityFunction in apiInfo.api.utilityFunctions) {
      final methodSignature = makeSignature(utilityFunction);
      o.b('$methodSignature {', () {
        final arguments =
            utilityFunction.arguments?.map((e) => e.proxy).toList() ?? [];
        final returnInfo =
            ArgumentProxy.fromReturnType(utilityFunction.returnType);
        final hasReturn = returnInfo.typeCategory != TypeCategory.voidType;
        final retString = hasReturn ? 'return ' : '';
        o.b('${retString}using((arena) {', () {
          final argumentsVar = createPtrcallArguments(o, arguments);

          if (hasReturn) {
            writeReturnAllocation(returnInfo, o);
          }

          final returnPtr = hasReturn ? 'retPtr.cast()' : 'nullptr.cast()';

          o.p('void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>, int) m =');
          o.p('  _bindings.${utilityFunction.name}Func!.asFunction();');
          o.p('m($returnPtr, $argumentsVar, ${arguments.length});');

          if (hasReturn) {
            writeReturnRead(returnInfo, o);
          }
        }, '});');
      }, '}');
      o.nl();
    }
    o.nl();

    // Binding init
    o.p('static final _bindings = _UtilityFunctionBindings();');
    o.b('static initBindings() {', () {
      o.p('final ffi = gde.ffiBindings;');
      for (final utilityFunction in apiInfo.api.utilityFunctions) {
        final name = utilityFunction.name;
        o.p("_bindings.${name}Func = ffi.gde_variant_get_ptr_utility_function(StringName.fromString('$name').nativePtr.cast(), ${utilityFunction.hash});");
      }
    }, '}');
  }, '}');

  // Binding class
  o.b('class _UtilityFunctionBindings {', () {
    for (final utilityFunction in apiInfo.api.utilityFunctions) {
      final name = utilityFunction.name;
      o.p('GDExtensionPtrUtilityFunction? ${name}Func;');
    }
  }, '}');
  o.nl();
}
