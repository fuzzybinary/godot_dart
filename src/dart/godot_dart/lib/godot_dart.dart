/// Library for supporting Dart in the Godot Game Engine
library godot_dart;

import 'dart:ffi';

import 'godot_dart.dart';
import 'src/core/gdextension_ffi_bindings.dart';
import 'src/reloader/hot_reloader.dart';

export 'src/annotations/godot_script.dart';
export 'src/core/core_types.dart';
export 'src/core/gdextension.dart';
export 'src/core/property_info.dart';
export 'src/core/type_info.dart';
export 'src/core/type_resolver.dart';
export 'src/extensions/async_extensions.dart';
export 'src/extensions/core_extensions.dart';
export 'src/gen/classes/engine_classes.dart';
export 'src/gen/global_constants.dart';
export 'src/gen/utility_functions.dart';
export 'src/gen/variant/builtins.dart';
export 'src/variant/variant.dart' hide getToTypeConstructor;

// ignore: unused_element
late GodotDart _globalExtension;
HotReloader? _reloader;
// ignore: unused_element
bool _isReloading = false;

@pragma('vm:entry-point')
void _reloadCode() async {
  _isReloading = true;
  var result = await _reloader?.reloadCode();
  print('[godot_dart] Hot reload result: $result');
  _isReloading = false;
}

@pragma('vm:entry-point')
void _registerGodot(int libraryAddress, int bindingCallbacks) {
  final godotDart = DynamicLibrary.process();
  final ffiInterface = GDExtensionFFI(godotDart);

  final libraryPtr = GDExtensionClassLibraryPtr.fromAddress(libraryAddress);
  final bindingCallbackPtr =
      Pointer<GDExtensionInstanceBindingCallbacks>.fromAddress(
          bindingCallbacks);
  // TODO: Assert everything is how we expect.
  _globalExtension = GodotDart(ffiInterface, libraryPtr, bindingCallbackPtr);

  initVariantBindings(ffiInterface);
  TypeInfo.initTypeMappings();

  GD.initBindings();
  SignalAwaiter.bind();
  CallbackAwaiter.bind();

  if (Engine.singleton.isEditorHint()) {
    Future.microtask(() async {
      _reloader = await HotReloader.create();
    });
  }

  print('[godot_dart] Everything loaded a-ok!');
}

@pragma('vm:entry-point')
void _unregisterGodot() {
  _reloader?.stop();
}

typedef PrintClosure = void Function(String line);
@pragma('vm:entry-point')
PrintClosure _getPrintClosure() {
  return (s) => _globalExtension.dartBindings.printNative(s);
}
