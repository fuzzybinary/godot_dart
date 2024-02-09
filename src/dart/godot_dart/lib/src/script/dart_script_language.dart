import '../../godot_dart.dart';
import 'dart_script.dart';

typedef ScriptTypeResolver = Type? Function(String scriptPath);

class DartScriptLanguage extends ScriptLanguageExtension {
  static TypeInfo sTypeInfo = TypeInfo(
    DartScriptLanguage,
    StringName.fromString('DartScriptLanguage'),
    parentClass: ScriptLanguageExtension.sTypeInfo.className,
    vTable: ScriptLanguageExtension.sTypeInfo.vTable,
  );

  static void initBindings() {
    gde.dartBindings.bindClass(DartScriptLanguage);
  }

  static late DartScriptLanguage singleton;

  ScriptTypeResolver typeResolver = (_) => null;

  DartScriptLanguage() : super() {
    singleton = this;
  }

  @override
  TypeInfo get typeInfo => sTypeInfo;

  Type? getTypeForScript(String scriptPath) {
    final type = typeResolver(scriptPath);
    if (type == null) {
      print(
          'Unable to find registered Dart type for script at path $scriptPath');
    }
    return type;
  }

  @override
  void vInit() {}

  @override
  String vGetName() {
    return 'Dart';
  }

  @override
  String vGetType() {
    return 'DartScript';
  }

  @override
  void vFrame() {
    gde.dartBindings.performFrameMaintenance();
  }

  @override
  String vGetExtension() {
    return 'dart';
  }

  @override
  bool vHasNamedClasses() {
    return true;
  }

  @override
  String vValidatePath(String path) {
    return '';
  }

  @override
  GodotObject? vCreateScript() {
    return DartScript();
  }

  @override
  Script vMakeTemplate(
      String template, String className, String baseClassName) {
    final source = '''import 'dart:ffi';

import 'package:godot_dart/godot_dart.dart';

part '$className.g.dart';

@GodotScript()
class $className extends $baseClassName  {
  static TypeInfo get sTypeInfo => _\$${className}TypeInfo();
  @override
  TypeInfo get typeInfo => sTypeInfo;

  
  $className() : super();

  $className.withNonNullOwner(Pointer<Void> owner) 
    : super.withNonNullOwner(owner);

  @override
  void vReady() {

  }

  @override
  void vProcess(double delta) {

  }
}
''';

    final script = DartScript();
    script.setSourceCode(source);
    script.setName(className);
    return script;
  }

  @override
  PackedStringArray vGetRecognizedExtensions() {
    final array = PackedStringArray();
    array.append('dart');
    return array;
  }

  @override
  Dictionary vValidate(String script, String path, bool validateFunctions,
      bool validateErrors, bool validateWarnings, bool validateSafeLines) {
    final validateResponse = Dictionary();
    validateResponse[Variant.fromObject('valid')] = Variant.fromObject(true);
    return validateResponse;
  }

  @override
  String vAutoIndentCode(String code, int fromLine, int toLine) {
    return code;
  }
}
