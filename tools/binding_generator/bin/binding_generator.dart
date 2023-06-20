import 'package:binding_generator/binding_generator.dart';

void main(List<String> arguments) {
  generate(GenerationOptions(
    apiJsonLocation: '../../godot-headers/godot/extension_api.json',
    outputDirectory: '../../src/dart/godot_dart/lib/src/gen',
    buildConfig: 'float_64',
  ));
}
