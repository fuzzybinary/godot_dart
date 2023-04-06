import 'dart:ffi';

import '../../godot_dart.dart';
import 'dart_script.dart';

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

  @override
  String vGetExtension() {
    return 'dart';
  }

  @override
  bool vHasNamedClasses() {
    return true;
  }

  @override
  String vValidatePath(GDString path) {
    return '';
  }

  @override
  Script? vMakeTemplate(
      GDString template, GDString className, GDString baseClassName) {
    final strClassName = gde.dartBindings.gdStringToString(className);
    final strBaseClassName = gde.dartBindings.gdStringToString(baseClassName);

    final source = '''
class $strClassName extends $baseClassName {
  // This is necessary boilerplate at the moment
  static late TypeInfo typeInfo;
  static void initTypeInfo() => typeInfo = TypeInfo(
        StringName.fromString('DartScript'),
        parentClass: Script.typeInfo.className,
      );
  static Map<String, Pointer<GodotVirtualFunction>> get vTable => $baseClassName.vTable;

  @override
  TypeInfo get staticTypeInfo => typeInfo;

  static void initBindings() {
    initTypeInfo();
    gde.dartBindings.bindClass($strClassName, $strClassName.typeInfo);
  }

  @override
  void vReady() {

  }

  @override
  void vProcess(double delta) {

  }
}
''';

    final gdSource = GDString.fromString(source);

    final script = DartScript();
    script.setSourceCode(gdSource);
    script.setName(className);
    return script;
  }

  @override
  PackedStringArray vGetRecognizedExtensions() {
    final array = PackedStringArray();
    array.append(GDString.fromString('dart'));
    return array;
  }
}
