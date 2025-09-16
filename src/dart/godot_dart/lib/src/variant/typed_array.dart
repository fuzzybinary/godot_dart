import 'dart:ffi';

import '../core/core.dart';
import '../gen/builtins.dart';

class TypedArray<T> extends Array {
  TypedArray() : super() {
    //gde.arraySetTyped(this, VariantType.typeObject, T, Variant());
  }

  TypedArray.fromVariantPtr(Pointer<Void> ptr) : super.fromVariantPtr(ptr);
  TypedArray.copyPtr(Pointer<Void> ptr) : super.copyPtr(ptr);

  static BuiltinTypeInfo<TypedArray<dynamic>> sTypeInfo =
      BuiltinTypeInfo<TypedArray<dynamic>>(
    className: StringName.fromString('TypedArray'),
    variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
    constructObjectDefault: () => TypedArray(),
    size: Array.sTypeInfo.size,
    constructCopy: (ptr) => TypedArray.copyPtr(ptr),
  );
}
