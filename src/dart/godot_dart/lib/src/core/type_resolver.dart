import 'package:quiver/collection.dart';

/// Created by the godot_dart bindings generator to map
/// godot script paths to types and visa versa
class TypeResolver {
  final typeBiMap = HashBiMap<String, Type>();

  TypeResolver(Map<String, Type> map) {
    typeBiMap.addEntries(map.entries);
  }

  String? pathFromType(Type type) {
    return typeBiMap.inverse[type];
  }

  Type? typeFromPath(path) {
    return typeBiMap[path];
  }
}
