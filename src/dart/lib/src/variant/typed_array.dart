import 'dart:ffi';

import '../../godot_dart.dart';

class TypedArray<T> extends Array {
  TypedArray() : super() {
    //gde.arraySetTyped(this, VariantType.typeObject, T, Variant());
  }
  static TypeInfo get sTypeInfo => Array.sTypeInfo;

  TypedArray.fromPointer(Pointer<Void> ptr) : super.fromPointer(ptr);
}
