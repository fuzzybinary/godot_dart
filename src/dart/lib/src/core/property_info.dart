import '../gen/global_constants.dart';

class PropertyInfo {
  final VariantType type;
  final String name;
  final String className;
  final PropertyHint hint;
  final String hintString;
  final int flags;

  PropertyInfo({
    required this.type,
    required this.name,
    this.className = '',
    this.hint = PropertyHint.propertyHintNone,
    this.hintString = '',
    this.flags = 6, // PropertyUsage.propertyUsageDefault
  });
}
