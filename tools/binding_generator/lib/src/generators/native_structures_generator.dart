import 'dart:io';

import 'package:path/path.dart' as path;

import '../code_sink.dart';
import '../common_helpers.dart';
import '../godot_api_info.dart';
import '../string_extensions.dart';
import '../type_helpers.dart';

final arrayRegex = RegExp(r'\[(?<size>\d+)\]');

class FieldInfo {
  late final String type;
  late final int? arraySize;
  late final String name;
  late final String? defaultValue;

  FieldInfo.fromString(String field) {
    final elements = field.split(' ');
    var tempType = elements[0];
    var tempName = elements[1];
    if (tempName.startsWith('*')) {
      // Actually goes with the type
      tempName = tempName.substring(1);
      tempType += '*';
    }
    final arrayMatch = arrayRegex.firstMatch(tempName);
    if (arrayMatch != null) {
      arraySize = int.parse(arrayMatch.namedGroup('size')!);
      tempName = tempName.replaceFirst(arrayRegex, '');
    } else {
      arraySize = null;
    }

    if (elements.length == 4 && elements[2] == '=') {
      defaultValue = elements[3];
    } else {
      defaultValue = null;
    }
    type = tempType;
    name = tempName;
  }
}

Future<void> generateNativeStructures(
    GodotApiInfo api, String targetDir, String buildConfig) async {
  targetDir = path.join(targetDir, 'classes');
  var directory = Directory(targetDir);
  if (!directory.existsSync()) {
    await directory.create(recursive: true);
  }

  // Holds all the exports for native structures, written as 'structs.dart' at
  // the end of generation
  var exportsString = '';

  for (final nativeStruct in api.nativeStructures.values) {
    if (hasDartType(nativeStruct.name)) {
      continue;
    }

    final destPath =
        path.join(targetDir, '${nativeStruct.name.toSnakeCase()}.dart');
    final o = CodeSink(File(destPath));

    o.write(header);

    final fields = nativeStruct.format
        .split(';')
        .map((e) => FieldInfo.fromString(e))
        .toList();

    o.p("import 'dart:ffi';");
    o.p("import '../../variant/structs.dart';");

    Set<String> usedTypes = {};

    for (final field in fields) {
      if (usedTypes.contains(field.type)) {
        continue;
      }
      usedTypes.add(field.type);
      if (api.nativeStructures.containsKey(field.type) ||
          api.engineClasses.containsKey(field.type)) {
        o.p("import '${field.type.toSnakeCase()}.dart';");
      }
      if (api.builtinClasses.containsKey(field.type) &&
          !hasDartType(field.type) &&
          !hasCustomImplementation(field.type)) {
        o.p("import '../variant/${field.type.toSnakeCase()}.dart';");
      }
    }
    o.nl();

    o.b('final class ${nativeStruct.dartName} extends Struct {', () {
      // Write fields
      for (final field in fields) {
        var dartType = getCorrectedType(field.type);
        if (field.type == 'StringName') {
          // Revert that change:
          dartType = 'StringName';
        }

        var ffiType = getFFITypeFromString(field.type);
        String? comment;
        if (field.type.endsWith('*')) {
          dartType = 'Pointer<Void>';
          ffiType = null;
        }

        if (dartType.contains('::')) {
          // Likely an enum. I know the size here is compiler specific, but for
          // now we're going to assume it's a 32-bit integer
          dartType = 'int';
          ffiType = 'Int32';
          comment = 'Instance of ${dartType.replaceAll('::', '')}';
        }

        if (comment != null) {
          o.p('/// $comment');
        }

        if (field.arraySize != null) {
          final arrayType = ffiType ?? dartType;
          o.p('@Array<$arrayType>(${field.arraySize}) external Array<$dartType> ${field.name};');
        } else {
          var annotation = '';
          if (ffiType != null) {
            annotation += '@$ffiType() ';
          } else if (!dartType.startsWith('Pointer')) {
            // Add 'Struct' to the end of the DartType
            dartType += 'Struct';
          }

          o.p('${annotation}external $dartType ${field.name};\n');
        }
      }
    }, '}');

    await o.close();

    exportsString += "import '${nativeStruct.name.toSnakeCase()}.dart';\n";
  }

  var exportsFile = File(path.join(targetDir, 'native_structures.dart'));
  var out = exportsFile.openWrite();
  out.write(header);
  out.write(exportsString);

  await out.close();
}
