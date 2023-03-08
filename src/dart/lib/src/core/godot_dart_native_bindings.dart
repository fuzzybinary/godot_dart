import 'dart:ffi';

import '../../godot_dart.dart';
import 'gdextension_ffi_bindings.dart';

class GodotDartNativeBindings {
  @pragma('vm:external-name', 'GodotDartNativeBindings::bindClass')
  external void bindClass(
    Type type,
    TypeInfo typeInfo,
  );

  @pragma('vm:external-name', 'GodotDartNativeBindings::bindMethod')
  external void bindMethod(TypeInfo typeInfo, String methodName,
      TypeInfo returnType, List<TypeInfo> argTypes);

  @pragma('vm:external-name', 'GodotDartNativeBindings::gdStringToString')
  external String gdStringToString(GDString string);

  @pragma('vm:external-name', 'GodotDartNativeBindings::gdObjectToDartObject')
  external Object gdObjectToDartObject(GDExtensionObjectPtr object);
}

// Potentially move this, just here for convenience
@pragma('vm:entry-point')
Variant _convertToVariant(Object? object) {
  return convertToVariant(object);
}

@pragma('vm:entry-point')
List<Object?> _variantsToDart(Pointer<Pointer<Void>> variants, int count) {
  var result = <Object?>[];
  for (int i = 0; i < count; ++i) {
    var variant = Variant.fromPointer(variants.elementAt(i).value);
    result.add(convertFromVariant(variant));
  }

  return result;
}
