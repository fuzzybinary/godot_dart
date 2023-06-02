import '../godot_dart.dart';

extension TNode on Node {
  T? getNodeT<T>([String? path]) {
    var typeInfo = gde.dartBindings.getGodotTypeInfo(T);
    final GDString name;
    if (path != null) {
      name = GDString.fromString(path);
    } else {
      name = GDString.fromStringName(typeInfo.className);
    }
    var node = getNode(NodePath.fromGDString(name));
    return gde.cast<T>(node, typeInfo);
  }
}
