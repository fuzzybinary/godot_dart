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

  /// This const constructor allows classes that we implement to lazily
  /// initialize their nativePtr members and add them to the finalizer
  /// at that point. It also allows those classes to have const constructors
  const BuiltinType.nonFinalized();
}

/// Core interface for engine classes
abstract class ExtensionType implements Finalizable {
  // This finalizer is used for objects we own in Dart world,
  // it has Godot delete the object
  static final _finalizer =
      NativeFinalizer(gde.dartBindings.finalizeExtensionObject);

  TypeInfo get typeInfo;

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

  @protected
  @pragma('vm:external-name', 'ExtensionType::postInitialize')
  external void postInitialize();
}

/// Reference counted objects
class Ref<T extends RefCounted> implements Finalizable {
  // If a ref is no longer reachable, tell Godot to unreference it.
  static final _finalizer = Finalizer<RefCounted>((obj) => obj.unreference());

  T? obj;

  Ref(this.obj) {
    obj?.reference();
    if (obj != null) {
      _finalizer.attach(this, obj!);
    }
  }

  Ref.fromPointer(Pointer<Void> refPointer) {
    final typeInfo = gde.dartBindings.getGodotTypeInfo(T);
    final objPtr = gde.interface.ref.ref_get_object
        .asFunction<Pointer<Void> Function(Pointer<Void>)>(
            isLeaf: true)(refPointer);
    final maybeObj =
        gde.dartBindings.gdObjectToDartObject(objPtr, typeInfo.bindingToken);
    if (maybeObj is T) {
      obj = maybeObj;
      obj?.reference();
      if (obj != null) {
        _finalizer.attach(this, obj!);
      }
    }
  }
}
