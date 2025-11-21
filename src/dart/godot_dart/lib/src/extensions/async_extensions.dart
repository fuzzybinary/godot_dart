import 'dart:async';

import '../../godot_dart.dart';

class SignalAwaiter extends GodotObject {
  static final sTypeInfo = ExtensionTypeInfo<SignalAwaiter>(
    className: StringName.fromString('SignalAwaiter'),
    parentTypeInfo: GodotObject.sTypeInfo,
    nativeTypeName: GodotObject.sTypeInfo.nativeTypeName,
    isRefCounted: false,
    constructObjectDefault: () => SignalAwaiter(),
    constructFromGodotObject: (_) => SignalAwaiter(),
  );

  @override
  @pragma('vm:entry-point')
  ExtensionTypeInfo<SignalAwaiter> get typeInfo => sTypeInfo;

  static void bind() {
    gde.typeResolver.addType(sTypeInfo);
    GDNativeInterface.bindClass(SignalAwaiter.sTypeInfo);
    GDNativeInterface.bindMethod(
      SignalAwaiter.sTypeInfo,
      MethodInfo<SignalAwaiter>(
        name: 'signalCalled',
        dartMethodCall: (self, _) => self.signalCalled(),
        args: [],
      ),
    );
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
  static final sTypeInfo = ExtensionTypeInfo<CallbackAwaiter>(
    className: StringName.fromString('CallbackAwaiter'),
    parentTypeInfo: GodotObject.sTypeInfo,
    nativeTypeName: GodotObject.sTypeInfo.nativeTypeName,
    isRefCounted: false,
    constructObjectDefault: () => CallbackAwaiter(),
    constructFromGodotObject: (_) => CallbackAwaiter(),
  );

  @override
  @pragma('vm:entry-point')
  ExtensionTypeInfo<CallbackAwaiter> get typeInfo => sTypeInfo;

  static void bind() {
    gde.typeResolver.addType(CallbackAwaiter.sTypeInfo);
    GDNativeInterface.bindClass(CallbackAwaiter.sTypeInfo);
    GDNativeInterface.bindMethod(
      CallbackAwaiter.sTypeInfo,
      MethodInfo<CallbackAwaiter>(
        name: 'didCallback',
        dartMethodCall: (self, _) => self.didCallback(),
        args: [],
      ),
    );
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
