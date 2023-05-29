import 'dart:ffi';

import '../../godot_dart.dart';
import 'dart_script.dart';

class DartScriptLanguage extends ScriptLanguageExtension {
  static TypeInfo sTypeInfo = TypeInfo(
    DartScriptLanguage,
    StringName.fromString('DartScriptLanguage'),
    parentClass: ScriptLanguageExtension.sTypeInfo.className,
  );
  static Map<String, Pointer<GodotVirtualFunction>> get vTable =>
      ScriptLanguageExtension.vTable;
  static void initBindings() {
    gde.dartBindings
        .bindClass(DartScriptLanguage, DartScriptLanguage.sTypeInfo);
  }

  static late DartScriptLanguage singleton;

  final _TypeScriptMapping _scriptMapping = _TypeScriptMapping();

  DartScriptLanguage() : super() {
    postInitialize();
    singleton = this;
  }

  @override
  TypeInfo get typeInfo => sTypeInfo;

  void addScript(String scriptPath, Type type) {
    _scriptMapping.put(scriptPath, type);
  }

  Type? getTypeForScript(String scriptPath) {
    final type = _scriptMapping.getType(scriptPath);
    if (type == null) {
      print(
          'Unable to find registered Dart type for script at path $scriptPath');
    }
    return type;
  }

  static final Map<String, MethodInfo> _methodTable = {
    '_init':
        MethodInfo(methodName: '_init', dartMethodName: 'vInit', arguments: []),
  };
  @override
  MethodInfo? getMethodInfo(String methodName) {
    return _methodTable[methodName] ?? super.getMethodInfo(methodName);
  }

  @override
  void vInit() {}

  @override
  GDString vGetName() {
    return GDString.fromString('Dart');
  }

  @override
  GDString vGetType() {
    return GDString.fromString('DartScript');
  }

  @override
  void vFrame() {
    gde.dartBindings.performFrameMaintenance();
  }

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
  GodotObject? vCreateScript() {
    return DartScript();
  }

  @override
  Ref<Script> vMakeTemplate(
      GDString template, GDString className, GDString baseClassName) {
    final strClassName = gde.dartBindings.gdStringToString(className);
    final strBaseClassName = gde.dartBindings.gdStringToString(baseClassName);

    final source = '''import 'dart:ffi';

import 'package:godot_dart/godot_dart.dart';

class $strClassName extends $strBaseClassName {
  // This is necessary boilerplate at the moment
  static TypeInfo typeInfo = TypeInfo(
    StringName.fromString('$strClassName'),
    parentClass: $strBaseClassName.typeInfo.className,
  );
  static Map<String, Pointer<GodotVirtualFunction>> get vTable => $strBaseClassName.vTable;
  static final Map<String, MethodInfo> _methodTable = {
    '_ready': MethodInfo(
      methodName: '_ready',
      dartMethodName: 'vReady',
      arguments: [],
    ),
    '_process': MethodInfo(
      methodName: '_process',
      dartMethodName: 'vProcess',
      arguments: [],
    ),
  };

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

  @override
  MethodInfo? getMethodInfo(String methodName) {
    return _methodTable[methodName];
  }
}
''';

    final gdSource = GDString.fromString(source);

    final script = DartScript();
    script.setSourceCode(gdSource);
    script.setName(className);
    return Ref<Script>(script);
  }

  @override
  PackedStringArray vGetRecognizedExtensions() {
    final array = PackedStringArray();
    array.append(GDString.fromString('dart'));
    return array;
  }

  @override
  Dictionary vValidate(GDString script, GDString path, bool validateFunctions,
      bool validateErrors, bool validateWarnings, bool validateSafeLines) {
    final validateResponse = Dictionary();
    validateResponse[convertToVariant('valid')] = convertToVariant(true);
    return validateResponse;
  }
}

class _TypeScriptMapping {
  final _map = <String, Type>{};
  final _inverse = <Type, String>{};

  void put(String scriptFile, Type type) {
    _map[scriptFile] = type;
    _inverse[type] = scriptFile;
  }

  Type? getType(String scriptFile) {
    return _map[scriptFile];
  }

  String? getScript(Type type) {
    return _inverse[type];
  }
}
