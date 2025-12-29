// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mob.dart';

// **************************************************************************
// GodotScriptAnnotationGenerator
// **************************************************************************

ExtensionTypeInfo<Mob> _$MobTypeInfo() {
  final typeInfo = ExtensionTypeInfo<Mob>(
    className: StringName.fromString('Mob'),
    parentTypeInfo: RigidBody2D.sTypeInfo,
    nativeTypeName: StringName.fromString(RigidBody2D.nativeTypeName),
    isRefCounted: false,
    constructObjectDefault: () => Mob(),
    constructFromGodotObject: (ptr) => Mob.withNonNullOwner(ptr),
    isScript: true,
    isGlobalClass: false,
    signals: [],
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
      name: 'onVisibleOnScreenNotifier2dScreenExited',
      dartMethodCall: (o, a) => o.onVisibleOnScreenNotifier2dScreenExited(),
      args: [],
    ),
  ];
  return typeInfo;
}
