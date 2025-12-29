// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hud.dart';

// **************************************************************************
// GodotScriptAnnotationGenerator
// **************************************************************************

ExtensionTypeInfo<Hud> _$HudTypeInfo() {
  final typeInfo = ExtensionTypeInfo<Hud>(
    className: StringName.fromString('Hud'),
    parentTypeInfo: CanvasLayer.sTypeInfo,
    nativeTypeName: StringName.fromString(CanvasLayer.nativeTypeName),
    isRefCounted: false,
    constructObjectDefault: () => Hud(),
    constructFromGodotObject: (ptr) => Hud.withNonNullOwner(ptr),
    isScript: true,
    isGlobalClass: false,
    signals: [
      SignalInfo(name: 'start_game', args: []),
    ],
    properties: [],
    rpcInfo: [],
  );
  typeInfo.methods = [
    MethodInfo(
      name: '_ready',
      dartMethodCall: (o, a) => o.vReady(),
      args: [],
    ),
    MethodInfo(
      name: '_process',
      dartMethodCall: (o, a) => o.vProcess(a[0] as double),
      args: [
        PropertyInfo(
          name: 'delta',
          typeInfo: PrimitiveTypeInfo.forType(double)!,
        ),
      ],
    ),
    MethodInfo(
      name: 'onStartButtonPressed',
      dartMethodCall: (o, a) => o.onStartButtonPressed(),
      args: [],
    ),
    MethodInfo(
      name: 'onMessageTimerTimeout',
      dartMethodCall: (o, a) => o.onMessageTimerTimeout(),
      args: [],
    ),
  ];
  return typeInfo;
}
