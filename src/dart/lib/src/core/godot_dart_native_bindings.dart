import 'dart:ffi';
import 'dart:io';

import 'package:path/path.dart' as path;

import '../../godot_dart.dart';
import '../script/dart_script.dart';
import 'gdextension_ffi_bindings.dart';

class GodotDartNativeBindings {
  late final DynamicLibrary dartDylib;
  late final DynamicLibrary godotDartDylib;

  late final _newPersistentHandle = dartDylib
      .lookup<NativeFunction<Pointer<Void> Function(Handle)>>(
          'Dart_NewPersistentHandle')
      .asFunction<Pointer<Void> Function(Object)>();
  late final _handleFromPersistent = dartDylib
      .lookup<NativeFunction<Handle Function(Pointer<Void>)>>(
          'Dart_HandleFromPersistent')
      .asFunction<Object? Function(Pointer<Void>)>();
  late final _deletePersistentHandle = dartDylib
      .lookup<NativeFunction<Void Function(Pointer<Void>)>>(
          'Dart_DeletePersistentHandle')
      .asFunction<void Function(Pointer<Void>)>();

  late final _variantCopy = godotDartDylib
      .lookup<
          NativeFunction<
              Void Function(
                  Pointer<Void>, Pointer<Void>, Int32)>>('variant_copy')
      .asFunction<void Function(Pointer<Void>, Pointer<Void>, int size)>(
          isLeaf: true);

  late final finalizeExtensionObject =
      godotDartDylib.lookup<NativeFunction<Void Function(Pointer<Void>)>>(
          'finalize_extension_object');
  late final performFrameMaintenance = godotDartDylib
      .lookup<NativeFunction<Void Function()>>('perform_frame_maintenance')
      .asFunction<void Function()>();
  late final createScriptInstance = godotDartDylib
      .lookup<
          NativeFunction<
              Pointer<Void> Function(
                  Handle, Handle, Pointer<Void>)>>('create_script_instance')
      .asFunction<Pointer<Void> Function(Type, DartScript, Pointer<Void>)>();

  static DynamicLibrary openLibrary(String libName) {
    var libraryPath = path.join(Directory.current.path, '$libName.so');
    if (Platform.isMacOS) {
      libraryPath = path.join(Directory.current.path, '$libName.dylib');
    } else if (Platform.isWindows) {
      libraryPath = path.join(Directory.current.path, '$libName.dll');
    }

    return DynamicLibrary.open(libraryPath);
  }

  GodotDartNativeBindings() {
    dartDylib = DynamicLibrary.open('dart_dll');
    godotDartDylib = DynamicLibrary.open('godot_dart');
  }

  @pragma('vm:external-name', 'GodotDartNativeBindings::print')
  external void print(String s);

  @pragma('vm:external-name', 'GodotDartNativeBindings::bindClass')
  external void bindClass(Type type, TypeInfo typeInfo);

  @pragma('vm:external-name', 'GodotDartNativeBindings::addProperty')
  external void addProperty(
      TypeInfo typeInfo, String propertyName, PropertyInfo propertyInfo);

  @pragma('vm:external-name', 'GodotDartNativeBindings::bindMethod')
  external void bindMethod(TypeInfo typeInfo, String methodName,
      TypeInfo returnType, List<TypeInfo> argTypes);

  @pragma('vm:external-name', 'GodotDartNativeBindings::gdStringToString')
  external String gdStringToString(GDString string);

  @pragma('vm:external-name', 'GodotDartNativeBindings::gdObjectToDartObject')
  external Object? gdObjectToDartObject(
      GDExtensionObjectPtr object, Pointer<Void>? bindingToken);

  Pointer<Void> toPersistentHandle(Object instance) {
    return _newPersistentHandle(instance);
  }

  Object? fromPersistentHandle(Pointer<Void> handle) {
    return _handleFromPersistent(handle);
  }

  void clearPersistentHandle(Pointer<Void> handle) {
    final obj = _handleFromPersistent(handle);
    if (obj != null) {
      if (obj is ExtensionType) {
        obj.detachOwner();
      }
      _deletePersistentHandle(handle);
    }
  }

  void variantCopyToNative(Pointer<Void> dest, BuiltinType src) {
    _variantCopy(dest, src.nativePtr.cast(), src.typeInfo.size);
  }

  void variantCopyFromNative(BuiltinType dest, Pointer<Void> src) {
    _variantCopy(dest.nativePtr.cast(), src, dest.typeInfo.size);
  }
}

// Potentially move this, just here for convenience
@pragma('vm:entry-point')
Variant _convertToVariant(Object? object) {
  return convertToVariant(object);
}

@pragma('vm:entry-point')
List<Object?> _variantsToDart(
    Pointer<Pointer<Void>> variants, int count, List<TypeInfo> typeInfo) {
  var result = <Object?>[];
  for (int i = 0; i < count; ++i) {
    var variant = Variant.fromPointer(variants.elementAt(i).value);
    if (typeInfo[i].variantType ==
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_VARIANT_MAX) {
      // Keep as variant
      result.add(variant);
    } else {
      result.add(convertFromVariant(variant, typeInfo[i].bindingToken));
    }
  }

  return result;
}
