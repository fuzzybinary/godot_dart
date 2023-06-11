import 'dart:ffi';
import 'dart:math';

import 'package:godot_dart/godot_dart.dart';

class Mob extends RigidBody2D with GodotScriptMixin {
  // This is necessary boilerplate at the moment
  static TypeInfo sTypeInfo = TypeInfo(
    Mob,
    StringName.fromString('Mob'),
    parentClass: RigidBody2D.sTypeInfo.className,
  );
  static Map<String, Pointer<GodotVirtualFunction>> get vTable =>
      RigidBody2D.vTable;
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
        name: 'onVisibleOnScreenNotifier2dScreenExited',
        args: [],
      ),
    ],
    signals: [],
    properties: [],
  );
  @override
  ScriptInfo get scriptInfo => sScriptInfo;

  @override
  TypeInfo get typeInfo => sTypeInfo;

  final _random = Random();

  Mob() : super() {
    postInitialize();
  }

  Mob.withNonNullOwner(Pointer<Void> owner) : super.withNonNullOwner(owner);

  @override
  void vReady() {
    final anim = getNodeT<AnimatedSprite2D>();
    final mobTypes = anim?.getSpriteFrames().obj?.getAnimationNames();
    if (mobTypes != null) {
      var animName = mobTypes[_random.nextInt(mobTypes.size())];
      anim?.play(animName, 1.0, false);
    }
  }

  @override
  void vProcess(double delta) {}

  void onVisibleOnScreenNotifier2dScreenExited() {
    queueFree();
  }
}
