library godot_dart_builder.builder;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/godot_dart_generator.dart';

Builder godotDartBuilder(BuilderOptions options) {
  return SharedPartBuilder(
    [
      GodotDartGenerator(),
    ],
    'godot_dart_builder',
  );
}
