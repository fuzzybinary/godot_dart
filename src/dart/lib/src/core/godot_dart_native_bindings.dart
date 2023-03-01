import '../gen/variant/string_name.dart';

class GodotDartNativeBindings {
  @pragma('vm:external-name', 'GodotDartNativeBindings::bindClass')
  external void bindClass(
    Type type,
    StringName className,
    StringName parentClasSName,
  );

  @pragma('vm:external-name', 'GodotDartNativeBindings::bindMethod')
  external void bindMethod(String className, String methodName, Type returnType,
      List<Type> argTypes);
}
