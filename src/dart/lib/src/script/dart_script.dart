import 'dart:ffi';

import '../../godot_dart.dart';
import 'dart_script_language.dart';

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
    _sourceCode = code;
  }

  @override
  GDString vGetSourceCode() {
    return _sourceCode;
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
