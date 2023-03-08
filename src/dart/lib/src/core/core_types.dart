import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../../godot_dart.dart';

/// Core interface for types that can convert to Variant (the builtin types)
abstract class BuiltinType {
  static final Finalizer<Pointer<Uint8>> _finalizer =
      Finalizer((mem) => calloc.free(mem));

  TypeInfo get staticTypeInfo;
  Pointer<Uint8> get opaque;

  BuiltinType() {
    _finalizer.attach(this, opaque);
  }
}
