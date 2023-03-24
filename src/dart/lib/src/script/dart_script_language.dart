import 'dart:ffi';

import '../../godot_dart.dart';
import '../core/gdextension_ffi_bindings.dart';

typedef _GodotVirtualFunction = NativeFunction<
    Void Function(GDExtensionClassInstancePtr, Pointer<GDExtensionConstTypePtr>,
        GDExtensionTypePtr)>;

class DartScriptLanguage extends ScriptLanguageExtension {
  static late TypeInfo typeInfo;
  static void initTypeInfo() => typeInfo = TypeInfo(
        StringName.fromString('DartScriptLanguage'),
        parentClass: ScriptLanguageExtension.typeInfo.className,
      );
  static final Map<String, Pointer<_GodotVirtualFunction>> _vTable = {};

  DartScriptLanguage() : super() {
    postInitialize();
  }

  static void initBindings() {
    initTypeInfo();
    initVTable();
    gde.dartBindings.bindClass(DartScriptLanguage, DartScriptLanguage.typeInfo);
    // gde.dartBindings.bindMethod(typeInfo, '_init', TypeInfo.forType(null)!, []);
    // gde.dartBindings
    //     .bindMethod(typeInfo, '_get_init', TypeInfo.forType(String)!, []);
  }

  @override
  TypeInfo get staticTypeInfo => typeInfo;

  @override
  void vInit() {
    print('Hi from vInit!');
  }

  @override
  String vGetName() {
    return 'Dart';
  }

  static void __init(GDExtensionClassInstancePtr instance,
      Pointer<GDExtensionConstTypePtr> args, GDExtensionTypePtr ret) {
    final self =
        gde.dartBindings.fromPersistentHandle(instance) as DartScriptLanguage;
    self.vInit();
  }

  static void __getName(GDExtensionClassInstancePtr instance,
      Pointer<GDExtensionConstTypePtr> args, GDExtensionTypePtr retPtr) {
    final self =
        gde.dartBindings.fromPersistentHandle(instance) as DartScriptLanguage;
    final ret = self.vGetName();
    final gdString = GDString.fromString(ret);
    gde.dartBindings.variantCopy(retPtr, gdString);
  }

  static void initVTable() {
    _vTable['_init'] = Pointer.fromFunction(__init);
    _vTable['_get_name'] = Pointer.fromFunction(__getName);
  }
}
