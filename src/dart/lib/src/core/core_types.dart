import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../../godot_dart.dart';
import 'gdextension_ffi_bindings.dart';

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

/// Core interface for engine classes
abstract class ExtensionType {
  late GDExtensionObjectPtr owner = Pointer.fromAddress(0);

  // TODO
  ExtensionType();

  ExtensionType.fromOwner(this.owner);
}
