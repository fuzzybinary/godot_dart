import 'dart:ffi';

import '../../godot_dart.dart';

class DartScriptLanguage extends ScriptLanguageExtension {
  static late TypeInfo typeInfo;
  static void initTypeInfo() => typeInfo = TypeInfo(
        StringName.fromString('DartScriptLanguage'),
        parentClass: ScriptLanguageExtension.typeInfo.className,
      );
  static Map<String, Pointer<GodotVirtualFunction>> get vTable =>
      ScriptLanguageExtension.vTable;

  DartScriptLanguage() : super() {
    postInitialize();
  }

  static void initBindings() {
    initTypeInfo();
    gde.dartBindings.bindClass(DartScriptLanguage, DartScriptLanguage.typeInfo);
  }

  @override
  TypeInfo get staticTypeInfo => typeInfo;

  @override
  void vInit() {
    print('Hi from vInit!');
  }

  @override
  String vGetName() {
    return 'Dart';
  }

  @override
  String vGetType() {
    return 'DartScript';
  }

  @override
  void vFrame() {}
}
