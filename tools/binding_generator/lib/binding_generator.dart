import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

import 'src/builtin_type_generator.dart';
import 'src/common_helpers.dart';
import 'src/engine_type_generator.dart';
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
  print('Generating builtins...\n');
  await generateBuiltinBindings(
      apiInfo, options.outputDirectory, options.buildConfig);

  print('Generating engine bindings...\n');
  await generateEngineBindings(
      apiInfo, options.outputDirectory, options.buildConfig);

  print('Generating global constants...\n');
  await generateGlobalConstants(
      apiInfo, options.outputDirectory, options.buildConfig);
}

Future<void> generateGlobalConstants(
    GodotApiInfo apiInfo, String outputDirectory, String buildConfig) async {
  final file = File(path.join(outputDirectory, 'global_constants.dart'));
  final out = file.openWrite();

  out.write(header);

  for (Map<String, dynamic> constant in apiInfo.raw['global_constants']) {
    final name = constant['name'] as String;
    out.write(
        'const int ${escapeName(name).toLowerCamelCase()} = ${constant['value']};\n');
  }

  out.write('\n');

  for (Map<String, dynamic> godotEnum in apiInfo.raw['global_enums']) {
    writeEnum(godotEnum, null, out);
  }

  await out.close();
}
