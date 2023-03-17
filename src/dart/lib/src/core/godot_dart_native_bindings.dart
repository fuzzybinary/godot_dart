import 'dart:ffi';

import '../../godot_dart.dart';
import 'gdextension_ffi_bindings.dart';

class GodotDartNativeBindings {
  late final DynamicLibrary dartDylib;

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

  GodotDartNativeBindings(String dartDllLibraryPath) {
    dartDylib = DynamicLibrary.open(dartDllLibraryPath);
  }

  @pragma('vm:external-name', 'GodotDartNativeBindings::bindClass')
  external void bindClass(
    Type type,
    TypeInfo typeInfo,
  );

  @pragma('vm:external-name', 'GodotDartNativeBindings::bindMethod')
  external void bindMethod(TypeInfo typeInfo, String methodName,
      TypeInfo returnType, List<TypeInfo> argTypes);

  @pragma('vm:external-name', 'GodotDartNativeBindings::gdStringToString')
  external String gdStringToString(GDString string);

  @pragma('vm:external-name', 'GodotDartNativeBindings::gdObjectToDartObject')
  external Object? gdObjectToDartObject(GDExtensionObjectPtr object,
      Pointer<GDExtensionInstanceBindingCallbacks>? bindingCallbacks);

  Pointer<Void> toPersistentHandle(Object instance) {
    return _newPersistentHandle(instance);
  }

  Object? fromPersistentHandle(Pointer<Void> handle) {
    return _handleFromPersistent(handle);
  }

  Object? clearPersistentHandle(Pointer<Void> handle) {
    final obj = _handleFromPersistent(handle);
    if (obj != null) {
      _deletePersistentHandle(handle);
    }
    return obj;
  }
}

// Potentially move this, just here for convenience
@pragma('vm:entry-point')
Variant _convertToVariant(Object? object) {
  return convertToVariant(object);
}

@pragma('vm:entry-point')
List<Object?> _variantsToDart(Pointer<Pointer<Void>> variants, int count,
    List<Pointer<Void>?> bindingCallbacks) {
  var result = <Object?>[];
  for (int i = 0; i < count; ++i) {
    var variant = Variant.fromPointer(variants.elementAt(i).value);
    result.add(convertFromVariant(variant, bindingCallbacks[i]?.cast()));
  }

  return result;
}
