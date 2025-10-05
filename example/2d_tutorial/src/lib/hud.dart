import 'dart:ffi';

import 'package:godot_dart/godot_dart.dart';

part 'hud.g.dart';

@GodotScript()
class Hud extends CanvasLayer {
  @pragma('vm:entry-point')
  static ExtensionTypeInfo<Hud> get sTypeInfo => _$HudTypeInfo();

  @override
  ExtensionTypeInfo<Hud> get typeInfo => Hud.sTypeInfo;

  Hud() : super();

  Hud.withNonNullOwner(Pointer<Void> owner) : super.withNonNullOwner(owner);

  @GodotSignal('start_game')
  late final Signal0 _startGame = Signal0(this, 'start_game');

  @override
  void vReady() {}

  @override
  void vProcess(double delta) {}

  void showMessage(String text) {
    var message = getNodeT<Label>('Message');
    message?.setText(text);
    message?.show();

    getNodeT<Timer>('MessageTimer')?.start();
  }

  Future<void> showGameOver() async {
    showMessage('Game Over');

    var messageTimer = getNodeT<Timer>('MessageTimer');
    await messageTimer!.timeout.asFuture(this);

    var message = getNodeT<Label>('Message');
    message?.setText('Dodge the \nCreeps!');
    message?.show();

    final timer = getTree()!.createTimer(1.0);
    await timer!.timeout.asFuture(this);

    getNodeT<Button>('StartButton')?.show();
  }

  void updateScore(int score) {
    getNodeT<Label>('ScoreLabel')?.setText(score.toString());
  }

  @GodotExport()
  void onStartButtonPressed() {
    getNodeT<Button>('StartButton')?.hide();
    _startGame.emit();
  }

  @GodotExport()
  void onMessageTimerTimeout() {
    getNodeT<Label>('Message')?.hide();
  }
}
