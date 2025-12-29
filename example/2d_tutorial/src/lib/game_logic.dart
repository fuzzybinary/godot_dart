import 'dart:math' as math;

import 'package:godot_dart/godot_dart.dart';

import 'hud.dart';
import 'mob.dart';
import 'player.dart';

part 'game_logic.g.dart';

@GodotScript()
class GameLogic extends Node {
  @pragma('vm:entry-point')
  static ExtensionTypeInfo<GameLogic> get sTypeInfo => _$GameLogicTypeInfo();

  @override
  ExtensionTypeInfo<GameLogic> get typeInfo => GameLogic.sTypeInfo;

  @GodotProperty()
  PackedScene? mobScene;

  var _score = 0;
  final _random = math.Random();

  GameLogic() : super();

  GameLogic.withNonNullOwner(super.owner)
      : super.withNonNullOwner();

  @override
  void vReady() {}

  @override
  void vProcess(double delta) {}

  @GodotExport()
  void gameOver() {
    getNodeT<Timer>('ScoreTimer')?.stop();
    getNodeT<Timer>('MobTimer')?.stop();

    getNodeT<Hud>('HUD')?.showGameOver();

    getTree()?.callGroup('mobs', 'queue_free');
    getNodeT<AudioStreamPlayer>('Music')?.stop();
    getNodeT<AudioStreamPlayer>('DeathSound')?.play();
  }

  @GodotExport()
  void newGame() {
    _score = 0;
    var startPosition = getNodeT<Marker2D>('StartPosition')!;
    var player = getNodeT<Player>();

    player?.start(startPosition.getPosition());

    getNodeT<Timer>('StartTimer')?.start();

    final hud = getNodeT<Hud>('HUD');
    hud?.updateScore(_score);
    hud?.showMessage('Get Ready!');

    getNodeT<AudioStreamPlayer>('Music')?.play();
  }

  @GodotExport()
  void onScoreTimerTimeout() {
    _score++;
    getNodeT<Hud>('HUD')?.updateScore(_score);
  }

  @GodotExport()
  void onStartTimerTimeout() {
    getNodeT<Timer>('MobTimer')?.start();
    getNodeT<Timer>('ScoreTimer')?.start();
  }

  @GodotExport()
  void onMobTimerTimeout() {
    final mob = mobScene?.instantiate()?.as<Mob>();
    if (mob != null) {
      var mobSpawnLocation =
          getNodeT<PathFollow2D>('MobPath/MobSpawnLocation')!;
      mobSpawnLocation.setProgressRatio(_random.nextDouble());

      var direction = mobSpawnLocation.getRotation() + math.pi / 2;

      mob.setPosition(mobSpawnLocation.getPosition());

      direction += -(math.pi / 4) + _random.nextDouble() * (math.pi / 2);
      mob.setRotation(direction);

      var velocity = Vector2.fromXY(150 + _random.nextDouble() * 100, 0);
      velocity = velocity.rotated(direction);
      mob.setLinearVelocity(velocity);

      addChild(mob);
    }
  }
}
