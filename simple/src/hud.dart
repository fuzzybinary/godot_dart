import 'dart:ffi';

import 'package:godot_dart/godot_dart.dart';

class Hud extends CanvasLayer with GodotScriptMixin {
  // This is necessary boilerplate at the moment
  static TypeInfo sTypeInfo = TypeInfo(
	Hud,
	StringName.fromString('Hud'),
	parentClass: CanvasLayer.sTypeInfo.className,
  );
  static Map<String, Pointer<GodotVirtualFunction>> get vTable =>
	  CanvasLayer.vTable;
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
		name: 'onStartButtonPressed',
		args: [],
	  ),
	  MethodInfo(
		name: 'onMessageTimerTimeout',
		args: [],
	  ),
	],
	signals: [
	  MethodInfo(name: 'start_game', args: []),
	],
	properties: [],
  );
  @override
  ScriptInfo get scriptInfo => sScriptInfo;

  @override
  TypeInfo get typeInfo => sTypeInfo;

  Hud() : super() {
	postInitialize();
  }

  Hud.withNonNullOwner(Pointer<Void> owner) : super.withNonNullOwner(owner);

  late final Signal _startGame = Signal.fromObjectSignal(this, 'start_game');

  @override
  void vReady() {}

  @override
  void vProcess(double delta) {}

  void showMessage(String text) {
	var message = getNodeT<Label>('Message');
	message?.setText(text);
	message?.show();

	getNodeT<Timer>('MessageTimer')?.start(-1);
  }

  Future<void> showGameOver() async {
	showMessage('Game Over');

	var messageTimer = getNodeT<Timer>('MessageTimer');
	// TODO: Generate constants for object signals
	await toSignal(messageTimer!, 'timeout');

	var message = getNodeT<Label>('Message');
	message?.setText('Dodge the \nCreeps!');
	message?.show();

	final timer = getTree()!.createTimer(1.0, true, false, false);
	await toSignal(timer.obj!, 'timeout');

	getNodeT<Button>('StartButton')?.show();
  }

  void updateScore(int score) {
	getNodeT<Label>('ScoreLabel')?.setText(score.toString());
  }

  void onStartButtonPressed() {
	getNodeT<Button>('StartButton')?.hide();
	_startGame.emit();
  }

  void onMessageTimerTimeout() {
	getNodeT<Label>('Message')?.hide();
  }
}
