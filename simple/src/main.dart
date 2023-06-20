import 'package:godot_dart/godot_dart.dart';

import 'lib/game_logic.dart';
import 'lib/hud.dart';
import 'lib/mob.dart';
import 'lib/player.dart';
import 'simple.dart';

void main() {
  Simple.bind();

  DartScriptLanguage.singleton.addScript('res://src/lib/player.dart', Player);
  DartScriptLanguage.singleton.addScript('res://src/lib/mob.dart', Mob);
  DartScriptLanguage.singleton
      .addScript('res://src/lib/game_logic.dart', GameLogic);
  DartScriptLanguage.singleton.addScript('res://src/lib/hud.dart', Hud);
}
