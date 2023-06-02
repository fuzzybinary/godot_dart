import 'dart:ffi';

import 'package:collection/collection.dart';

import '../../godot_dart.dart';
import '../variant/typed_array.dart';

class DartScript extends ScriptExtension {
  static TypeInfo sTypeInfo = TypeInfo(
    DartScript,
    StringName.fromString('DartScript'),
    parentClass: ScriptExtension.sTypeInfo.className,
  );
  static Map<String, Pointer<GodotVirtualFunction>> get vTable =>
      ScriptExtension.vTable;

  @override
  TypeInfo get typeInfo => sTypeInfo;

  static void initBindings() {
    gde.dartBindings.bindClass(DartScript, DartScript.sTypeInfo);
  }

  Type? _scriptType;
  ScriptInfo? _scriptInfo;

  GDString _sourceCode = GDString();

  DartScript() : super() {
    postInitialize();
  }

  @override
  DartScriptLanguage? vGetLanguage() {
    return DartScriptLanguage.singleton;
  }

  @override
  void vSetSourceCode(GDString code) {
    _sourceCode = GDString.copy(code);
  }

  @override
  GDString vGetSourceCode() {
    return _sourceCode;
  }

  @override
  bool vHasSourceCode() {
    return !_sourceCode.isEmpty();
  }

  @override
  bool vCanInstantiate() {
    return vIsTool() || !Engine.singleton.isEditorHint();
  }

  @override
  bool vHasMethod(StringName method) {
    return _findMethod(method) != null;
  }

  @override
  Dictionary vGetMethodInfo(StringName method) {
    final methodInfo = _findMethod(method);
    return methodInfo?.asDict() ?? Dictionary();
  }

  @override
  bool vIsValid() {
    return true;
  }

  @override
  bool vHasScriptSignal(StringName signal) {
    bool hasSignal = false;
    if (_scriptType == null) {
      _refreshType();
    }

    if (_scriptInfo != null) {
      final signalName = GDString.fromStringName(signal).toDartString();
      final signalInfo =
          _scriptInfo!.signals.firstWhereOrNull((e) => e.name == signalName);
      hasSignal = signalInfo != null;
    }

    return hasSignal;
  }

  @override
  TypedArray<Dictionary> vGetScriptSignalList() {
    var gdSignals = TypedArray<Dictionary>();
    if (_scriptType == null) {
      _refreshType();
    }

    if (_scriptInfo != null) {
      for (final signal in _scriptInfo!.signals) {
        gdSignals.append(convertToVariant(signal.asDict()));
      }
    }

    return gdSignals;
  }

  @override
  TypedArray<Dictionary> vGetScriptMethodList() {
    var gdMethods = TypedArray<Dictionary>();
    if (_scriptType == null) {
      _refreshType();
    }

    if (_scriptInfo != null) {
      for (final method in _scriptInfo!.methods) {
        gdMethods.append(convertToVariant(method.asDict()));
      }
    }

    return gdMethods;
  }

  @override
  TypedArray<Dictionary> vGetScriptPropertyList() {
    var gdProperties = TypedArray<Dictionary>();
    if (_scriptType == null) {
      _refreshType();
    }

    if (_scriptInfo != null) {
      for (final prop in _scriptInfo!.properties) {
        gdProperties.append(convertToVariant(prop.asDict()));
      }
    }

    return gdProperties;
  }

  @override
  GDError vReload(bool keepState) {
    print('vReload');
    _refreshType();

    return GDError.ok;
  }

  @override
  Pointer<Void> vInstanceCreate(GodotObject? forObject) {
    if (forObject == null) return nullptr;
    print('Instance create');

    if (_scriptType == null) {
      _refreshType();
    }

    if (_scriptType == null) return nullptr;

    Pointer<Void> scriptInstance = gde.dartBindings
        .createScriptInstance(_scriptType!, this, forObject.nativePtr, false);

    return scriptInstance;
  }

  @override
  Pointer<Void> vPlaceholderInstanceCreate(GodotObject? forObject) {
    if (forObject == null) return nullptr;
    print('Placeholder instance create');

    final scriptPath = getPath().toDartString();
    final type = DartScriptLanguage.singleton.getTypeForScript(scriptPath);
    if (type == null) return nullptr;

    Pointer<Void> scriptInstance = gde.dartBindings
        .createScriptInstance(type, this, forObject.nativePtr, true);

    return scriptInstance;
  }

  void _refreshType() {
    final scriptPath = getPath().toDartString();
    _scriptType = DartScriptLanguage.singleton.getTypeForScript(scriptPath);
    if (_scriptType != null) {
      _scriptInfo = gde.dartBindings.getGodotScriptInfo(_scriptType!);
    } else {
      _scriptInfo = null;
    }
  }

  MethodInfo? _findMethod(StringName methodName) {
    MethodInfo? info;
    if (_scriptType == null) {
      _refreshType();
    }

    if (_scriptInfo != null) {
      // TODO: ?
      final name = GDString.fromStringName(methodName).toDartString();
      info = _scriptInfo!.methods.firstWhereOrNull((e) => e.name == name);
    }

    return info;
  }
}
