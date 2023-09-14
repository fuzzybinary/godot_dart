import 'package:path/path.dart' as p;

import '../../godot_dart.dart';
import 'dart_script.dart';

class DartResourceFormatLoader extends ResourceFormatLoader {
  static TypeInfo sTypeInfo = TypeInfo(
    DartResourceFormatLoader,
    StringName.fromString('DartResourceFormatLoader'),
    parentClass: ResourceFormatLoader.sTypeInfo.className,
    vTable: ResourceFormatLoader.sTypeInfo.vTable,
  );

  DartResourceFormatLoader() : super();

  static void initBindings() {
    gde.dartBindings.bindClass(DartResourceFormatLoader);
  }

  @override
  TypeInfo get typeInfo => sTypeInfo;

  @override
  bool vHandlesType(String type) {
    return type == 'Script' || type == 'DartScript';
  }

  @override
  PackedStringArray vGetRecognizedExtensions() {
    final array = PackedStringArray();
    array.pushBack('dart');
    return array;
  }

  @override
  bool vRecognizePath(String path, String type) {
    return path.endsWith('.dart');
  }

  @override
  String vGetResourceType(String path) {
    final extension = p.extension(path);

    return extension == '.dart' ? 'DartScript' : '';
  }

  @override
  String vGetResourceScriptClass(String path) {
    return 'DartScript';
  }

  @override
  bool vExists(String path) {
    return FileAccess.fileExists(path);
  }

  @override
  Variant vLoad(
      String path, String originalPath, bool useSubThreads, int cacheMode) {
    // Can cast directly since this is a direct Dart -> Dart call
    final script = DartScriptLanguage.singleton.vCreateScript() as DartScript?;

    if (script == null) {
      return Variant();
    }

    script.setPath(originalPath);
    final file = FileAccess.open(originalPath, FileAccessModeFlags.read);
    if (file != null) {
      final text = file.getAsText();
      script.setSourceCode(text);
      file.close();
    }

    return convertToVariant(script);
  }

  @override
  int vGetResourceUid(String path) {
    return -1;
  }
}

class DartResourceFormatSaver extends ResourceFormatSaver {
  static TypeInfo sTypeInfo = TypeInfo(
    DartResourceFormatSaver,
    StringName.fromString('DartResourceFormatSaver'),
    parentClass: ResourceFormatSaver.sTypeInfo.className,
    vTable: ResourceFormatSaver.sTypeInfo.vTable,
  );

  DartResourceFormatSaver() : super();

  static void initBindings() {
    gde.dartBindings.bindClass(DartResourceFormatSaver);
  }

  @override
  TypeInfo get typeInfo => sTypeInfo;

  @override
  GDError vSave(Resource? resource, String path, int flags) {
    if (resource == null) return GDError.errInvalidParameter;

    final script = gde.cast<DartScript>(resource);
    if (script == null) return GDError.errBug;

    final file = FileAccess.open(path, FileAccessModeFlags.write);
    if (file != null) {
      final srcCode = script.getSourceCode();
      file.storeString(srcCode);
      if (file.getError() != GDError.ok &&
          file.getError() != GDError.errFileEof) {
        return GDError.errCantCreate;
      }

      file.flush();
      file.close();
    }

    return GDError.ok;
  }

  @override
  bool vRecognizePath(Resource? resource, String path) {
    return path.endsWith('.dart');
  }

  @override
  bool vRecognize(Resource? resource) {
    if (gde.cast<DartScript>(resource) != null) {
      return true;
    }
    return false;
  }

  @override
  PackedStringArray vGetRecognizedExtensions(Resource? resource) {
    return PackedStringArray()..pushBack('dart');
  }
}
