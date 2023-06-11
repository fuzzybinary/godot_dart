import 'dart:ffi';
import 'dart:math' as math;

import 'package:godot_dart/godot_dart.dart';

import 'mob.dart';
import 'player.dart';

class GameLogic extends Node with GodotScriptMixin {
  // This is necessary boilerplate at the moment
  static TypeInfo sTypeInfo = TypeInfo(
    GameLogic,
    StringName.fromString('GameLogic'),
    parentClass: Node.sTypeInfo.className,
  );
  static Map<String, Pointer<GodotVirtualFunction>> get vTable => Node.vTable;
  static final sScriptInfo = ScriptInfo(
    methods: [
      MethodInfo(
        name: '_ready',
        dartMethodName: 'vReady',
        args: [],
      ),
      MethodInfo(
        name: '_process',
        dartMethodName: 'vProcess',
        args: [
          PropertyInfo(typeInfo: TypeInfo.forType(double)!, name: 'delta'),
        ],
      ),
      MethodInfo(
        name: 'onStartTimerTimeout',
        args: [],
      ),
      MethodInfo(
        name: 'onScoreTimerTimeout',
        args: [],
      ),
      MethodInfo(
        name: 'onMobTimerTimeout',
        args: [],
      ),
    ],
    signals: [],
    properties: [
      PropertyInfo(typeInfo: PackedScene.sTypeInfo, name: 'mobScene'),
    ],
  );
  @override
  ScriptInfo get scriptInfo => sScriptInfo;

  @override
  TypeInfo get typeInfo => sTypeInfo;

  PackedScene? mobScene;
  var score = 0;
  final _random = math.Random();

  GameLogic() : super() {
    postInitialize();
  }

  GameLogic.withNonNullOwner(Pointer<Void> owner)
      : super.withNonNullOwner(owner);

  @override
  void vReady() {
    newGame();
  }

  @override
  void vProcess(double delta) {}

  void gameOver() {
    getNodeT<Timer>('ScoreTimer')?.stop();
    getNodeT<Timer>('MobTimer')?.stop();
  }

  void newGame() {
    score = 0;
    var startPosition = getNodeT<Marker2D>('StartPosition')!;
    var player = getNodeT<Player>();
    print('Got Player: $player');
    player?.start(startPosition.getPosition());

    getNodeT<Timer>('StartTimer')?.start(-1);
  }

  void onScoreTimerTimeout() {
    score++;
  }

  void onStartTimerTimeout() {
    getNodeT<Timer>('MobTimer')?.start(-1);
    getNodeT<Timer>('ScoreTimer')?.start(-1);
  }

  void onMobTimerTimeout() {
    final mob = gde.cast<Mob>(
      mobScene?.instantiate(PackedSceneGenEditState.genEditStateDisabled),
    );
    if (mob != null) {
      var mobSpawnLocation =
          getNodeT<PathFollow2D>('MobPath/MobSpawnLocation')!;
      mobSpawnLocation.setProgressRatio(_random.nextDouble());

      var direction = mobSpawnLocation.getRotation() + math.pi / 2;

      mob.setPosition(mobSpawnLocation.getPosition());

      direction += (math.pi / 4) + _random.nextDouble() * (math.pi / 2);
      mob.setRotation(direction);

      var velocity = Vector2.fromXY(150 + _random.nextDouble() * 100, 0);
      velocity = velocity.rotated(direction);
      mob.setLinearVelocity(velocity);

      addChild(mob, false, NodeInternalMode.internalModeDisabled);
    }
  }
}
