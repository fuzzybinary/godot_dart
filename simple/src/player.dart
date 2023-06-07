import 'dart:ffi';

import 'package:collection/collection.dart';
import 'package:godot_dart/godot_dart.dart';

class Player extends Area2D {
  // This is necessary boilerplate at the moment
  static TypeInfo sTypeInfo = TypeInfo(
    Player,
    StringName.fromString('Player'),
    parentClass: Area2D.sTypeInfo.className,
    bindingToken: gde.dartBindings.toPersistentHandle(Player),
  );
  static Map<String, Pointer<GodotVirtualFunction>> get vTable => Area2D.vTable;
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
        name: 'onBodyEntered',
        args: [PropertyInfo(typeInfo: Node2D.sTypeInfo, name: 'body')],
      ),
    ],
    signals: [MethodInfo(name: 'hit', args: [])],
    properties: [
      PropertyInfo(typeInfo: TypeInfo.forType(int)!, name: 'speed'),
    ],
  );

  @override
  TypeInfo get typeInfo => sTypeInfo;

  Player() : super() {
    postInitialize();
  }

  Player.withNonNullOwner(Pointer<Void> owner) : super.withNonNullOwner(owner);

  late final Signal _hit = Signal.fromObjectSignal(this, 'hit');
  var speed = 400;
  late Vector2 _screenSize;

  @override
  void vReady() {
    hide();
    _screenSize = getViewportRect().size;
  }

  @override
  void vProcess(double delta) {
    var velocity = Vector2.fromXY(0, 0);
    var input = Input.singleton;
    if (input.isActionPressed('move_right', false)) {
      velocity.x += 1;
    }
    if (input.isActionPressed('move_left', false)) {
      velocity.x -= 1;
    }
    if (input.isActionPressed('move_down', false)) {
      velocity.y += 1;
    }
    if (input.isActionPressed('move_up', false)) {
      velocity.y -= 1;
    }

    final animatedSprite = getNodeT<AnimatedSprite2D>();

    if (velocity.length() > 0) {
      velocity = velocity.normalized();
      velocity.x *= speed;
      velocity.y *= speed;
      animatedSprite?.play('', 1.0, false);

      if (velocity.x != 0) {
        animatedSprite?.setAnimation('walk');
        animatedSprite?.setFlipV(false);
        animatedSprite?.setFlipH(velocity.x < 0);
      } else if (velocity.y != 0) {
        animatedSprite?.setAnimation('up');
        animatedSprite?.setFlipV(velocity.y > 0);
      }
    } else {
      getNodeT<AnimatedSprite2D>()?.stop();
    }

    var position = getPosition();
    position.x = (position.x + velocity.x * delta).clamp(0, _screenSize.x);
    position.y = (position.y + velocity.y * delta).clamp(0, _screenSize.y);
    setPosition(position);
  }

  void start(Vector2 pos) {
    setPosition(pos);
    show();
    getNodeT<CollisionShape2D>()?.setDisabled(false);
  }

  void onBodyEntered(Node2D body) {
    _hit.emit();
    hide();
    getNodeT<CollisionShape2D>()
        ?.setDeferred('disabled', convertToVariant(true));
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
