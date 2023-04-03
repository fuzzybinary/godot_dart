import 'godot_api_info.dart';

final dartTypes = [
  'Nil',
  'void',
  'bool',
  'real_t',
  'float',
  'double',
  'int',
  'int8_t',
  'uint8_t',
  'int16_t',
  'uint16_t',
  'int32_t',
  'uint32_t',
  'int64_t',
  'uint64_t',
];

/// Checks to see if the requested type has a type we can
/// utilize directly from Dart (PODs mostly)
bool hasDartType(String typeName) {
  return dartTypes.contains(typeName);
}

final typeToFFIType = {
  'bool': 'Bool',
  'real_t': 'Float',
  'float': 'Float',
  'double': 'Double',
  'int': 'Int',
  'int8_t': 'Int8',
  'uint8_t': 'Uint8',
  'int16_t': 'Int16',
  'uint16_t': 'Uint16',
  'int32_t': 'Int32',
  'uint32_t': 'Uint32',
  'int64_t': 'Int64',
  'uint64_t': 'Uint64',
  'void': 'Void',
};

String? getFFIType(TypeInfo type) {
  return typeToFFIType[type.godotType];
}

String? getFFITypeFromString(String type) {
  return typeToFFIType[type];
}

final defaultValueForType = {'bool': 'true', 'double': '0.0', 'int': '0'};

String getDefaultValueForType(TypeInfo info) {
  if (info.isOptional) {
    return 'null';
  } else if (defaultValueForType.containsKey(info.dartType)) {
    return defaultValueForType[info.dartType]!;
  } else if (info.dartType == 'String') {
    return "''";
  } else if (info.godotType.startsWith('enum::') ||
      info.godotType.startsWith('bitfield::')) {
    // TODO: I'd rather this gave a real value
    return '${info.dartType}.values[0]';
  } else if (info.dartType.contains('Pointer<')) {
    return 'nullptr';
  } else {
    return '${info.dartType}()';
  }
}

String getCorrectedType(String type, {String? meta}) {
  const typeConversion = {
    'float': 'double',
    'Nil': 'Variant',
    'String': 'GDString',
    'Object': 'GodotObject',
    'real_t': 'double',
    'int8_t': 'int',
    'uint8_t': 'int',
    'int16_t': 'int',
    'uint16_t': 'int',
    'int32_t': 'int',
    'uint32_t': 'int',
    'int64_t': 'int',
    'uint64_t': 'int',
  };
  if (meta != null) {
    if (meta.contains('int')) {
      return 'int';
    } else if (typeConversion.containsKey(meta)) {
      return typeConversion[meta]!;
    }
  }
  if (typeConversion.containsKey(type)) {
    return typeConversion[type]!;
  }

  if (type.startsWith('typedarray::')) {
    return '${type.replaceFirst('typedarray::', 'TypedArray<')}>';
  }
  if (type.startsWith('enum::') || type.startsWith('bitfield::')) {
    return getEnumName(type, null);
  }

  return type;
}

// Also works for bitfields
String getEnumName(String enumName, String? className) {
  final name = (className ?? '') +
      enumName
          .replaceFirst('enum::', '')
          .replaceAll('bitfield::', '')
          .replaceAll('.', '');
  // Special case replacements
  if (name == 'Error') {
    return 'GDError';
  }
  return name;
}

/// Fix any names that might be reserved words in dart
String escapeName(String name) {
  const map = {
    'with': 'withVal',
    'class': 'klass',
    'bool': 'boolVal',
    'int': 'intVal',
    'default': 'defaultVal',
    'case': '_case',
    'switch': 'switchVal',
    'new': 'newVal',
    'enum': 'enumVal',
    'in': 'inVal',
    'var': 'variant',
    'final': 'finalVal',
    'args': 'argsParam',
  };

  return map[name] ?? name;
}

String escapeMethodName(String name) {
  if (name == 'new') {
    return 'create';
  }

  return name;
}
