import 'dart:ffi';

import 'package:ffi/ffi.dart';

class Variant {
  static final Finalizer<Pointer<Uint8>> _finalizer =
      Finalizer((mem) => calloc.free(mem));

  // TODO: This is supposed to come from the generator, but we
  // may just need to take the max size
  static const int _size = 24;

  static final _opaque = calloc<Uint8>(_size);
  Pointer<Uint8> get opaque => _opaque;

  Variant() {
    _finalizer.attach(this, _opaque);
  }
}
