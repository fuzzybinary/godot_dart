import 'package:meta/meta.dart';

import '../../godot_dart.dart';

@immutable
class RpcInfo {
  final String name;
  final MultiplayerAPIRPCMode mode;
  final bool callLocal;
  final MultiplayerPeerTransferMode transferMode;
  final int transferChannel;

  const RpcInfo({
    required this.name,
    this.mode = MultiplayerAPIRPCMode.rpcModeAuthority,
    this.callLocal = false,
    this.transferMode = MultiplayerPeerTransferMode.reliable,
    this.transferChannel = 0,
  });

  Dictionary asDict() {
    final dict = Dictionary();

    dict[Variant('name')] = Variant(name);
    dict[Variant('rpc_mode')] = Variant(mode.value);
    dict[Variant('call_local')] = Variant(callLocal);
    dict[Variant('transfer_mode')] = Variant(transferMode.value);
    dict[Variant('channel')] = Variant(transferChannel);

    return dict;
  }
}
