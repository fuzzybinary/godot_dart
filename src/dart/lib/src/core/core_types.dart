import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../../godot_dart.dart';
import 'gdextension_ffi_bindings.dart';

/// Core interface for types that can convert to Variant (the builtin types)
abstract class BuiltinType {
  static final Finalizer<Pointer<Uint8>> _finalizer = Finalizer((mem) {
    calloc.free(mem);
  });

  TypeInfo get staticTypeInfo;
  Pointer<Uint8> get nativePtr;

  BuiltinType() {
    _finalizer.attach(this, nativePtr);
  }
}

/// Core interface for engine classes
abstract class ExtensionType implements Finalizable {
  // This finalizer is used for objects we own in Dart world,
  // it has Godot delete the object
  static final _finalizer =
      NativeFinalizer(gde.dartBindings.finalizeExtensionObject);

  late GDExtensionObjectPtr _owner = Pointer.fromAddress(0);
  GDExtensionObjectPtr get nativePtr => _owner;

  ExtensionType.forType(StringName typeName) {
    _owner = gde.constructObject(typeName);
    _finalizer.attach(this, _owner, detach: this);
  }

  ExtensionType.withNonNullOwner(this._owner);

  @internal
  void detachOwner() {
    // We should be able to call this finalizer even if Dart doesn't own
    // the object. In that case the object shouldn't have been registered
    // to the finalizer and this call won't do anything.
    _finalizer.detach(this);
    _owner = Pointer.fromAddress(0);
  }

  TypeInfo get staticTypeInfo;

  @protected
  @pragma('vm:external-name', 'ExtensionType::postInitialize')
  external void postInitialize();
}
