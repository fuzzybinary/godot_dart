import 'dart:ffi';

import 'package:meta/meta.dart';

import '../gen/engine_classes.dart';
import 'gdextension.dart';
import 'signals.dart';
import 'gdextension_ffi_bindings.dart';
import 'type_info.dart';

/// Core interface for types that can convert to Variant (the builtin types)
abstract class BuiltinType implements Finalizable {
  @internal
  static final finalizer =
      NativeFinalizer(gde.dartBindings.finalizeBuiltinObject);

  Pointer<Uint8> _opaque = nullptr;

  TypeInfo get typeInfo;
  // Overrideable
  Pointer<Uint8> get nativePtr {
    return nativeDataPtr;
  }

  // DO NOT override
  @protected
  Pointer<Uint8> get nativeDataPtr {
    if (_opaque == nullptr) {
      return nullptr;
    }
    return _opaque + GodotDart.destructorSize;
  }

  BuiltinType(int size, GDExtensionPtrDestructor? destructor) {
    allocateOpaque(size, destructor);
    finalizer.attach(this, _opaque.cast());
  }

  /// This constructor allows classes that we implement to lazily
  /// initialize their nativePtr members
  BuiltinType.nonFinalized();

  @protected
  Pointer<Uint8> allocateOpaque(
      int size, GDExtensionPtrDestructor? destructor) {
    _opaque =
        gde.ffiBindings.gde_mem_alloc(GodotDart.destructorSize + size).cast();
    _opaque.cast<GDExtensionPtrDestructor>().value = destructor ?? nullptr;
    return _opaque + GodotDart.destructorSize;
  }

  /// This is used by the generators to call the FFI copy constructors for
  /// builtin types, usually as part of returning them from a ptr call.
  void constructCopy(GDExtensionTypePtr ptr);
}

typedef OnDetachCallback = void Function(ExtensionType obj);

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

  final Set<SignalCallable> _referencedSignals = {};

  // Created from Dart
  ExtensionType() {
    _owner = gde.constructObject(typeInfo.nativeTypeName);
    _attachFinalizer();
    _tieDartToNative();
  }

  // Created from Godot
  ExtensionType.withNonNullOwner(this._owner) {
    _tieDartToNative();
  }

  // Used by SignalCallable to automatically connect a signal to this
  // object, so that it can be removed if the object goes away.
  void attachSignal(SignalCallable signal) {
    _referencedSignals.add(signal);
  }

  // Used by SignalCallable to remove a signal if there are no more subscriptions
  // to it by this object.
  void detachSignal(SignalCallable signal) {
    _referencedSignals.remove(signal);
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
      bool isGodotType = typeInfo.nativeTypeName.toDartString() ==
          typeInfo.className.toDartString();
      gde.dartBindings
          .tieDartToNative(this, _owner, this is RefCounted, isGodotType);
    }
  }

  @internal
  void detachOwner() {
    for (final signal in _referencedSignals) {
      signal.unsubscribeAll(this as GodotObject);
    }
    _referencedSignals.clear();

    // We should be able to call this finalizer even if Dart doesn't own
    // the object. In that case the object shouldn't have been registered
    // to the finalizer and this call won't do anything.
    _finalizer.detach(this);
    _owner = Pointer.fromAddress(0);
  }
}
