import 'dart:ffi';

import 'package:godot_dart/godot_dart.dart';

class Player extends Area2D {
  // This is necessary boilerplate at the moment
  static TypeInfo sTypeInfo = TypeInfo(
    Player,
    StringName.fromString('Player'),
    parentClass: Area2D.sTypeInfo.className,
  );
  static Map<String, Pointer<GodotVirtualFunction>> get vTable => Area2D.vTable;
  static final Map<String, MethodInfo> _methodTable = {
    '_ready': MethodInfo(
      methodName: '_ready',
      dartMethodName: 'vReady',
      arguments: [],
    ),
    '_process': MethodInfo(
      methodName: '_process',
      dartMethodName: 'vProcess',
      arguments: [TypeInfo.forType(double)!],
    ),
  };

  @override
  TypeInfo get typeInfo => sTypeInfo;

  Player() : super() {
    postInitialize();
  }

  Player.withNonNullOwner(Pointer<Void> owner) : super.withNonNullOwner(owner);

  final _speed = 400;
  late Vector2 _screenSize;

  @override
  void vReady() {
    _screenSize = getViewportRect().size;
  }

  @override
  void vProcess(double delta) {
    var velocity = Vector2.fromXY(0, 0);
    var input = Input.singleton;
    if (input.isActionPressed(StringName.fromString('move_right'), false)) {
      velocity.x += 1;
    }
    if (input.isActionPressed(StringName.fromString('move_left'), false)) {
      velocity.x -= 1;
    }
    if (input.isActionPressed(StringName.fromString('move_down'), false)) {
      velocity.y += 1;
    }
    if (input.isActionPressed(StringName.fromString('move_up'), false)) {
      velocity.y -= 1;
    }

    if (velocity.length() > 0) {
      velocity = velocity.normalized();
      velocity.x *= _speed;
      velocity.y *= _speed;
      getNodeT<AnimatedSprite2D>(AnimatedSprite2D.sTypeInfo)
          ?.play(StringName.fromString(''), 1.0, false);
    } else {
      getNodeT<AnimatedSprite2D>(AnimatedSprite2D.sTypeInfo)?.stop();
    }

    var position = getPosition();
    position.x = (position.x + velocity.x * delta).clamp(0, _screenSize.x);
    position.y = (position.y + velocity.y * delta).clamp(0, _screenSize.y);
    setPosition(position);
  }

  @override
  MethodInfo? getMethodInfo(String methodName) {
    return _methodTable[methodName];
  }
}

extension TNode on Node {
  T? getNodeT<T>(TypeInfo typeInfo) {
    final name = GDString.fromStringName(typeInfo.className);
    var node = getNode(NodePath.fromGDString(name));
    return gde.cast<T>(node, typeInfo);
  }
}
