import 'dart:async';

import '../godot_dart.dart';

extension TNode on Node {
  T? getNodeT<T>([String? path]) {
    var typeInfo = gde.dartBindings.getGodotTypeInfo(T);
    final GDString name;
    if (path != null) {
      name = GDString.fromString(path);
    } else {
      name = GDString.fromStringName(typeInfo.className);
    }
    var node = getNode(NodePath.fromGDString(name));
    return gde.cast<T>(node);
  }
}

class SignalAwaiter extends GodotObject {
  static TypeInfo sTypeInfo = TypeInfo(
    SignalAwaiter,
    StringName.fromString('SignalAwaiter'),
    parentClass: ScriptExtension.sTypeInfo.className,
    vTable: ScriptExtension.sTypeInfo.vTable,
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
  Completer<void> completer = Completer<void>();

  // TODO: Godot instantiates ClassDB classes to get their properties, which
  // means they need default properties. Look for a better way to handle this.
  SignalAwaiter({this.source, this.signalName}) : super() {
    postInitialize();

    if (source == null || signalName == null) return;

    final callable = Callable.fromObjectMethod(this, 'signalCalled');
    source!.connect(signalName!, callable);
  }

  void signalCalled() {
    completer.complete();
  }
}

Future<void> toSignal(GodotObject source, String signal) {
  final awaiter = SignalAwaiter(source: source, signalName: signal);
  return awaiter.completer.future;
}
