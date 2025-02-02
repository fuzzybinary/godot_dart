import 'dart:async';

import '../gen/engine_classes.dart';
import '../gen/builtins.dart';
import '../core/type_info.dart';
import '../core/gdextension.dart';

class SignalAwaiter extends GodotObject {
  static TypeInfo sTypeInfo = TypeInfo(
    SignalAwaiter,
    StringName.fromString('SignalAwaiter'),
    StringName.fromString(GodotObject.nativeTypeName),
    parentType: GodotObject,
    vTable: GodotObject.sTypeInfo.vTable,
  );

  @override
  TypeInfo get typeInfo => sTypeInfo;

  static void bind() {
    gde.dartBindings.bindClass(SignalAwaiter);
    gde.dartBindings.bindMethod(
        SignalAwaiter.sTypeInfo, 'signalCalled', TypeInfo.forType(null)!, []);
  }

  final GodotObject? source;
  final String? signalName;
  Callable? callable;
  Completer<void> completer = Completer<void>();

  // TODO: Godot instantiates ClassDB classes to get their properties, which
  // means they need default properties. Look for a better way to handle this.
  SignalAwaiter({this.source, this.signalName}) : super() {
    if (source == null || signalName == null) return;

    callable = Callable.fromObjectMethod(this, 'signalCalled');
    source!.connect(signalName!, callable!);
  }

  void signalCalled() {
    source?.disconnect(signalName!, callable!);
    completer.complete();
  }

  void cancel() {
    source?.disconnect(signalName!, callable!);
    completer.completeError(OperationCanceledError());
  }
}

class OperationCanceledError extends Error {}

class CallbackAwaiter extends GodotObject {
  static TypeInfo sTypeInfo = TypeInfo(
    CallbackAwaiter,
    StringName.fromString('CallbackAwaiter'),
    StringName.fromString(GodotObject.nativeTypeName),
    parentType: GodotObject,
    vTable: GodotObject.sTypeInfo.vTable,
  );

  @override
  TypeInfo get typeInfo => sTypeInfo;

  static void bind() {
    gde.dartBindings.bindClass(CallbackAwaiter);
    gde.dartBindings.bindMethod(
        CallbackAwaiter.sTypeInfo, 'didCallback', TypeInfo.forType(null)!, []);
  }

  Callable? _callable;
  final Completer<void> _completer = Completer<void>();

  Future<void> get future => _completer.future;
  Callable get callable => _callable!;

  void didCallback() {
    _completer.complete();
  }

  CallbackAwaiter() : super() {
    _callable = Callable.fromObjectMethod(this, 'didCallback');
  }
}

Future<void> futureSignal(GodotObject source, String signal) {
  final awaiter = SignalAwaiter(source: source, signalName: signal);
  return awaiter.completer.future;
}
