import 'package:meta/meta.dart';

import '../gen/builtins.dart';
import '../gen/global_constants.dart';
import '../variant/variant.dart';
import 'type_info.dart';
import 'gdextension.dart';

@immutable
class PropertyInfo {
  @pragma('vm:entry-point')
  final Type type;

  @pragma('vm:entry-point')
  final String name;

  @pragma('vm:entry-point')
  final PropertyHint hint;

  @pragma('vm:entry-point')
  final String hintString;

  @pragma('vm:entry-point')
  final int flags;

  const PropertyInfo({
    required this.type,
    required this.name,
    this.hint = PropertyHint.none,
    this.hintString = '',
    this.flags = 6, // PropertyUsage.propertyUsageDefault
  });

  Dictionary asDict() {
    final dict = Dictionary();

    final typeInfo = gde.typeResolver.getTypeInfoByType(type);
    if (typeInfo != null) {
      dict[Variant('type')] = Variant(typeInfo.variantType);
      dict[Variant('name')] = Variant(name);
      dict[Variant('class_name')] = Variant(typeInfo.className);
      dict[Variant('hint')] = Variant(hint);
      dict[Variant('hint_string')] = Variant(hintString);
      dict[Variant('usage')] = Variant(flags);
    }

    return dict;
  }
}

// Info for Dart property bound to Godot
@immutable
class DartPropertyInfo<C, T> extends PropertyInfo {
  @pragma('vm:entry-point')
  final T Function(C) getter;

  @pragma('vm:entry-point')
  final void Function(C, T) setter;

  // Only used for properties on ExtensionTypes (not scripts)
  @pragma('vm:entry-point')
  MethodInfo<C> get getterInfo {
    return MethodInfo(
        returnInfo: this,
        name: 'get__$name',
        dartMethodCall: (self, _) => getter(self),
        args: []);
  }

  // Only used for properties on ExtensionTypes (not scripts)
  @pragma('vm:entry-point')
  MethodInfo<C> get setterInfo {
    return MethodInfo(
        name: 'set__$name',
        dartMethodCall: (self, args) => setter(self, args[0] as T),
        args: [this]);
  }

  const DartPropertyInfo({
    required super.type,
    required super.name,
    super.hint,
    super.hintString,
    super.flags,
    required this.getter,
    required this.setter,
  }) : super();
}
