import 'package:godot_dart/godot_dart.dart';

part 'world.g.dart';

@GodotScript()
class World extends Node2D {
  static ExtensionTypeInfo<World> get sTypeInfo => _$WorldTypeInfo();
  @override
  ExtensionTypeInfo<World> get typeInfo => sTypeInfo;

  World() : super();

  World.withNonNullOwner(super.owner) : super.withNonNullOwner();

  static const port = 12912;

  final enetPeer = ENetMultiplayerPeer();
  late TextEdit _messages;
  late LineEdit _userNameBox;
  late LineEdit _line;

  String username = 'Unknown';

  @override
  void vReady() {
    _line = getNodeT<LineEdit>('Line')!;
    _messages = getNodeT<TextEdit>('Messages')!;
    _userNameBox = getNodeT<LineEdit>('Username')!;
  }

  @GodotExport()
  void onHostPressed() {
    enetPeer.createServer(port);

    getMultiplayer()!.setMultiplayerPeer(enetPeer);
    _joined();
  }

  @GodotExport()
  void onJoinPressed() {
    enetPeer.createClient('127.0.0.1', port);
    getMultiplayer()!.setMultiplayerPeer(enetPeer);
    _joined();
  }

  @GodotRpc(mode: MultiplayerAPIRPCMode.rpcModeAnyPeer, callLocal: true)
  void messageRpc(String username, String data) {
    final newText = '${_messages.getText()}$username: $data\n';
    _messages.setText(newText);
  }

  @GodotExport()
  void onSendPressed() {
    final line = _line.getText();
    _line.setText('');
    $rpc.messageRpc(username, line);
  }

  void _joined() {
    username = _userNameBox.getText();
    if (username.isEmpty) {
      username = 'Unknown';
    }
    getNodeT<Button>('Host')?.hide();
    getNodeT<Button>('Join')?.hide();
    getNodeT<Control>('Username')?.hide();
  }
}
