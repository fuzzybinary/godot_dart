/// Library for supporting Dart in the Godot Game Engine
library godot_dart;

import 'dart:ffi';

import 'godot_dart.dart';
import 'src/core/gdextension_ffi_bindings.dart';
import 'src/script/dart_resource_format.dart';
import 'src/script/dart_script.dart';

export 'src/core/core_types.dart';
export 'src/core/gdextension.dart';
export 'src/core/property_info.dart';
export 'src/core/type_info.dart';
export 'src/gen/classes/engine_classes.dart';
export 'src/gen/global_constants.dart';
export 'src/gen/variant/builtins.dart';
export 'src/script/dart_script_language.dart';
export 'src/variant/variant.dart';

// ignore: unused_element
late GodotDart _globalExtension;
DartScriptLanguage? _dartScriptLanguage;

@pragma('vm:entry-point')
void _registerGodot(int gdeAddress, int libraryAddress, int bindingCallbacks) {
  final extensionInterface =
      Pointer<GDExtensionInterface>.fromAddress(gdeAddress);
  final libraryPtr = GDExtensionClassLibraryPtr.fromAddress(libraryAddress);
  final bindingCallbackPtr =
      Pointer<GDExtensionInstanceBindingCallbacks>.fromAddress(
          bindingCallbacks);
  // TODO: Assert everything is how we expect.
  _globalExtension =
      GodotDart(extensionInterface, libraryPtr, bindingCallbackPtr);

  initVariantBindings(extensionInterface.ref);
  TypeInfo.initTypeMappings();

  DartScriptLanguage.initBindings();
  DartScript.initBindings();
  DartResourceFormatLoader.initBindings();
  DartResourceFormatSaver.initBindings();
  _dartScriptLanguage = DartScriptLanguage();

  var engine = Engine.singleton;
  engine.registerScriptLanguage(_dartScriptLanguage);

  ResourceLoader.singleton
      .addResourceFormatLoader(Ref(DartResourceFormatLoader()), false);
  ResourceSaver.singleton
      .addResourceFormatSaver(Ref(DartResourceFormatSaver()), false);

  print('Everything loaded a-ok!');
}

@pragma('vm:entry-point')
void _unregisterGodot() {
  Engine.singleton.unregisterScriptLanguage(_dartScriptLanguage);
}

typedef PrintClosure = void Function(String line);
@pragma('vm:entry-point')
PrintClosure _getPrintClosure() {
  return (s) => _globalExtension.dartBindings.print(s);
}
