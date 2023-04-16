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

const String templateLocation = 'lib/src/templates';

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

  print('Generating native structures...');
  await generateNativeStructures(
      apiInfo, options.outputDirectory, options.buildConfig);
}

Future<void> generateGlobalConstants(
    GodotApiInfo apiInfo, String outputDirectory, String buildConfig) async {
  final file = File(path.join(outputDirectory, 'global_constants.dart'));
  final o = CodeSink(file);

  o.write(header);

  for (Map<String, dynamic> constant in apiInfo.api.globalConstants) {
    final name = constant['name'] as String;
    o.p('const int ${escapeName(name).toLowerCamelCase()} = ${constant['value']};');
  }
  o.nl();

  for (final godotEnum in apiInfo.api.globalEnums) {
    writeEnum(godotEnum, null, o);
  }

  await o.close();
}
