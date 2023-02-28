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

bool argumentNeedsAllocation(Map<String, dynamic> argument) {
  final type = argument['type'] as String;
  return dartTypes.contains(type);
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
};

String getFFIType(String type) {
  if (typeToFFIType.containsKey(type)) {
    return typeToFFIType[type]!;
  }

  return type;
}

String getCorrectedType(String type) {
  switch (type) {
    case 'String':
    case 'Object':
      return 'GD$type';

    case 'float':
    case 'real_t':
      return 'double';
  }

  if (type.startsWith('int') || type.startsWith('uint')) {
    return 'int';
  }

  return type;
}