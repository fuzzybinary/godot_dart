// GENERATED FILE - DO NOT MODIFY

import 'package:godot_dart/godot_dart.dart';
import 'lib/game_logic.dart';
import 'lib/hud.dart';
import 'lib/mob.dart';
import 'lib/player.dart';

void attachScriptResolver() {
  final typeResolver = gde.typeResolver;
  typeResolver.addScriptType(
    'res://src/lib/game_logic.dart',
    GameLogic,
    GameLogic.sTypeInfo,
  );
  typeResolver.addScriptType('res://src/lib/hud.dart', Hud, Hud.sTypeInfo);
  typeResolver.addScriptType('res://src/lib/mob.dart', Mob, Mob.sTypeInfo);
  typeResolver.addScriptType(
    'res://src/lib/player.dart',
    Player,
    Player.sTypeInfo,
  );
}
