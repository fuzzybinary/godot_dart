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
    gde.dartBindings.bindClass(DartScriptLanguage);
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
  Ref<Script> vMakeTemplate(
      String template, String className, String baseClassName) {
    final source = '''import 'dart:ffi';

import 'package:godot_dart/godot_dart.dart';

class $className extends $baseClassName with GodotScriptMixin {
  // This is necessary boilerplate at the moment
  static TypeInfo sTypeInfo = TypeInfo(
    $className,
    StringName.fromString('$className'),
    parentClass: $baseClassName.sTypeInfo.className,
  );
  static Map<String, Pointer<GodotVirtualFunction>> get vTable => $baseClassName.vTable;
  static final sScriptInfo = ScriptInfo(
    methods: [
      MethodInfo(
        name: '_ready',
        dartMethodName: 'vReady',
        args: [],
      ),
      MethodInfo(
        name: '_process',
        dartMethodName: 'vProcess',
        args: [
          PropertyInfo(typeInfo: TypeInfo.forType(double)!, name: 'delta'),
        ],
      ),
    ],
    signals: [],
    properties: [],
  );
  @override
  ScriptInfo get scriptInfo => sScriptInfo;

  @override
  TypeInfo get typeInfo => sTypeInfo;

  $className() : super() {
    postInitialize();
  }

  $className.withNonNullOwner(Pointer<Void> owner) : super.withNonNullOwner(owner);

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
    return Ref<Script>(script);
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
