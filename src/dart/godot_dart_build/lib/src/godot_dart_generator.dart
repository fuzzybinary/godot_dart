import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart' as c;
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';
import 'package:godot_dart/godot_dart.dart';
import 'package:logging/logging.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:source_gen/source_gen.dart';

const _godotScriptChecker = TypeChecker.fromRuntime(GodotScript);
// TODO: Need to make this a builder option
const godotPrefix = 'res://src';

typedef TypePathPair = ({String type, String path, bool isGlobal});

class GodotDartBuilder extends Builder {
  @override
  Future<void> build(BuildStep buildStep) async {
    final pubspecSrc = await buildStep
        .readAsString(AssetId(buildStep.inputId.package, 'pubspec.yaml'));
    final pubspec = Pubspec.parse(pubspecSrc);
    final packageName = pubspec.name;

    final assets = await buildStep
        .findAssets(Glob(r'**/*.dart', recursive: true))
        .toList();

    final libraryBuilder = c.LibraryBuilder()
      ..comments.add('GENERATED FILE - DO NOT MODIFY')
      ..directives
          .add(c.Directive.import('package:godot_dart/godot_dart.dart'));
    libraryBuilder.body.add(await _generateScriptResolver(
        buildStep, packageName, assets, libraryBuilder));
    final c.DartEmitter emitter = c.DartEmitter(useNullSafetySyntax: true);
    final DartFormatter formatter = DartFormatter();

    final outputId =
        AssetId(buildStep.inputId.package, 'godot_dart_scripts.g.dart');

    await buildStep.writeAsString(
      outputId,
      formatter.format(libraryBuilder.build().accept(emitter).toString()),
    );
  }

  @override
  Map<String, List<String>> get buildExtensions => {
        r'$package$': ['godot_dart_scripts.g.dart'],
      };

  Future<List<TypePathPair>> _getTypePathPairs(
      BuildStep buildStep, String packageName, List<AssetId> assets) async {
    List<TypePathPair> typeMap = [];
    for (var asset in assets) {
      if (!await buildStep.resolver.isLibrary(asset)) continue;

      final library = await buildStep.resolver.libraryFor(asset);
      final libraryReader = LibraryReader(library);
      for (var annotatedElement
          in libraryReader.annotatedWith(_godotScriptChecker)) {
        var element = annotatedElement.element;
        if (element is! ClassElement || element is EnumElement) {
          throw InvalidGenerationSourceError(
            '`@GodotScript` can only be used on classes.',
            element: element,
          );
        }

        final relativeName =
            _removePackage(library.librarySource.fullName, packageName);

        log.log(Level.INFO, '$relativeName => ${element.name}');

        final isGlobalReader = annotatedElement.annotation.read('isGlobal');
        final isGlobal = isGlobalReader.isBool && isGlobalReader.boolValue;

        typeMap
            .add((type: element.name, path: relativeName, isGlobal: isGlobal));
      }
    }

    return typeMap;
  }

  Future<c.Spec> _generateScriptResolver(
      BuildStep buildStep,
      String packageName,
      List<AssetId> assets,
      c.LibraryBuilder libraryBuilder) async {
    final methodBody = StringBuffer();
    methodBody.writeln('final typeResolver = gde.typeResolver;');
    final typeMap = await _getTypePathPairs(buildStep, packageName, assets);
    for (final t in typeMap) {
      libraryBuilder.directives.add(c.Directive.import(t.path));

      methodBody.writeln(
          "typeResolver.addScriptType('${t.path}', ${t.type}, ${t.isGlobal});");
    }

    final method = c.Method((b) => b
      ..name = 'attachScriptResolver'
      ..returns = c.refer('void')
      ..body = c.Code(methodBody.toString()));

    return method;
  }

  String _removePackage(String fullName, String packageName) {
    return fullName.replaceFirst('/$packageName/', '');
  }
}
