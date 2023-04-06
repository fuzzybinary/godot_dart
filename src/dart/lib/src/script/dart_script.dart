import 'dart:ffi';

import '../../godot_dart.dart';

class DartScript extends ScriptExtension {
  static late TypeInfo typeInfo;
  static void initTypeInfo() => typeInfo = TypeInfo(
        StringName.fromString('DartScript'),
        parentClass: ScriptExtension.typeInfo.className,
      );
  static Map<String, Pointer<GodotVirtualFunction>> get vTable =>
      ScriptExtension.vTable;

  @override
  TypeInfo get staticTypeInfo => typeInfo;

  static void initBindings() {
    initTypeInfo();
    gde.dartBindings.bindClass(DartScript, DartScript.typeInfo);
  }

  DartScript() : super() {
    postInitialize();
  }

  @override
  bool vCanInstantiate() {
    return true;
  }

  @override
  Pointer<Void> vInstanceCreate(GodotObject? forObject) {
    return nullptr;
  }

  @override
  Pointer<Void> vPlaceholderInstanceCreate(GodotObject? forObject) {
    return nullptr;
  }
}
