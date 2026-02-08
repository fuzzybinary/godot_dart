import 'dart:ffi';

import '../core/core.dart';
import '../gen/variant/string_name.dart';
import 'array.dart';
import 'variant.dart';

class TypedArray<T> extends GDBaseArray with Iterable<T> {
  TypedArray() : super() {
    //gde.arraySetTyped(this, VariantType.typeObject, T, Variant());
  }

  TypedArray.fromVariantPtr(Pointer<Void> ptr) : super.fromVariantPtr(ptr);
  TypedArray.copyPtr(Pointer<Void> ptr) : super.copyPtr(ptr);

  T operator [](int index) {
    final self = Variant(this);
    final ret = gde.variantGetIndexed(self, index);
    return ret.cast<T>();
  }

  void operator []=(int index, Variant value) {
    final self = Variant(this);
    gde.variantSetIndexed(self, index, value);
  }

  @override
  Iterator<T> get iterator => _TypedArrayIterator(this);

  static BuiltinTypeInfo<TypedArray<dynamic>> sTypeInfo =
      BuiltinTypeInfo<TypedArray<dynamic>>(
    className: StringName.fromString('TypedArray'),
    variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
    constructObjectDefault: () => TypedArray(),
    size: GDBaseArray.sTypeInfo.size,
    constructCopy: (ptr) => TypedArray.copyPtr(ptr),
  );
}

class _TypedArrayIterator<T> implements Iterator<T> {
  final TypedArray<T> array;

  int _index = -1;
  final int _initialSize;

  _TypedArrayIterator(this.array) : _initialSize = array.size();

  @override
  T get current => array[_index];

  @override
  bool moveNext() {
    if (_initialSize != array.size()) throw ConcurrentModificationError(array);

    _index++;
    return _index < _initialSize;
  }
}
