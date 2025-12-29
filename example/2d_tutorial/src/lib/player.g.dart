// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player.dart';

// **************************************************************************
// GodotScriptAnnotationGenerator
// **************************************************************************

ExtensionTypeInfo<Player> _$PlayerTypeInfo() {
  final typeInfo = ExtensionTypeInfo<Player>(
    className: StringName.fromString('Player'),
    parentTypeInfo: Area2D.sTypeInfo,
    nativeTypeName: StringName.fromString(Area2D.nativeTypeName),
    isRefCounted: false,
    constructObjectDefault: () => Player(),
    constructFromGodotObject: (ptr) => Player.withNonNullOwner(ptr),
    isScript: true,
    isGlobalClass: false,
    signals: [
      SignalInfo(name: 'hit', args: []),
    ],
    properties: [
      DartPropertyInfo<Player, int>(
        name: 'speed',
        typeInfo: PrimitiveTypeInfo.forType(int)!,
        getter: (self) => self.speed,
        setter: (self, value) => self.speed = value,
      ),
    ],
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
      name: 'start',
      dartMethodCall: (o, a) => o.start(a[0] as Vector2),
      args: [
        PropertyInfo(
          name: 'pos',
          typeInfo: Vector2.sTypeInfo,
        ),
      ],
    ),
    MethodInfo(
      name: 'onBodyEntered',
      dartMethodCall: (o, a) => o.onBodyEntered(a[0] as Node2D),
      args: [
        PropertyInfo(
          name: 'body',
          typeInfo: Node2D.sTypeInfo,
        ),
      ],
    ),
  ];
  return typeInfo;
}
