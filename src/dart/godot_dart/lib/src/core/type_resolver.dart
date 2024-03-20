/// Created by the godot_dart bindings generator to map
/// godot script paths to types and visa versa
abstract interface class TypeResolver {
  String? pathFromType(Type type);

  Type? typeFromPath(String path);
}
