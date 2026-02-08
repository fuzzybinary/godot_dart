import 'dart:ffi';

import 'package:ffi/ffi.dart';

import '../core/core.dart';
import '../variant/variant.dart';
import '../gen/builtins.dart';

// This is mostly from the generator. However, becuse of the
// customization necessary type safety of indexors and iterators
// for the two inheriting classes (GDArray and TypedArray), it has
// been moved to "hand" implementaiton. The biggest changes here are that
// most methods don't use GDBaseArray directly, and instead create the GDArray
// or TypedArray subclasses where appropriate.
@pragma('vm:entry-point')
class GDBaseArray extends BuiltinType {
  static const int _size = 8;
  static final _ArrayBindings _bindings = _ArrayBindings();
  static final sTypeInfo = BuiltinTypeInfo<GDBaseArray>(
    className: StringName.fromString('Array'),
    variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
    size: _size,
    constructObjectDefault: () => GDArray(),
    constructCopy: (ptr) => GDArray.copyPtr(ptr),
  );

  @override
  BuiltinTypeInfo<GDBaseArray> get typeInfo => sTypeInfo;

  static void initBindingsConstructorDestructor() {
    _bindings.constructor_0 = gde.variantGetConstructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY, 0);
    _bindings.constructor_1 = gde.variantGetConstructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY, 1);
    _bindings.constructor_2 = gde.variantGetConstructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY, 2);
    _bindings.constructor_3 = gde.variantGetConstructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY, 3);
    _bindings.constructor_4 = gde.variantGetConstructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY, 4);
    _bindings.constructor_5 = gde.variantGetConstructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY, 5);
    _bindings.constructor_6 = gde.variantGetConstructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY, 6);
    _bindings.constructor_7 = gde.variantGetConstructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY, 7);
    _bindings.constructor_8 = gde.variantGetConstructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY, 8);
    _bindings.constructor_9 = gde.variantGetConstructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY, 9);
    _bindings.constructor_10 = gde.variantGetConstructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY, 10);
    _bindings.constructor_11 = gde.variantGetConstructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY, 11);
    _bindings.constructor_12 = gde.variantGetConstructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY, 12);
    _bindings.destructor = gde.variantGetDestructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY);
  }

  static void initBindings() {
    initBindingsConstructorDestructor();

    _bindings.methodSize = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('size'),
      3173160232,
    );
    _bindings.methodIsEmpty = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('is_empty'),
      3918633141,
    );
    _bindings.methodClear = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('clear'),
      3218959716,
    );
    _bindings.methodHash = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('hash'),
      3173160232,
    );
    _bindings.methodAssign = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('assign'),
      2307260970,
    );
    _bindings.methodPushBack = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('push_back'),
      3316032543,
    );
    _bindings.methodPushFront = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('push_front'),
      3316032543,
    );
    _bindings.methodAppend = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('append'),
      3316032543,
    );
    _bindings.methodAppendArray = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('append_array'),
      2307260970,
    );
    _bindings.methodResize = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('resize'),
      848867239,
    );
    _bindings.methodInsert = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('insert'),
      3176316662,
    );
    _bindings.methodRemoveAt = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('remove_at'),
      2823966027,
    );
    _bindings.methodFill = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('fill'),
      3316032543,
    );
    _bindings.methodErase = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('erase'),
      3316032543,
    );
    _bindings.methodFront = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('front'),
      1460142086,
    );
    _bindings.methodBack = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('back'),
      1460142086,
    );
    _bindings.methodPickRandom = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('pick_random'),
      1460142086,
    );
    _bindings.methodFind = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('find'),
      2336346817,
    );
    _bindings.methodRfind = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('rfind'),
      2336346817,
    );
    _bindings.methodCount = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('count'),
      1481661226,
    );
    _bindings.methodHas = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('has'),
      3680194679,
    );
    _bindings.methodPopBack = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('pop_back'),
      1321915136,
    );
    _bindings.methodPopFront = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('pop_front'),
      1321915136,
    );
    _bindings.methodPopAt = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('pop_at'),
      3518259424,
    );
    _bindings.methodSort = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('sort'),
      3218959716,
    );
    _bindings.methodSortCustom = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('sort_custom'),
      3470848906,
    );
    _bindings.methodShuffle = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('shuffle'),
      3218959716,
    );
    _bindings.methodBsearch = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('bsearch'),
      3372222236,
    );
    _bindings.methodBsearchCustom = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('bsearch_custom'),
      161317131,
    );
    _bindings.methodReverse = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('reverse'),
      3218959716,
    );
    _bindings.methodDuplicate = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('duplicate'),
      636440122,
    );
    _bindings.methodSlice = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('slice'),
      1393718243,
    );
    _bindings.methodFilter = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('filter'),
      4075186556,
    );
    _bindings.methodMap = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('map'),
      4075186556,
    );
    _bindings.methodReduce = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('reduce'),
      4272450342,
    );
    _bindings.methodAny = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('any'),
      4129521963,
    );
    _bindings.methodAll = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('all'),
      4129521963,
    );
    _bindings.methodMax = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('max'),
      1460142086,
    );
    _bindings.methodMin = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('min'),
      1460142086,
    );
    _bindings.methodIsTyped = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('is_typed'),
      3918633141,
    );
    _bindings.methodIsSameTyped = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('is_same_typed'),
      2988181878,
    );
    _bindings.methodGetTypedBuiltin = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('get_typed_builtin'),
      3173160232,
    );
    _bindings.methodGetTypedClassName = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('get_typed_class_name'),
      1825232092,
    );
    _bindings.methodGetTypedScript = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('get_typed_script'),
      1460142086,
    );
    _bindings.methodMakeReadOnly = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('make_read_only'),
      3218959716,
    );
    _bindings.methodIsReadOnly = gde.variantGetBuiltinMethod(
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
      StringName.fromString('is_read_only'),
      3918633141,
    );
    _bindings.indexedSetter = gde.variantGetIndexedSetter(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY);
    _bindings.indexedGetter = gde.variantGetIndexedGetter(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY);
  }

  GDBaseArray.fromVariantPtr(GDExtensionVariantPtr ptr)
      : super(_size, _bindings.destructor) {
    final c = getToTypeConstructor(
        GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY);
    c!(nativePtr.cast(), ptr);
  }

  GDBaseArray() : super(_size, _bindings.destructor) {
    using((arena) {
      Pointer<Pointer<Void>> ptrArgArray = nullptr;
      final void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>)
          ctor = _bindings.constructor_0!.asFunction();
      ctor(nativePtr.cast(), ptrArgArray);
    });
  }

  GDBaseArray.copyPtr(GDExtensionConstTypePtr ptr)
      : super(_size, _bindings.destructor) {
    gde.callBuiltinConstructor(_bindings.constructor_1!, nativePtr.cast(), [
      ptr.cast(),
    ]);
  }
  @override
  void constructCopy(GDExtensionTypePtr ptr) {
    gde.callBuiltinConstructor(_bindings.constructor_1!, ptr, [
      nativePtr.cast(),
    ]);
  }

  GDBaseArray.copy(
    final GDBaseArray from,
  ) : super(_size, _bindings.destructor) {
    using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      (ptrArgArray + 0).value = from.nativePtr.cast();
      final void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>)
          ctor = _bindings.constructor_1!.asFunction();
      ctor(nativePtr.cast(), ptrArgArray);
    });
  }

  GDBaseArray.fromBaseTypeClassNameScript(
    final GDBaseArray base,
    final int type,
    final String className,
    final Variant script,
  ) : super(_size, _bindings.destructor) {
    using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 4);
      (ptrArgArray + 0).value = base.nativePtr.cast();
      final typePtr = arena.allocate<Int64>(sizeOf<Int64>())..value = type;
      (ptrArgArray + 1).value = typePtr.cast();
      final gdclassName = StringName.fromString(className);
      (ptrArgArray + 2).value = gdclassName.nativePtr.cast();
      (ptrArgArray + 3).value = script.nativePtr.cast();
      final void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>)
          ctor = _bindings.constructor_2!.asFunction();
      ctor(nativePtr.cast(), ptrArgArray);
    });
  }

  GDBaseArray.fromPackedByteArray(
    final PackedByteArray from,
  ) : super(_size, _bindings.destructor) {
    using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      (ptrArgArray + 0).value = from.nativePtr.cast();
      final void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>)
          ctor = _bindings.constructor_3!.asFunction();
      ctor(nativePtr.cast(), ptrArgArray);
    });
  }

  GDBaseArray.fromPackedInt32Array(
    final PackedInt32Array from,
  ) : super(_size, _bindings.destructor) {
    using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      (ptrArgArray + 0).value = from.nativePtr.cast();
      final void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>)
          ctor = _bindings.constructor_4!.asFunction();
      ctor(nativePtr.cast(), ptrArgArray);
    });
  }

  GDBaseArray.fromPackedInt64Array(
    final PackedInt64Array from,
  ) : super(_size, _bindings.destructor) {
    using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      (ptrArgArray + 0).value = from.nativePtr.cast();
      final void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>)
          ctor = _bindings.constructor_5!.asFunction();
      ctor(nativePtr.cast(), ptrArgArray);
    });
  }

  GDBaseArray.fromPackedFloat32Array(
    final PackedFloat32Array from,
  ) : super(_size, _bindings.destructor) {
    using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      (ptrArgArray + 0).value = from.nativePtr.cast();
      final void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>)
          ctor = _bindings.constructor_6!.asFunction();
      ctor(nativePtr.cast(), ptrArgArray);
    });
  }

  GDBaseArray.fromPackedFloat64Array(
    final PackedFloat64Array from,
  ) : super(_size, _bindings.destructor) {
    using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      (ptrArgArray + 0).value = from.nativePtr.cast();
      final void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>)
          ctor = _bindings.constructor_7!.asFunction();
      ctor(nativePtr.cast(), ptrArgArray);
    });
  }

  GDBaseArray.fromPackedStringArray(
    final PackedStringArray from,
  ) : super(_size, _bindings.destructor) {
    using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      (ptrArgArray + 0).value = from.nativePtr.cast();
      final void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>)
          ctor = _bindings.constructor_8!.asFunction();
      ctor(nativePtr.cast(), ptrArgArray);
    });
  }

  GDBaseArray.fromPackedVector2Array(
    final PackedVector2Array from,
  ) : super(_size, _bindings.destructor) {
    using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      (ptrArgArray + 0).value = from.nativePtr.cast();
      final void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>)
          ctor = _bindings.constructor_9!.asFunction();
      ctor(nativePtr.cast(), ptrArgArray);
    });
  }

  GDBaseArray.fromPackedVector3Array(
    final PackedVector3Array from,
  ) : super(_size, _bindings.destructor) {
    using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      (ptrArgArray + 0).value = from.nativePtr.cast();
      final void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>)
          ctor = _bindings.constructor_10!.asFunction();
      ctor(nativePtr.cast(), ptrArgArray);
    });
  }

  GDBaseArray.fromPackedColorArray(
    final PackedColorArray from,
  ) : super(_size, _bindings.destructor) {
    using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      (ptrArgArray + 0).value = from.nativePtr.cast();
      final void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>)
          ctor = _bindings.constructor_11!.asFunction();
      ctor(nativePtr.cast(), ptrArgArray);
    });
  }

  GDBaseArray.fromPackedVector4Array(
    final PackedVector4Array from,
  ) : super(_size, _bindings.destructor) {
    using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      (ptrArgArray + 0).value = from.nativePtr.cast();
      final void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>)
          ctor = _bindings.constructor_12!.asFunction();
      ctor(nativePtr.cast(), ptrArgArray);
    });
  }

  int size() {
    return using((arena) {
      Pointer<Pointer<Void>> ptrArgArray = nullptr;
      final retPtr = arena.allocate<Int64>(sizeOf<Int64>());
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodSize!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 0);
      return retPtr.value;
    });
  }

  void clear() {
    using((arena) {
      Pointer<Pointer<Void>> ptrArgArray = nullptr;
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodClear!.asFunction();
      m(nativePtr.cast(), ptrArgArray, nullptr.cast(), 0);
    });
  }

  int hash() {
    return using((arena) {
      Pointer<Pointer<Void>> ptrArgArray = nullptr;
      final retPtr = arena.allocate<Int64>(sizeOf<Int64>());
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodHash!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 0);
      return retPtr.value;
    });
  }

  void assign(GDArray array) {
    using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      (ptrArgArray + 0).value = array.nativePtr.cast();
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodAssign!.asFunction();
      m(nativePtr.cast(), ptrArgArray, nullptr.cast(), 1);
    });
  }

  void pushBack(Variant value) {
    using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      (ptrArgArray + 0).value = value.nativePtr.cast();
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodPushBack!.asFunction();
      m(nativePtr.cast(), ptrArgArray, nullptr.cast(), 1);
    });
  }

  void pushFront(Variant value) {
    using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      (ptrArgArray + 0).value = value.nativePtr.cast();
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodPushFront!.asFunction();
      m(nativePtr.cast(), ptrArgArray, nullptr.cast(), 1);
    });
  }

  void append(Variant value) {
    using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      (ptrArgArray + 0).value = value.nativePtr.cast();
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodAppend!.asFunction();
      m(nativePtr.cast(), ptrArgArray, nullptr.cast(), 1);
    });
  }

  void appendArray(GDArray array) {
    using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      (ptrArgArray + 0).value = array.nativePtr.cast();
      void Function(
          GDExtensionTypePtr,
          Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr,
          int) m = _bindings.methodAppendArray!.asFunction();
      m(nativePtr.cast(), ptrArgArray, nullptr.cast(), 1);
    });
  }

  int resize(int size) {
    return using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      final sizePtr = arena.allocate<Int64>(sizeOf<Int64>())..value = size;
      (ptrArgArray + 0).value = sizePtr.cast();
      final retPtr = arena.allocate<Int64>(sizeOf<Int64>());
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodResize!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 1);
      return retPtr.value;
    });
  }

  int insert(int position, Variant value) {
    return using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 2);
      final positionPtr = arena.allocate<Int64>(sizeOf<Int64>())
        ..value = position;
      (ptrArgArray + 0).value = positionPtr.cast();
      (ptrArgArray + 1).value = value.nativePtr.cast();
      final retPtr = arena.allocate<Int64>(sizeOf<Int64>());
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodInsert!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 2);
      return retPtr.value;
    });
  }

  void removeAt(int position) {
    using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      final positionPtr = arena.allocate<Int64>(sizeOf<Int64>())
        ..value = position;
      (ptrArgArray + 0).value = positionPtr.cast();
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodRemoveAt!.asFunction();
      m(nativePtr.cast(), ptrArgArray, nullptr.cast(), 1);
    });
  }

  void fill(Variant value) {
    using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      (ptrArgArray + 0).value = value.nativePtr.cast();
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodFill!.asFunction();
      m(nativePtr.cast(), ptrArgArray, nullptr.cast(), 1);
    });
  }

  void erase(Variant value) {
    using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      (ptrArgArray + 0).value = value.nativePtr.cast();
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodErase!.asFunction();
      m(nativePtr.cast(), ptrArgArray, nullptr.cast(), 1);
    });
  }

  Variant front() {
    return using((arena) {
      Pointer<Pointer<Void>> ptrArgArray = nullptr;
      final retVal = Variant();
      final retPtr = retVal.nativePtr;
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodFront!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 0);
      return retVal;
    });
  }

  Variant back() {
    return using((arena) {
      Pointer<Pointer<Void>> ptrArgArray = nullptr;
      final retVal = Variant();
      final retPtr = retVal.nativePtr;
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodBack!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 0);
      return retVal;
    });
  }

  Variant pickRandom() {
    return using((arena) {
      Pointer<Pointer<Void>> ptrArgArray = nullptr;
      final retVal = Variant();
      final retPtr = retVal.nativePtr;
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodPickRandom!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 0);
      return retVal;
    });
  }

  int find(Variant what, {int from = 0}) {
    return using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 2);
      (ptrArgArray + 0).value = what.nativePtr.cast();
      final fromPtr = arena.allocate<Int64>(sizeOf<Int64>())..value = from;
      (ptrArgArray + 1).value = fromPtr.cast();
      final retPtr = arena.allocate<Int64>(sizeOf<Int64>());
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodFind!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 2);
      return retPtr.value;
    });
  }

  int rfind(Variant what, {int from = -1}) {
    return using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 2);
      (ptrArgArray + 0).value = what.nativePtr.cast();
      final fromPtr = arena.allocate<Int64>(sizeOf<Int64>())..value = from;
      (ptrArgArray + 1).value = fromPtr.cast();
      final retPtr = arena.allocate<Int64>(sizeOf<Int64>());
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodRfind!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 2);
      return retPtr.value;
    });
  }

  int count(Variant value) {
    return using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      (ptrArgArray + 0).value = value.nativePtr.cast();
      final retPtr = arena.allocate<Int64>(sizeOf<Int64>());
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodCount!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 1);
      return retPtr.value;
    });
  }

  bool has(Variant value) {
    return using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      (ptrArgArray + 0).value = value.nativePtr.cast();
      final retPtr = arena.allocate<Bool>(sizeOf<Bool>());
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodHas!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 1);
      return retPtr.value;
    });
  }

  Variant popBack() {
    return using((arena) {
      Pointer<Pointer<Void>> ptrArgArray = nullptr;
      final retVal = Variant();
      final retPtr = retVal.nativePtr;
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodPopBack!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 0);
      return retVal;
    });
  }

  Variant popFront() {
    return using((arena) {
      Pointer<Pointer<Void>> ptrArgArray = nullptr;
      final retVal = Variant();
      final retPtr = retVal.nativePtr;
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodPopFront!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 0);
      return retVal;
    });
  }

  Variant popAt(int position) {
    return using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      final positionPtr = arena.allocate<Int64>(sizeOf<Int64>())
        ..value = position;
      (ptrArgArray + 0).value = positionPtr.cast();
      final retVal = Variant();
      final retPtr = retVal.nativePtr;
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodPopAt!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 1);
      return retVal;
    });
  }

  void sort() {
    using((arena) {
      Pointer<Pointer<Void>> ptrArgArray = nullptr;
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodSort!.asFunction();
      m(nativePtr.cast(), ptrArgArray, nullptr.cast(), 0);
    });
  }

  void sortCustom(Callable func) {
    using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      (ptrArgArray + 0).value = func.nativePtr.cast();
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodSortCustom!.asFunction();
      m(nativePtr.cast(), ptrArgArray, nullptr.cast(), 1);
    });
  }

  void shuffle() {
    using((arena) {
      Pointer<Pointer<Void>> ptrArgArray = nullptr;
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodShuffle!.asFunction();
      m(nativePtr.cast(), ptrArgArray, nullptr.cast(), 0);
    });
  }

  int bsearch(Variant value, {bool before = true}) {
    return using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 2);
      (ptrArgArray + 0).value = value.nativePtr.cast();
      final beforePtr = arena.allocate<Bool>(sizeOf<Bool>())..value = before;
      (ptrArgArray + 1).value = beforePtr.cast();
      final retPtr = arena.allocate<Int64>(sizeOf<Int64>());
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodBsearch!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 2);
      return retPtr.value;
    });
  }

  int bsearchCustom(Variant value, Callable func, {bool before = true}) {
    return using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 3);
      (ptrArgArray + 0).value = value.nativePtr.cast();
      (ptrArgArray + 1).value = func.nativePtr.cast();
      final beforePtr = arena.allocate<Bool>(sizeOf<Bool>())..value = before;
      (ptrArgArray + 2).value = beforePtr.cast();
      final retPtr = arena.allocate<Int64>(sizeOf<Int64>());
      void Function(
          GDExtensionTypePtr,
          Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr,
          int) m = _bindings.methodBsearchCustom!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 3);
      return retPtr.value;
    });
  }

  void reverse() {
    using((arena) {
      Pointer<Pointer<Void>> ptrArgArray = nullptr;
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodReverse!.asFunction();
      m(nativePtr.cast(), ptrArgArray, nullptr.cast(), 0);
    });
  }

  GDArray duplicate({bool deep = false}) {
    return using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      final deepPtr = arena.allocate<Bool>(sizeOf<Bool>())..value = deep;
      (ptrArgArray + 0).value = deepPtr.cast();
      final retVal = GDArray();
      final retPtr = retVal.nativePtr;
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodDuplicate!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 1);
      return retVal;
    });
  }

  GDArray slice(int begin,
      {int end = 2147483647, int step = 1, bool deep = false}) {
    return using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 4);
      final beginPtr = arena.allocate<Int64>(sizeOf<Int64>())..value = begin;
      (ptrArgArray + 0).value = beginPtr.cast();
      final endPtr = arena.allocate<Int64>(sizeOf<Int64>())..value = end;
      (ptrArgArray + 1).value = endPtr.cast();
      final stepPtr = arena.allocate<Int64>(sizeOf<Int64>())..value = step;
      (ptrArgArray + 2).value = stepPtr.cast();
      final deepPtr = arena.allocate<Bool>(sizeOf<Bool>())..value = deep;
      (ptrArgArray + 3).value = deepPtr.cast();
      final retVal = GDArray();
      final retPtr = retVal.nativePtr;
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodSlice!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 4);
      return retVal;
    });
  }

  GDArray filter(Callable method) {
    return using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      (ptrArgArray + 0).value = method.nativePtr.cast();
      final retVal = GDArray();
      final retPtr = retVal.nativePtr;
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodFilter!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 1);
      return retVal;
    });
  }

  bool all(Callable method) {
    return using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      (ptrArgArray + 0).value = method.nativePtr.cast();
      final retPtr = arena.allocate<Bool>(sizeOf<Bool>());
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodAll!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 1);
      return retPtr.value;
    });
  }

  Variant max() {
    return using((arena) {
      Pointer<Pointer<Void>> ptrArgArray = nullptr;
      final retVal = Variant();
      final retPtr = retVal.nativePtr;
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodMax!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 0);
      return retVal;
    });
  }

  Variant min() {
    return using((arena) {
      Pointer<Pointer<Void>> ptrArgArray = nullptr;
      final retVal = Variant();
      final retPtr = retVal.nativePtr;
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodMin!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 0);
      return retVal;
    });
  }

  bool isTyped() {
    return using((arena) {
      Pointer<Pointer<Void>> ptrArgArray = nullptr;
      final retPtr = arena.allocate<Bool>(sizeOf<Bool>());
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodIsTyped!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 0);
      return retPtr.value;
    });
  }

  bool isSameTyped(GDBaseArray array) {
    return using((arena) {
      final ptrArgArray = arena.allocate<GDExtensionConstTypePtr>(
          sizeOf<GDExtensionConstTypePtr>() * 1);
      (ptrArgArray + 0).value = array.nativePtr.cast();
      final retPtr = arena.allocate<Bool>(sizeOf<Bool>());
      void Function(
          GDExtensionTypePtr,
          Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr,
          int) m = _bindings.methodIsSameTyped!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 1);
      return retPtr.value;
    });
  }

  int getTypedBuiltin() {
    return using((arena) {
      Pointer<Pointer<Void>> ptrArgArray = nullptr;
      final retPtr = arena.allocate<Int64>(sizeOf<Int64>());
      void Function(
          GDExtensionTypePtr,
          Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr,
          int) m = _bindings.methodGetTypedBuiltin!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 0);
      return retPtr.value;
    });
  }

  String getTypedClassName() {
    return using((arena) {
      Pointer<Pointer<Void>> ptrArgArray = nullptr;
      final retVal = GDString();
      final retPtr = retVal.nativePtr;
      void Function(
          GDExtensionTypePtr,
          Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr,
          int) m = _bindings.methodGetTypedClassName!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 0);
      return retVal.toDartString();
    });
  }

  Variant getTypedScript() {
    return using((arena) {
      Pointer<Pointer<Void>> ptrArgArray = nullptr;
      final retVal = Variant();
      final retPtr = retVal.nativePtr;
      void Function(
          GDExtensionTypePtr,
          Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr,
          int) m = _bindings.methodGetTypedScript!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 0);
      return retVal;
    });
  }

  void makeReadOnly() {
    using((arena) {
      Pointer<Pointer<Void>> ptrArgArray = nullptr;
      void Function(
          GDExtensionTypePtr,
          Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr,
          int) m = _bindings.methodMakeReadOnly!.asFunction();
      m(nativePtr.cast(), ptrArgArray, nullptr.cast(), 0);
    });
  }

  bool isReadOnly() {
    return using((arena) {
      Pointer<Pointer<Void>> ptrArgArray = nullptr;
      final retPtr = arena.allocate<Bool>(sizeOf<Bool>());
      void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,
          GDExtensionTypePtr, int) m = _bindings.methodIsReadOnly!.asFunction();
      m(nativePtr.cast(), ptrArgArray, retPtr.cast(), 0);
      return retPtr.value;
    });
  }
}

class _ArrayIterator implements Iterator<Variant> {
  final GDArray array;

  int _index = -1;
  final int _initialSize;

  _ArrayIterator(this.array) : _initialSize = array.size();

  @override
  Variant get current => array[_index];

  @override
  bool moveNext() {
    if (_initialSize != array.size()) throw ConcurrentModificationError(array);

    _index++;
    return _index < _initialSize;
  }
}

@pragma('vm:entry-point')
class GDArray extends GDBaseArray with Iterable<Variant> {
  GDArray() : super();

  GDArray.fromVariantPtr(Pointer<Void> ptr) : super.fromVariantPtr(ptr);
  GDArray.copyPtr(Pointer<Void> ptr) : super.copyPtr(ptr);

  Variant operator [](int index) {
    final self = Variant(this);
    final ret = gde.variantGetIndexed(self, index);
    return ret;
  }

  void operator []=(int index, Variant value) {
    final self = Variant(this);
    gde.variantSetIndexed(self, index, value);
  }

  @override
  Iterator<Variant> get iterator => _ArrayIterator(this);

  static BuiltinTypeInfo<GDArray> sTypeInfo = BuiltinTypeInfo<GDArray>(
    className: StringName.fromString('Array'),
    variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_ARRAY,
    constructObjectDefault: () => GDArray(),
    size: GDBaseArray.sTypeInfo.size,
    constructCopy: (ptr) => GDArray.copyPtr(ptr),
  );
}

class _ArrayBindings {
  GDExtensionPtrConstructor? constructor_0;
  GDExtensionPtrConstructor? constructor_1;
  GDExtensionPtrConstructor? constructor_2;
  GDExtensionPtrConstructor? constructor_3;
  GDExtensionPtrConstructor? constructor_4;
  GDExtensionPtrConstructor? constructor_5;
  GDExtensionPtrConstructor? constructor_6;
  GDExtensionPtrConstructor? constructor_7;
  GDExtensionPtrConstructor? constructor_8;
  GDExtensionPtrConstructor? constructor_9;
  GDExtensionPtrConstructor? constructor_10;
  GDExtensionPtrConstructor? constructor_11;
  GDExtensionPtrConstructor? constructor_12;
  GDExtensionPtrDestructor? destructor;
  GDExtensionPtrBuiltInMethod? methodSize;
  GDExtensionPtrBuiltInMethod? methodIsEmpty;
  GDExtensionPtrBuiltInMethod? methodClear;
  GDExtensionPtrBuiltInMethod? methodHash;
  GDExtensionPtrBuiltInMethod? methodAssign;
  GDExtensionPtrBuiltInMethod? methodPushBack;
  GDExtensionPtrBuiltInMethod? methodPushFront;
  GDExtensionPtrBuiltInMethod? methodAppend;
  GDExtensionPtrBuiltInMethod? methodAppendArray;
  GDExtensionPtrBuiltInMethod? methodResize;
  GDExtensionPtrBuiltInMethod? methodInsert;
  GDExtensionPtrBuiltInMethod? methodRemoveAt;
  GDExtensionPtrBuiltInMethod? methodFill;
  GDExtensionPtrBuiltInMethod? methodErase;
  GDExtensionPtrBuiltInMethod? methodFront;
  GDExtensionPtrBuiltInMethod? methodBack;
  GDExtensionPtrBuiltInMethod? methodPickRandom;
  GDExtensionPtrBuiltInMethod? methodFind;
  GDExtensionPtrBuiltInMethod? methodRfind;
  GDExtensionPtrBuiltInMethod? methodCount;
  GDExtensionPtrBuiltInMethod? methodHas;
  GDExtensionPtrBuiltInMethod? methodPopBack;
  GDExtensionPtrBuiltInMethod? methodPopFront;
  GDExtensionPtrBuiltInMethod? methodPopAt;
  GDExtensionPtrBuiltInMethod? methodSort;
  GDExtensionPtrBuiltInMethod? methodSortCustom;
  GDExtensionPtrBuiltInMethod? methodShuffle;
  GDExtensionPtrBuiltInMethod? methodBsearch;
  GDExtensionPtrBuiltInMethod? methodBsearchCustom;
  GDExtensionPtrBuiltInMethod? methodReverse;
  GDExtensionPtrBuiltInMethod? methodDuplicate;
  GDExtensionPtrBuiltInMethod? methodSlice;
  GDExtensionPtrBuiltInMethod? methodFilter;
  GDExtensionPtrBuiltInMethod? methodMap;
  GDExtensionPtrBuiltInMethod? methodReduce;
  GDExtensionPtrBuiltInMethod? methodAny;
  GDExtensionPtrBuiltInMethod? methodAll;
  GDExtensionPtrBuiltInMethod? methodMax;
  GDExtensionPtrBuiltInMethod? methodMin;
  GDExtensionPtrBuiltInMethod? methodIsTyped;
  GDExtensionPtrBuiltInMethod? methodIsSameTyped;
  GDExtensionPtrBuiltInMethod? methodGetTypedBuiltin;
  GDExtensionPtrBuiltInMethod? methodGetTypedClassName;
  GDExtensionPtrBuiltInMethod? methodGetTypedScript;
  GDExtensionPtrBuiltInMethod? methodMakeReadOnly;
  GDExtensionPtrBuiltInMethod? methodIsReadOnly;
  GDExtensionPtrIndexedSetter? indexedSetter;
  GDExtensionPtrIndexedGetter? indexedGetter;
}
