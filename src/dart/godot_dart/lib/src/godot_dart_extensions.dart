import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../godot_dart.dart';
import 'core/gdextension_ffi_bindings.dart';

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
    return node?.cast<T>();
  }
}

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
    completer.complete();
    source?.disconnect(signalName!, callable!);
  }
}

Future<void> toSignal(GodotObject source, String signal) {
  final awaiter = SignalAwaiter(source: source, signalName: signal);
  return awaiter.completer.future;
}

extension StringExtensions on String {
  static String fromGodotStringPtr(GDExtensionTypePtr ptr) {
    return using((arena) {
      int length =
          gde.ffiBindings.gde_string_to_utf16_chars(ptr.cast(), nullptr, 0);
      final chars = arena.allocate<Uint16>(sizeOf<Uint16>() * length);
      gde.ffiBindings
          .gde_string_to_utf16_chars(ptr.cast(), chars.cast(), length);
      return chars.cast<Utf16>().toDartString(length: length);
    });
  }
}
