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

    dict[Variant('type')] = Variant(typeInfo.variantType);
    dict[Variant('name')] = Variant(name);
    dict[Variant('class_name')] = Variant(typeInfo.className);
    dict[Variant('hint')] = Variant(hint);
    dict[Variant('hint_string')] = Variant(hintString);
    dict[Variant('usage')] = Variant(flags);

    return dict;
  }
}
