import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../core/gdextension.dart';
import '../core/gdextension_ffi_bindings.dart';
import '../core/godot_dart_native_bridge.dart';
import '../gen/builtins.dart';
import '../gen/engine_classes.dart';
import '../gen/utility_functions.dart';
import '../variant/variant.dart';
import '../variant/array.dart';

extension TNode on Node {
  T? getNodeT<T>([String? path]) {
    final GDString name;
    if (path != null) {
      name = GDString.fromString(path);
    } else {
      var typeInfo = gde.typeResolver.getTypeInfoByType(T);
      if (typeInfo != null) {
        name = GDString.fromStringName(typeInfo.className);
      } else {
        return null;
      }
    }
    var node = getNode(NodePath.fromGDString(name));
    return node?.as<T>();
  }
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

extension WeakRefExtension on Object {
  WeakRef? getWeak() {
    return GD.weakref(Variant(this)).cast<WeakRef>();
  }
}

extension GDPointerExtension on Pointer {
  Object? toDart() {
    return GDNativeInterface.gdObjectToDartObject(cast());
  }
}

extension GDArrayExtensions on GDArray {
  List<T> toDartList<T>() {
    final arraySize = size();
    final list = <T>[];
    for (int i = 0; i < arraySize; i++) {
      final element = this[i].as<T>();
      if (element is T) {
        list.add(element);
      }
    }
    return list;
  }

  static GDArray fromList<T>(List<T> list) {
    final array = GDArray();
    for (var element in list) {
      array.append(Variant(element));
    }
    return array;
  }
}
