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
}
