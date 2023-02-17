import 'package:binding_generator/binding_generator.dart';

void main(List<String> arguments) {
  generate(GenerationOptions(
    apiJsonLocation: '../../godot-headers/godot/extension_api.json',
    outputDirectory: '../../src/dart/lib/src/gen',
    buildConfig: 'float_32',
  ));
}
