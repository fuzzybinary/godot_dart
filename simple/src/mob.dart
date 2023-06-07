import 'dart:ffi';
import 'dart:math';

import 'package:collection/collection.dart';
import 'package:godot_dart/godot_dart.dart';

class Mob extends RigidBody2D {
  // This is necessary boilerplate at the moment
  static TypeInfo sTypeInfo = TypeInfo(
    Mob,
    StringName.fromString('Mob'),
    parentClass: RigidBody2D.sTypeInfo.className,
    bindingToken: gde.dartBindings.toPersistentHandle(Mob),
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

  @override
  MethodInfo? getMethodInfo(String methodName) {
    return sScriptInfo.methods.firstWhereOrNull((e) => e.name == methodName);
  }

  @override
  PropertyInfo? getPropertyInfo(String propertyName) {
    return sScriptInfo.properties
        .firstWhereOrNull((e) => e.name == propertyName);
  }
}
