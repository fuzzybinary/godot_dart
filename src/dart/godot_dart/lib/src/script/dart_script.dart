import 'dart:ffi';

import 'package:collection/collection.dart';

import '../../godot_dart.dart';
import '../variant/typed_array.dart';

class DartScript extends ScriptExtension {
  static TypeInfo sTypeInfo = TypeInfo(
    DartScript,
    StringName.fromString('DartScript'),
    parentClass: ScriptExtension.sTypeInfo.className,
    vTable: ScriptExtension.sTypeInfo.vTable,
  );

  @override
  TypeInfo get typeInfo => sTypeInfo;

  static void initBindings() {
    gde.dartBindings.bindClass(DartScript);
  }

  Type? _scriptType;
  ScriptInfo? _scriptInfo;

  String _sourceCode = '';

  DartScript() : super();

  DartScript.withNonNullOwner(Pointer<Void> owner)
      : super.withNonNullOwner(owner);

  void loadFromDisk(String path) {
    final file = FileAccess.open(path, FileAccessModeFlags.read);
    if (file != null) {
      final text = file.getAsText();
      setSourceCode(text);
      file.close();
    }
  }

  @override
  DartScriptLanguage? vGetLanguage() {
    return DartScriptLanguage.singleton;
  }

  @override
  void vSetSourceCode(String code) {
    _sourceCode = code;
  }

  @override
  String vGetSourceCode() {
    return _sourceCode;
  }

  @override
  bool vHasSourceCode() {
    return _sourceCode.isNotEmpty;
  }

  @override
  bool vCanInstantiate() {
    return vIsTool() || !Engine.singleton.isEditorHint();
  }

  @override
  bool vHasMethod(String method) {
    return _findMethod(method) != null;
  }

  @override
  Dictionary vGetMethodInfo(String method) {
    final methodInfo = _findMethod(method);
    return methodInfo?.asDict() ?? Dictionary();
  }

  @override
  bool vIsValid() {
    return true;
  }

  @override
  bool vHasScriptSignal(String signal) {
    bool hasSignal = false;
    if (_scriptType == null) {
      _refreshType();
    }

    if (_scriptInfo != null) {
      final signalInfo =
          _scriptInfo!.signals.firstWhereOrNull((e) => e.name == signal);
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
    _refreshType();

    return GDError.ok;
  }

  @override
  Pointer<Void> vInstanceCreate(GodotObject? forObject) {
    if (forObject == null) return nullptr;

    if (_scriptType == null) {
      _refreshType();
    }

    if (_scriptType == null) return nullptr;

    // TODO: There has to be a better way to check this
    final refCounted = forObject.cast<RefCounted>();

    Pointer<Void> scriptInstance = gde.dartBindings.createScriptInstance(
      _scriptType!,
      this,
      forObject.nativePtr,
      false,
      refCounted != null,
    );

    return scriptInstance;
  }

  @override
  Pointer<Void> vPlaceholderInstanceCreate(GodotObject? forObject) {
    if (forObject == null) return nullptr;

    final scriptPath = getPath();
    final type = DartScriptLanguage.singleton.getTypeForScript(scriptPath);
    if (type == null) return nullptr;

    // TODO: There has to be a better way to check this
    final refCounted = forObject.cast<RefCounted>();

    Pointer<Void> scriptInstance = gde.dartBindings.createScriptInstance(
      type,
      this,
      forObject.nativePtr,
      true,
      refCounted != null,
    );

    return scriptInstance;
  }

  void _refreshType() {
    final scriptPath = getPath();
    _scriptType = DartScriptLanguage.singleton.getTypeForScript(scriptPath);
    if (_scriptType != null) {
      _scriptInfo = gde.dartBindings.getGodotScriptInfo(_scriptType!);
    } else {
      _scriptInfo = null;
    }
  }

  MethodInfo? _findMethod(String methodName) {
    MethodInfo? info;
    if (_scriptType == null) {
      _refreshType();
    }

    if (_scriptInfo != null) {
      // TODO: ?
      info = _scriptInfo!.methods.firstWhereOrNull((e) => e.name == methodName);
    }

    return info;
  }
}