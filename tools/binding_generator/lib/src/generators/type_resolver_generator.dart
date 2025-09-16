import 'dart:io';

import 'package:path/path.dart' as path;

import '../code_sink.dart';
import '../common_helpers.dart';
import '../godot_api_info.dart';

const imports = """
import '../core/type_resolver.dart';
import 'engine_classes.dart';
""";

Future<void> generateTypeResolver(GodotApiInfo api, String targetDir) async {
  final destPath = path.join(targetDir, 'type_resolver.g.dart');

  final o = CodeSink(File(destPath));
  o.write(header);
  o.write(imports);
  o.nl();

  o.b('extension GeneratedAdd on TypeResolver {', () {
    o.b('void addGodotStandardLibrary() {', () {
      for (final classInfo in api.engineClasses.values) {
        o.p('addType(${classInfo.dartName}.sTypeInfo);');
      }
    }, '}');
  }, '}');
}
