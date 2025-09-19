import 'dart:ffi';
import 'dart:math';

import 'package:godot_dart/godot_dart.dart';

part 'mob.g.dart';

@GodotScript()
class Mob extends RigidBody2D {
  static ExtensionTypeInfo<Mob> get sTypeInfo => _$MobTypeInfo();

  @override
  @pragma('vm:entry-point')
  ExtensionTypeInfo<Mob> get typeInfo => Mob.sTypeInfo;

  final _random = Random();

  Mob() : super();

  Mob.withNonNullOwner(Pointer<Void> owner) : super.withNonNullOwner(owner);

  @override
  void vReady() {
    final anim = getNodeT<AnimatedSprite2D>();
    final mobTypes = anim?.getSpriteFrames()?.getAnimationNames();
    if (mobTypes != null) {
      var animName = mobTypes[_random.nextInt(mobTypes.size())];
      anim?.play(name: animName);
    }
  }

  @override
  void vProcess(double delta) {}

  @GodotExport()
  void onVisibleOnScreenNotifier2dScreenExited() {
    queueFree();
  }
}
