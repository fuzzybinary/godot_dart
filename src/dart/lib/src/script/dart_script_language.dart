import '../../godot_dart.dart';

class DartScriptLanguage extends ScriptLanguageExtension {
  static late TypeInfo typeInfo;
  static void initTypeInfo() => typeInfo = TypeInfo(
        StringName.fromString('DartScriptLanguage'),
        parentClass: ScriptLanguageExtension.typeInfo.className,
      );

  DartScriptLanguage();

  @override
  TypeInfo get staticTypeInfo => typeInfo;

  @override
  String vGetName() {
    return 'Dart';
  }
}
