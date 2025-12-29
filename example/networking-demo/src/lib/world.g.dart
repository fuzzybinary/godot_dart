// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'world.dart';

// **************************************************************************
// GodotScriptAnnotationGenerator
// **************************************************************************

ExtensionTypeInfo<World> _$WorldTypeInfo() {
  final typeInfo = ExtensionTypeInfo<World>(
    className: StringName.fromString('World'),
    parentTypeInfo: Node2D.sTypeInfo,
    nativeTypeName: StringName.fromString(Node2D.nativeTypeName),
    isRefCounted: false,
    constructObjectDefault: () => World(),
    constructFromGodotObject: (ptr) => World.withNonNullOwner(ptr),
    isScript: true,
    isGlobalClass: false,
    signals: [],
    properties: [],
    rpcInfo: [
      RpcInfo(
        name: 'messageRpc',
        mode: MultiplayerAPIRPCMode.rpcModeAnyPeer,
        callLocal: true,
        transferMode: MultiplayerPeerTransferMode.reliable,
        transferChannel: 0,
      ),
    ],
  );
  typeInfo.methods = [
    MethodInfo(
      name: '_ready',
      dartMethodCall: (o, a) => o.vReady(),
      args: [],
    ),
    MethodInfo(
      name: 'onHostPressed',
      dartMethodCall: (o, a) => o.onHostPressed(),
      args: [],
    ),
    MethodInfo(
      name: 'onJoinPressed',
      dartMethodCall: (o, a) => o.onJoinPressed(),
      args: [],
    ),
    MethodInfo(
      name: 'messageRpc',
      dartMethodCall: (o, a) => o.messageRpc(a[0] as String, a[1] as String),
      args: [
        PropertyInfo(
          name: 'username',
          typeInfo: PrimitiveTypeInfo.forType(String)!,
        ),
        PropertyInfo(
          name: 'data',
          typeInfo: PrimitiveTypeInfo.forType(String)!,
        ),
      ],
    ),
    MethodInfo(
      name: 'onSendPressed',
      dartMethodCall: (o, a) => o.onSendPressed(),
      args: [],
    ),
  ];
  return typeInfo;
}

class $WorldRpcMethods {
  $WorldRpcMethods(this.self);

  World self;

  void messageRpc(
    String username,
    String data, {
    int? peerId,
  }) {
    final args = <Variant>[
      Variant(username),
      Variant(data),
    ];
    if (peerId != null) {
      self.rpcId(peerId, 'messageRpc', vargs: args);
    } else {
      self.rpc('messageRpc', vargs: args);
    }
  }
}

extension WorldRpcExtension on World {
  $WorldRpcMethods get $rpc {
    return $WorldRpcMethods(this);
  }
}
