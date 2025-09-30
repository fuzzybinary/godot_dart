import 'dart:ffi';

import 'package:meta/meta.dart';

import '../gen/builtins.dart';
import '../variant/variant.dart';
import 'core.dart';

/// Native functions accessible from Dart. These are defined in C++ at
/// dart_bindings_c_interface.cpp
sealed class GDNativeInterface {
  @Native<Void Function(Handle)>(symbol: 'dart_print')
  external static void dartPrint(String string);

  @Native<Void Function(Handle)>(symbol: 'bind_class')
  external static void bindClass(ExtensionTypeInfo<dynamic> typeInfo);

  @Native<Void Function(Handle)>(symbol: 'set_type_resolver')
  external static void setTypeResolver(TypeResolver typeResolver);

  @Native<Void Function(Handle, Handle)>(symbol: 'bind_method')
  external static void bindMethod(
      ExtensionTypeInfo<dynamic> typeInfo, MethodInfo<dynamic> methodInfo);

  @Native<Void Function(Handle, Handle)>(symbol: 'add_property')
  external static void addProperty(
      ExtensionTypeInfo<dynamic> typeInfo, PropertyInfo propertyInfo);

  @Native<Handle Function(Pointer<Void>)>(symbol: 'gd_string_to_dart_string')
  external static String? _gdStringToDartString(Pointer<Void> stringPtr);

  static String gdStringToString(GDString string) {
    return _gdStringToDartString(string.nativePtr.cast()) ?? '';
  }

  @Native<Handle Function(Pointer<Void>)>(symbol: 'gd_object_to_dart_object')
  external static Object? gdObjectToDartObject(Pointer<Void> objectPtr);

  @Native<Void Function(Pointer<Void>)>(symbol: 'finalize_variant')
  external static void finalizeVariant(Pointer<Void> variant);

  @Native<Void Function(Pointer<Void>)>(symbol: 'finalize_builtin_object')
  external static void finalizeBuiltinObject(Pointer<Void> builtinObject);

  @Native<Void Function(Pointer<Void>)>(symbol: 'finalize_extension_object')
  external static void finalizeExtensionObject(Pointer<Void> extensionObject);

  @Native<Handle Function(Pointer<Void>)>(symbol: 'object_from_script_instance')
  external static Object? objectFromScriptInstance(
      Pointer<Void> scriptInstance);

  @Native<Handle Function(GDExtensionClassInstancePtr)>(
      symbol: 'dart_object_from_instance_binding')
  external static Object? objectFromInstanceBinding(
      GDExtensionClassInstancePtr object);

  @Native<Void Function(Handle, Handle, GDExtensionObjectPtr, Bool, Bool)>(
      symbol: 'tie_dart_to_native')
  external static void tieDartToNative(
      Object dartObj,
      ExtensionTypeInfo<dynamic> typeInfo,
      GDExtensionObjectPtr godotObj,
      bool isRefcounted,
      bool isGodotDefined);

  @Native<GDExtensionScriptInstanceDataPtr Function(GDExtensionConstObjectPtr)>(
      symbol: 'get_script_instance')
  external static GDExtensionScriptInstanceDataPtr getScriptInstance(
      GDExtensionConstObjectPtr ptr);

  @Native<Handle Function(Handle, Int64)>(symbol: 'create_signal_callable')
  external static Object createSignalCallable(
      SignalCallable callable, int instanceId);
}

@pragma('vm:entry-point')
List<Object?> _variantsToDart(
    int variantsPtrPtr, int count, List<PropertyInfo> argInfoList) {
  assert(argInfoList.length == count);
  final Pointer<Pointer<Void>> variants =
      Pointer<Pointer<Void>>.fromAddress(variantsPtrPtr);

  var result = <Object?>[];
  for (int i = 0; i < count; ++i) {
    var variantPtr = (variants + i).value;
    result.add(variantPtrToDart(variantPtr, argInfoList[i].typeInfo));
  }

  return result;
}

// Used by Signals. Convert a list of Variants into Dart Variants
// without attempting to convert to their underlying Dart types.
@pragma('vm:entry-point')
List<Variant> _variantsToDartVariants(int variantsPtrPtr, int count) {
  final Pointer<Pointer<Void>> variants =
      Pointer<Pointer<Void>>.fromAddress(variantsPtrPtr);
  return List.generate(count, (i) {
    var variantPtr = (variants + i).value;
    return Variant.fromVariantPtr(variantPtr);
  });
}

@pragma('vm:entry-point')
Object? _variantAddressToDart(int variantAddress, TypeInfo typeInfo) {
  return variantPtrToDart(Pointer<Void>.fromAddress(variantAddress), typeInfo);
}

@internal
Object? variantPtrToDart(Pointer<Void> variantPtr, TypeInfo typeInfo) {
  // What to do here? This was essentially a "cast" replacement which is why it
  // had a special case checking if it was casting to "Variant."
  if (typeInfo.variantType ==
      GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_VARIANT_MAX) {
    // Keep as variant
    return Variant.fromVariantPtr(variantPtr);
  } else {
    return convertFromVariantPtr(variantPtr);
  }
}
