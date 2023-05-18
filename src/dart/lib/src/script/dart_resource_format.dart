import 'dart:ffi';

import '../../godot_dart.dart';
import 'dart_script.dart';

class DartResourceFormatLoader extends ResourceFormatLoader {
  static TypeInfo sTypeInfo = TypeInfo(
    DartResourceFormatLoader,
    StringName.fromString('DartResourceFormatLoader'),
    parentClass: ResourceFormatLoader.sTypeInfo.className,
  );
  static Map<String, Pointer<GodotVirtualFunction>> get vTable =>
      ResourceFormatLoader.vTable;

  DartResourceFormatLoader() : super() {
    postInitialize();
  }

  static void initBindings() {
    gde.dartBindings.bindClass(
        DartResourceFormatLoader, DartResourceFormatLoader.sTypeInfo);
  }

  @override
  TypeInfo get typeInfo => sTypeInfo;

  @override
  bool vHandlesType(StringName type) {
    final strType = GDString.fromStringName(type).toDartString();
    return strType == 'Script' || strType == 'DartScript';
  }

  @override
  PackedStringArray vGetRecognizedExtensions() {
    final array = PackedStringArray();
    array.pushBack(GDString.fromString('dart'));
    return array;
  }

  @override
  bool vRecognizePath(GDString path, StringName type) {
    return path.toDartString().endsWith('.dart');
  }

  @override
  GDString vGetResourceType(GDString path) {
    final extension = path.getExtension();

    return extension.toDartString() == 'dart'
        ? GDString.fromString('DartScript')
        : GDString.fromString('');
  }

  @override
  GDString vGetResourceScriptClass(GDString path) {
    return GDString.fromString('DartScript');
  }

  @override
  bool vExists(GDString path) {
    return FileAccess.fileExists(path);
  }

  @override
  Variant vLoad(
      GDString path, GDString originalPath, bool useSubThreads, int cacheMode) {
    // Can cast directly since this is a direct Dart -> Dart call
    final script = DartScriptLanguage.singleton.vCreateScript() as DartScript?;

    if (script == null) {
      return Variant();
    }

    script.setPath(originalPath);
    final file = FileAccess.open(originalPath, FileAccessModeFlags.read);
    if (file.obj != null) {
      final text = file.obj?.getAsText(false);
      if (text != null) {
        script.setSourceCode(text);
      }
      file.obj?.close();
    }

    return convertToVariant(script);
  }
}

class DartResourceFormatSaver extends ResourceFormatSaver {
  static TypeInfo sTypeInfo = TypeInfo(
    DartResourceFormatSaver,
    StringName.fromString('DartResourceFormatSaver'),
    parentClass: ResourceFormatSaver.sTypeInfo.className,
  );
  static Map<String, Pointer<GodotVirtualFunction>> get vTable =>
      ResourceFormatSaver.vTable;

  DartResourceFormatSaver() : super() {
    postInitialize();
  }

  static void initBindings() {
    gde.dartBindings
        .bindClass(DartResourceFormatSaver, DartResourceFormatSaver.sTypeInfo);
  }

  @override
  TypeInfo get typeInfo => sTypeInfo;

  @override
  GDError vSave(Ref<Resource> resource, GDString path, int flags) {
    if (resource.obj == null) return GDError.errInvalidParameter;

    final script = gde.cast<DartScript>(resource.obj, DartScript.sTypeInfo);
    if (script == null) return GDError.errBug;

    final file = FileAccess.open(path, FileAccessModeFlags.write);
    if (file.obj != null) {
      final srcCode = script.getSourceCode();
      file.obj?.storeString(srcCode);
      if (file.obj?.getError() != GDError.ok &&
          file.obj?.getError() != GDError.errFileEof) {
        return GDError.errCantCreate;
      }
    }

    file.obj?.flush();
    file.obj?.close();

    return GDError.ok;
  }

  @override
  bool vRecognizePath(Ref<Resource> resource, GDString path) {
    return path.toDartString().endsWith('.dart');
  }

  @override
  bool vRecognize(Ref<Resource> resource) {
    if (gde.cast<DartScript>(resource.obj, DartScript.sTypeInfo) != null) {
      return true;
    }
    return false;
  }

  @override
  PackedStringArray vGetRecognizedExtensions(Ref<Resource> resource) {
    return PackedStringArray()..pushBack(GDString.fromString('dart'));
  }
}
