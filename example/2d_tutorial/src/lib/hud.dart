import 'dart:ffi';

import 'package:godot_dart/godot_dart.dart';

part 'hud.g.dart';

@GodotScript()
class Hud extends CanvasLayer {
  static TypeInfo get sTypeInfo => _$HudTypeInfo();
  @override
  TypeInfo get typeInfo => Hud.sTypeInfo;

  Hud() : super() {
    postInitialize();
  }

  Hud.withNonNullOwner(Pointer<Void> owner) : super.withNonNullOwner(owner);

  @GodotSignal('start_game')
  late final Signal _startGame = Signal.fromObjectSignal(this, 'start_game');

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
    // TODO: Generate constants for object signals
    await toSignal(messageTimer!, 'timeout');

    var message = getNodeT<Label>('Message');
    message?.setText('Dodge the \nCreeps!');
    message?.show();

    final timer = getTree()!.createTimer(1.0);
    await toSignal(timer.obj!, 'timeout');

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
