import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../../godot_dart.dart';
import 'gdextension_ffi_bindings.dart';

/// Core interface for types that can convert to Variant (the builtin types)
abstract class BuiltinType {
  @internal
  static final Finalizer<Pointer<Uint8>> finalizer = Finalizer((mem) {
    calloc.free(mem);
  });

  TypeInfo get typeInfo;
  Pointer<Uint8> get nativePtr;

  BuiltinType() {
    finalizer.attach(this, nativePtr);
  }

  /// This is used by the generators to call the FFI copy constructors for
  /// builtin types, usually as part of returning them from a ptr call.
  void constructCopy(GDExtensionTypePtr ptr);

  /// This const constructor allows classes that we implement to lazily
  /// initialize their nativePtr members and add them to the finalizer
  /// at that point.
  const BuiltinType.nonFinalized();
}

/// Core interface for engine classes
abstract class ExtensionType implements Finalizable {
  // This finalizer is used for objects we own in Dart world, and for
  // RefCounted objects that we own the last reference to. It has Godot
  // delete the object
  static final _finalizer =
      NativeFinalizer(gde.dartBindings.finalizeExtensionObject);

  GDExtensionObjectPtr _owner = nullptr;
  GDExtensionObjectPtr get nativePtr => _owner;

  TypeInfo get typeInfo;
  @protected
  StringName get nativeTypeName;

  // Created from Dart
  ExtensionType() {
    _owner = gde.constructObject(nativeTypeName);
    _attachFinalizer();
    _tieDartToNative();
  }

  // Created from Godot
  ExtensionType.withNonNullOwner(this._owner) {
    _tieDartToNative();
  }

  void _attachFinalizer() {
    // Only attach the finalizer if this isn't RefCounted
    // RefCounted objects are handled by DartGodotInstanceBinding::initialize
    if (this is! RefCounted) {
      _finalizer.attach(this, _owner, detach: this);
    }
  }

  /// Tie the Dart object to the native object.
  @protected
  void _tieDartToNative() {
    // Script instance should take care of this. Should we assert that the
    // object has a script instance?
    if (typeInfo.scriptInfo == null) {
      bool isGodotType =
          nativeTypeName.toDartString() == typeInfo.className.toDartString();
      gde.dartBindings
          .tieDartToNative(this, _owner, this is RefCounted, isGodotType);
    }
  }

  @internal
  void detachOwner() {
    // We should be able to call this finalizer even if Dart doesn't own
    // the object. In that case the object shouldn't have been registered
    // to the finalizer and this call won't do anything.
    _finalizer.detach(this);
    _owner = Pointer.fromAddress(0);
  }
}
