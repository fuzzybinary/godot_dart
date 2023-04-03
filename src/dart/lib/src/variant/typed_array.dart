import 'dart:ffi';

import '../../godot_dart.dart';

class TypedArray<T> extends Array {
  TypedArray() : super() {
    //gde.arraySetTyped(this, VariantType.typeObject, T, Variant());
  }

  TypedArray.fromPointer(Pointer<Void> ptr) : super.fromPointer(ptr);
}
