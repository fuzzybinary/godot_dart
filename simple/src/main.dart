import 'package:godot_dart/godot_dart.dart';

import 'player.dart';
import 'simple.dart';

void main() {
  Simple.bind();
  DartScriptLanguage.singleton.addScript('res://src/player.dart', Player);
}
