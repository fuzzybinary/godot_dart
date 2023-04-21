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
  GDString vGetName() {
    return GDString.fromString('Dart');
  }

  @override
  GDString vGetType() {
    return GDString.fromString('DartScript');
  }

  @override
  void vFrame() {}

  @override
  GDString vGetExtension() {
    return GDString.fromString('dart');
  }

  @override
  bool vHasNamedClasses() {
    return true;
  }

  @override
  GDString vValidatePath(GDString path) {
    return GDString.fromString('');
  }

  @override
  Script? vMakeTemplate(
      GDString template, GDString className, GDString baseClassName) {
    final strClassName = gde.dartBindings.gdStringToString(className);
    final strBaseClassName = gde.dartBindings.gdStringToString(baseClassName);

    final source = '''
class $strClassName extends $strBaseClassName {
  // This is necessary boilerplate at the moment
  static TypeInfo typeInfo = TypeInfo(
    StringName.fromString('$strClassName'),
    parentClass: $strBaseClassName.typeInfo.className,
  );
  static Map<String, Pointer<GodotVirtualFunction>> get vTable => $strBaseClassName.vTable;

  @override
  TypeInfo get staticTypeInfo => typeInfo;

  $strClassName() : super() {
    postInitialize();
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
