import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:built_collection/built_collection.dart';
import 'package:code_builder/code_builder.dart' as c;
import 'package:dart_style/dart_style.dart';
import 'package:glob/glob.dart';
import 'package:godot_dart/godot_dart.dart';
import 'package:logging/logging.dart';
import 'package:pubspec_parse/pubspec_parse.dart';
import 'package:source_gen/source_gen.dart';

const _godotScriptChecker = TypeChecker.fromRuntime(GodotScript);

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

    final libraryBuilder = c.LibraryBuilder();
    libraryBuilder.comments.add('GENERATED FILE - DO NOT MODIFY');
    libraryBuilder.directives
        .add(c.Directive.import('package:godot_dart/godot_dart.dart'));

    await _generateResolverClass(
        buildStep, packageName, assets, libraryBuilder);
    await _generateScriptResolver(
        buildStep, packageName, assets, libraryBuilder);

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

  Future<void> _generateResolverClass(BuildStep buildStep, String packageName,
      List<AssetId> assets, c.LibraryBuilder libraryBuilder) async {
    final classBuilder = c.ClassBuilder()
      ..name = 'TypeResolverImpl'
      ..implements = ListBuilder([
        c.refer('TypeResolver', 'package:godot_dart/godot.dart'),
      ]);

    final pathFromType = c.MethodBuilder()
      ..name = 'pathFromType'
      ..requiredParameters.add(c.Parameter((p) => p
        ..type = c.refer('Type')
        ..name = 'scriptType'))
      ..returns = c.refer('String?')
      ..annotations = ListBuilder([
        c.CodeExpression(c.Code('override')),
      ]);
    final pathFromTypeBody = StringBuffer();
    pathFromTypeBody.writeln('final Map<Type, String> typeFileMap = {');

    final typeFromPath = c.MethodBuilder()
      ..name = 'typeFromPath'
      ..requiredParameters.add(c.Parameter((p) => p
        ..type = c.refer('String')
        ..name = 'scriptPath'))
      ..returns = c.refer('Type?')
      ..annotations = ListBuilder([
        c.CodeExpression(c.Code('override')),
      ]);
    final typeFromPathBody = StringBuffer();
    typeFromPathBody.writeln('final Map<String, Type> fileTypeMap = {');

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
        libraryBuilder.directives.add(c.Directive.import(relativeName));

        // TODO: Need to make this a builder option
        final godotPrefix = 'res://src';

        log.log(Level.INFO, '$relativeName => ${element.name}');

        typeFromPathBody
            .writeln("'$godotPrefix/$relativeName': ${element.name},");
        pathFromTypeBody
            .writeln("${element.name}: '$godotPrefix/$relativeName',");
      }
    }
    pathFromTypeBody.writeln('};');
    pathFromTypeBody.writeln('return typeFileMap[scriptType];');
    pathFromType.body = c.Code(pathFromTypeBody.toString());

    typeFromPathBody.writeln('};');
    typeFromPathBody.writeln('return fileTypeMap[scriptPath];');
    typeFromPath.body = c.Code(typeFromPathBody.toString());

    classBuilder.methods.addAll([
      pathFromType.build(),
      typeFromPath.build(),
    ]);

    libraryBuilder.body.add(
      classBuilder.build(),
    );
  }

  Future<void> _generateScriptResolver(BuildStep buildStep, String packageName,
      List<AssetId> assets, c.LibraryBuilder libraryBuilder) async {
    final methodBuilder = c.MethodBuilder()
      ..name = 'attachScriptResolver'
      ..returns = c.refer('void');
    final methodBody = StringBuffer();
    methodBody.writeln('final TypeResolverImpl resolver = TypeResolverImpl();');
    methodBody.writeln('gde.dartBindings.attachTypeResolver(resolver);');

    methodBuilder.body = c.Code(methodBody.toString());
    libraryBuilder.body.add(methodBuilder.build());
  }

  String _removePackage(String fullName, String packageName) {
    return fullName.replaceFirst('/$packageName/', '');
  }
}
