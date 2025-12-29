// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'game_logic.dart';

// **************************************************************************
// GodotScriptAnnotationGenerator
// **************************************************************************

ExtensionTypeInfo<GameLogic> _$GameLogicTypeInfo() {
  final typeInfo = ExtensionTypeInfo<GameLogic>(
    className: StringName.fromString('GameLogic'),
    parentTypeInfo: Node.sTypeInfo,
    nativeTypeName: StringName.fromString(Node.nativeTypeName),
    isRefCounted: false,
    constructObjectDefault: () => GameLogic(),
    constructFromGodotObject: (ptr) => GameLogic.withNonNullOwner(ptr),
    isScript: true,
    isGlobalClass: false,
    signals: [],
    properties: [
      DartPropertyInfo<GameLogic, PackedScene?>(
        name: 'mobScene',
        typeInfo: PackedScene.sTypeInfo,
        hint: PropertyHint.resourceType,
        hintString: 'PackedScene',
        getter: (self) => self.mobScene,
        setter: (self, value) => self.mobScene = value,
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
      name: 'gameOver',
      dartMethodCall: (o, a) => o.gameOver(),
      args: [],
    ),
    MethodInfo(
      name: 'newGame',
      dartMethodCall: (o, a) => o.newGame(),
      args: [],
    ),
    MethodInfo(
      name: 'onScoreTimerTimeout',
      dartMethodCall: (o, a) => o.onScoreTimerTimeout(),
      args: [],
    ),
    MethodInfo(
      name: 'onStartTimerTimeout',
      dartMethodCall: (o, a) => o.onStartTimerTimeout(),
      args: [],
    ),
    MethodInfo(
      name: 'onMobTimerTimeout',
      dartMethodCall: (o, a) => o.onMobTimerTimeout(),
      args: [],
    ),
  ];
  return typeInfo;
}
