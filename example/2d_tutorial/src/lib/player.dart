import 'dart:ffi';

import 'package:godot_dart/godot_dart.dart';

part 'player.g.dart';

@GodotScript()
class Player extends Area2D {
  @pragma('vm:entry-point')
  static ExtensionTypeInfo<Player> get sTypeInfo => _$PlayerTypeInfo();

  @override
  ExtensionTypeInfo<Player> get typeInfo => Player.sTypeInfo;

  Player() : super();

  Player.withNonNullOwner(Pointer<Void> owner) : super.withNonNullOwner(owner);

  @GodotSignal('hit')
  late final Signal0 _hit = Signal0(this, 'hit');

  @GodotProperty()
  var speed = 400;

  @GodotProperty()
  var test = 111;

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
    if (input.isActionPressed('move_right')) {
      velocity.x += 1;
    }
    if (input.isActionPressed('move_left')) {
      velocity.x -= 1;
    }
    if (input.isActionPressed('move_down')) {
      velocity.y += 1;
    }
    if (input.isActionPressed('move_up')) {
      velocity.y -= 1;
    }

    final animatedSprite = getNodeT<AnimatedSprite2D>();

    if (velocity.length > 0) {
      velocity = velocity.normalized();
      velocity.x *= speed;
      velocity.y *= speed;
      animatedSprite?.play();

      if (velocity.x != 0) {
        animatedSprite?.setAnimation('walk');
        animatedSprite?.setFlipV(false);
        animatedSprite?.setFlipH(velocity.x < 0);
      } else if (velocity.y != 0) {
        animatedSprite?.setAnimation('up');
        animatedSprite?.setFlipV(velocity.y > 0);
      }
    } else {
      animatedSprite?.stop();
    }

    var position = getPosition();
    position.x = (position.x + velocity.x * delta).clamp(0, _screenSize.x);
    position.y = (position.y + velocity.y * delta).clamp(0, _screenSize.y);
    setPosition(position);
  }

  @GodotRpc()
  void start(Vector2 pos) {
    setPosition(pos);
    show();
    getNodeT<CollisionShape2D>()?.setDisabled(false);
  }

  @GodotExport()
  void onBodyEntered(Node2D body) {
    _hit.emit();
    hide();
    getNodeT<CollisionShape2D>()?.setDeferred('disabled', Variant(true));
  }
}
