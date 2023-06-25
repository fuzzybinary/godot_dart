library godot_dart_builder.builder;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/godot_dart_generator.dart';
import 'src/godot_script_generator.dart';

Builder godotDartBuilder(BuilderOptions options) {
  return SharedPartBuilder(
    [
      GodotScriptAnnotationGenerator(),
    ],
    'godot_dart_builder',
  );
}

// Generate the file that holds the filename -> type mapping
Builder godotDartIndex(BuilderOptions options) {
  return GodotDartBuilder();
}
