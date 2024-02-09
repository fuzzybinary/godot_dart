import '../../godot_dart.dart';

class PropertyInfo {
  final TypeInfo typeInfo;
  final String name;
  final PropertyHint hint;
  final String hintString;
  final int flags;

  PropertyInfo({
    required this.typeInfo,
    required this.name,
    this.hint = PropertyHint.propertyHintNone,
    this.hintString = '',
    this.flags = 6, // PropertyUsage.propertyUsageDefault
  });

  Dictionary asDict() {
    final dict = Dictionary();

    dict[Variant.fromObject('type')] = Variant.fromObject(typeInfo.variantType);
    dict[Variant.fromObject('name')] = Variant.fromObject(name);
    dict[Variant.fromObject('class_name')] =
        Variant.fromObject(typeInfo.className);
    dict[Variant.fromObject('hint')] = Variant.fromObject(hint);
    dict[Variant.fromObject('hint_string')] = Variant.fromObject(hintString);
    dict[Variant.fromObject('usage')] = Variant.fromObject(flags);

    return dict;
  }
}
