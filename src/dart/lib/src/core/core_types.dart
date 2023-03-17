import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../../godot_dart.dart';
import 'gdextension_ffi_bindings.dart';

/// Core interface for types that can convert to Variant (the builtin types)
abstract class BuiltinType {
  static final Finalizer<Pointer<Uint8>> _finalizer =
      Finalizer((mem) => calloc.free(mem));

  TypeInfo get staticTypeInfo;
  Pointer<Uint8> get nativePtr;

  BuiltinType() {
    _finalizer.attach(this, nativePtr);
  }
}

/// Core interface for engine classes
abstract class ExtensionType {
  late GDExtensionObjectPtr _owner = Pointer.fromAddress(0);
  GDExtensionObjectPtr get nativePtr => _owner;

  ExtensionType.forType(StringName typeName) {
    _owner = gde.constructObject(typeName);
  }

  ExtensionType.fromOwner(this._owner);

  TypeInfo get staticTypeInfo;
}
