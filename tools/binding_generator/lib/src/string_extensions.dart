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
    return replaceAllMapped(RegExp('(.)_([a-z])'), (match) {
      return '${match.group(1)}${match.group(2)?.toUpperCase()}';
    });
  }

  String toUpperCamelCase() {
    var lowerCamel = toLowerCamelCase();
    return lowerCamel.replaceRange(
        0, 1, lowerCamel[0].toUpperCase().toString());
  }
}
