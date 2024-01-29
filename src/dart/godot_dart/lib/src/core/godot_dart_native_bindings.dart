import 'dart:ffi';

import '../../godot_dart.dart';
import '../script/dart_script.dart';
import 'gdextension_ffi_bindings.dart';

class GodotDartNativeBindings {
  late final DynamicLibrary processLib;

  late final _handleFromPersistent = processLib
      .lookup<NativeFunction<Handle Function(Pointer<Void>)>>(
          'Dart_HandleFromPersistent')
      .asFunction<Object? Function(Pointer<Void>)>();
  late final _deletePersistentHandle = processLib
      .lookup<NativeFunction<Void Function(Pointer<Void>)>>(
          'Dart_DeletePersistentHandle')
      .asFunction<void Function(Pointer<Void>)>();

  late final _variantCopy = processLib
      .lookup<
          NativeFunction<
              Void Function(
                  Pointer<Void>, Pointer<Void>, Int32)>>('variant_copy')
      .asFunction<void Function(Pointer<Void>, Pointer<Void>, int size)>(
          isLeaf: true);

  late final finalizeExtensionObject =
      processLib.lookup<NativeFunction<Void Function(Pointer<Void>)>>(
          'finalize_extension_object');
  late final performFrameMaintenance = processLib
      .lookup<NativeFunction<Void Function()>>('perform_frame_maintenance')
      .asFunction<void Function()>();
  late final createScriptInstance = processLib
      .lookup<
          NativeFunction<
              Pointer<Void> Function(Handle, Handle, Pointer<Void>, Bool,
                  Bool)>>('create_script_instance')
      .asFunction<
          Pointer<Void> Function(
              Type, DartScript, Pointer<Void>, bool, bool)>();
  late final objectFromScriptInstance = processLib
      .lookup<NativeFunction<Handle Function(Pointer<Void>)>>(
          'object_from_script_instance')
      .asFunction<Object? Function(Pointer<Void>)>();

  late final _safeNewPersistentHandle = processLib
      .lookup<NativeFunction<Pointer<Void> Function(Handle)>>(
          'safe_new_persistent_handle')
      .asFunction<Pointer<Void> Function(Object)>();

  late final tieDartToNative = processLib
      .lookup<
          NativeFunction<
              Void Function(Handle, GDExtensionObjectPtr, Bool,
                  Bool)>>('tie_dart_to_native')
      .asFunction<void Function(Object, GDExtensionObjectPtr, bool, bool)>();
  late final objectFromInstanceBinding = processLib
      .lookup<NativeFunction<Handle Function(GDExtensionClassInstancePtr)>>(
          'dart_object_from_instance_binding')
      .asFunction<Object Function(GDExtensionClassInstancePtr)>();

  GodotDartNativeBindings() {
    processLib = DynamicLibrary.process();
  }

  @pragma('vm:external-name', 'GodotDartNativeBindings::print')
  external void printNative(String s);

  @pragma('vm:external-name', 'GodotDartNativeBindings::bindClass')
  external void bindClass(Type type);

  @pragma('vm:external-name', 'GodotDartNativeBindings::addProperty')
  external void addProperty(TypeInfo typeInfo, PropertyInfo propertyInfo);

  @pragma('vm:external-name', 'GodotDartNativeBindings::bindMethod')
  external void bindMethod(TypeInfo typeInfo, String methodName,
      TypeInfo returnType, List<TypeInfo> argTypes);

  @pragma('vm:external-name', 'GodotDartNativeBindings::gdStringToString')
  external String gdStringToString(GDString string);

  @pragma('vm:external-name', 'GodotDartNativeBindings::gdObjectToDartObject')
  external Object? gdObjectToDartObject(
      GDExtensionObjectPtr object, Pointer<Void>? bindingToken);

  @pragma('vm:external-name', 'GodotDartNativeBindings::getGodotTypeInfo')
  external TypeInfo getGodotTypeInfo(Type type);

  @pragma('vm:external-name', 'GodotDartNativeBindings::getGodotScriptInfo')
  external ScriptInfo getGodotScriptInfo(Type type);

  Pointer<Void> toPersistentHandle(Object instance) {
    return _safeNewPersistentHandle(instance);
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
    Pointer<Pointer<Void>> variants, int count, List<dynamic> typeInfoList) {
  var result = <Object?>[];
  for (int i = 0; i < count; ++i) {
    var variantPtr = variants.elementAt(i).value;
    dynamic info = typeInfoList[i];
    // TODO: this is a hack to get around two different ways of calling this. Please fix.
    if (info is PropertyInfo) {
      result.add(_variantPtrToDart(variantPtr, info.typeInfo));
    } else {
      result.add(_variantPtrToDart(variantPtr, info as TypeInfo));
    }
  }

  return result;
}

@pragma('vm:entry-point')
Object? _variantPtrToDart(Pointer<Void> variantPtr, TypeInfo typeInfo) {
  var variant = Variant.fromPointer(variantPtr);
  if (typeInfo.variantType ==
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_VARIANT_MAX) {
    // Keep as variant
    return variant;
  } else {
    return convertFromVariant(variant, typeInfo);
  }
}