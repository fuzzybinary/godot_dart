extension StringHelpers on String {
  String toSnakeCase() {
    return replaceAllMapped(RegExp('(.)([A-Z][a-z]+)'), (match) {
      return '${match.group(1)}_${match.group(2)}';
    })
        .replaceAllMapped(RegExp('([a-z0-9])([A-Z])'), (match) {
          return '${match.group(1)}_${match.group(2)}';
        })
        .replaceAll('2_D', '2d')
        .replaceAll('3_D', '3d')
        .toLowerCase();
  }

  String toUpperSnakeCase() {
    return toSnakeCase().toUpperCase();
  }

  String toLowerCamelCase() {
    return toLowerCase().replaceAllMapped(RegExp('_([a-z])'), (match) {
      return '${match.group(1)?.toUpperCase()}';
    });
  }

  String toUpperCamelCase() {
    var lowerCamel = toLowerCamelCase();
    return lowerCamel.replaceRange(
        0, 1, lowerCamel[0].toUpperCase().toString());
  }

  String lowerFirstLetter() {
    return replaceRange(0, 1, this[0].toLowerCase().toString());
  }
}
