import '../../godot_dart.dart';

class PropertyInfo {
  final TypeInfo typeInfo;
  final String name;
  final PropertyHint hint;
  final String hintString;
  final int flags;
  final bool isReference;

  PropertyInfo({
    required this.typeInfo,
    required this.name,
    this.hint = PropertyHint.propertyHintNone,
    this.hintString = '',
    this.flags = 6, // PropertyUsage.propertyUsageDefault
    this.isReference = false,
  });

  Dictionary asDict() {
    final dict = Dictionary();

    dict[convertToVariant('type')] = convertToVariant(typeInfo.variantType);
    dict[convertToVariant('name')] = convertToVariant(name);
    dict[convertToVariant('class_name')] = convertToVariant(typeInfo.className);
    dict[convertToVariant('hint')] = convertToVariant(hint);
    dict[convertToVariant('hint_string')] = convertToVariant(hintString);
    dict[convertToVariant('usage')] = convertToVariant(flags);

    return dict;
  }
}
