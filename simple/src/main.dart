import 'package:godot_dart/godot_dart.dart';

import 'game_logic.dart';
import 'mob.dart';
import 'player.dart';
import 'simple.dart';

void main() {
  Simple.bind();
  DartScriptLanguage.singleton.addScript('res://src/player.dart', Player);
  DartScriptLanguage.singleton.addScript('res://src/mob.dart', Mob);
  DartScriptLanguage.singleton
      .addScript('res://src/game_logic.dart', GameLogic);
}
