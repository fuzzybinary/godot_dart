import 'package:godot_dart/godot_dart.dart';

import 'godot_dart_scripts.g.dart';
import 'lib/simple.dart';

void main() {
  Simple.bind();

  attachScriptResolver(DartScriptLanguage.singleton);
}
