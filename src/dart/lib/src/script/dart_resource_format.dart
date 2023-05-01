import 'dart:ffi';

import '../../godot_dart.dart';
import 'dart_script.dart';

class DartResourceFormatLoader extends ResourceFormatLoader {
  static TypeInfo typeInfo = TypeInfo(
    StringName.fromString('DartResourceFormatLoader'),
    parentClass: ResourceFormatLoader.typeInfo.className,
  );
  static Map<String, Pointer<GodotVirtualFunction>> get vTable =>
      ResourceFormatLoader.vTable;

  DartResourceFormatLoader() : super() {
    postInitialize();
  }

  static void initBindings() {
    gde.dartBindings
        .bindClass(DartResourceFormatLoader, DartResourceFormatLoader.typeInfo);
  }

  @override
  TypeInfo get staticTypeInfo => typeInfo;

  @override
  Variant vLoad(
      GDString path, GDString originalPath, bool useSubThreads, int cacheMode) {
    return Variant();
  }
}

class DartResourceFormatSaver extends ResourceFormatSaver {
  static TypeInfo typeInfo = TypeInfo(
    StringName.fromString('DartResourceFormatSaver'),
    parentClass: ResourceFormatSaver.typeInfo.className,
  );
  static Map<String, Pointer<GodotVirtualFunction>> get vTable =>
      ResourceFormatSaver.vTable;

  DartResourceFormatSaver() : super() {
    postInitialize();
  }

  static void initBindings() {
    gde.dartBindings
        .bindClass(DartResourceFormatSaver, DartResourceFormatSaver.typeInfo);
  }

  @override
  TypeInfo get staticTypeInfo => typeInfo;

  @override
  GDError vSave(Ref<Resource> resource, GDString path, int flags) {
    if (resource.obj == null) return GDError.errInvalidParameter;

    final script = gde.cast<DartScript>(resource.obj, DartScript.typeInfo);
    if (script == null) return GDError.errBug;

    final file = FileAccess.open(path, FileAccessModeFlags.write);
    if (file.obj != null) {
      file.obj?.storeString(script.getSourceCode());
      if (file.obj?.getError() != GDError.ok &&
          file.obj?.getError() != GDError.errFileEof) {
        return GDError.errCantCreate;
      }
    }

    file.obj?.close();

    return GDError.ok;
  }

  @override
  bool vRecognizePath(Ref<Resource> resource, GDString path) {
    return path.toDartString().endsWith('.dart');
  }

  @override
  bool vRecognize(Ref<Resource> resource) {
    if (gde.cast<DartScript>(resource.obj, DartScript.typeInfo) != null) {
      return true;
    }
    return false;
  }

  @override
  PackedStringArray vGetRecognizedExtensions(Ref<Resource> resource) {
    return PackedStringArray()..pushBack(GDString.fromString('dart'));
  }
}
