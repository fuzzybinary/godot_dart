import 'package:godot_dart/godot_dart.dart';

import 'godot_dart_scripts.g.dart';

class SimpleTestNode extends Node {
  static final sTypeInfo = ExtensionTypeInfo<SimpleTestNode>(
    className: StringName.fromString('SimpleTestNode'),
    parentTypeInfo: Node.sTypeInfo,
    nativeTypeName: StringName.fromString('Node'),
    isRefCounted: Node.sTypeInfo.isRefCounted,
    constructObjectDefault: () => SimpleTestNode(),
    constructFromGodotObject: (owner) => SimpleTestNode.withNonNullOwner(owner),
  );

  @override
  ExtensionTypeInfo<SimpleTestNode> get typeInfo => SimpleTestNode.sTypeInfo;

  SimpleTestNode() : super();

  SimpleTestNode.withNonNullOwner(super.owner) : super.withNonNullOwner();

  int maxSpeed = 12559;

  static void bind(TypeResolver typeResolver) {
    typeResolver.addType(sTypeInfo);
    GDNativeInterface.bindClass(SimpleTestNode.sTypeInfo);
    GDNativeInterface.addProperty(
      SimpleTestNode.sTypeInfo,
      DartPropertyInfo<SimpleTestNode, int>(
        type: int,
        name: 'maxSpeed',
        getter: (self) => self.maxSpeed,
        setter: (self, value) => self.maxSpeed = value,
      ),
    );
  }
}

void main() {
  refreshScripts();

  SimpleTestNode.bind(gde.typeResolver);
}

@pragma('vm:entry-point')
void refreshScripts() {
  populateScriptResolver();
}
