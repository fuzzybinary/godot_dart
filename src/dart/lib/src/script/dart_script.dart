import 'dart:ffi';

import '../../godot_dart.dart';

class DartScript extends ScriptExtension {
  static TypeInfo sTypeInfo = TypeInfo(
    DartScript,
    StringName.fromString('DartScript'),
    parentClass: ScriptExtension.sTypeInfo.className,
  );
  static Map<String, Pointer<GodotVirtualFunction>> get vTable =>
      ScriptExtension.vTable;

  @override
  TypeInfo get typeInfo => sTypeInfo;

  static void initBindings() {
    gde.dartBindings.bindClass(DartScript, DartScript.sTypeInfo);
  }

  GDString _sourceCode = GDString();

  DartScript() : super() {
    postInitialize();
  }

  @override
  DartScriptLanguage? vGetLanguage() {
    return DartScriptLanguage.singleton;
  }

  @override
  void vSetSourceCode(GDString code) {
    _sourceCode = GDString.copy(code);
  }

  @override
  GDString vGetSourceCode() {
    return _sourceCode;
  }

  @override
  bool vCanInstantiate() {
    return vIsTool() || !Engine.singleton.isEditorHint();
  }

  @override
  Pointer<Void> vInstanceCreate(GodotObject? forObject) {
    if (forObject == null) return nullptr;
    print('Instance create');

    final scriptPath = getPath().toDartString();
    final type = DartScriptLanguage.singleton.getTypeForScript(scriptPath);
    if (type == null) return nullptr;

    Pointer<Void> scriptInstance =
        gde.dartBindings.createScriptInstance(type, this, forObject.nativePtr);

    return scriptInstance;
  }

  @override
  Pointer<Void> vPlaceholderInstanceCreate(GodotObject? forObject) {
    if (forObject == null) return nullptr;
    print('Placeholder instance create');

    // final scriptPath = getPath().toDartString();
    // final type = DartScriptLanguage.singleton.getTypeForScript(scriptPath);
    // if (type == null) return nullptr;

    // Pointer<Void> scriptInstance =
    //     gde.dartBindings.createScriptInstance(type, this, forObject.nativePtr);

    // return scriptInstance;
    return nullptr;
  }
}
