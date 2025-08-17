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
    libraryBuilder.body.add(await _generateResolverClass(
        buildStep, packageName, assets, libraryBuilder));
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

  Future<c.Spec> _generateResolverClass(BuildStep buildStep, String packageName,
      List<AssetId> assets, c.LibraryBuilder libraryBuilder) async {
    final typeMap = await _getTypePathPairs(buildStep, packageName, assets);

    for (final t in typeMap) {
      libraryBuilder.directives.add(c.Directive.import(t.path));
    }

    final klass = c.Class((b) => b
      ..name = 'TypeResolverImpl'
      ..implements = ListBuilder([
        c.refer('TypeResolver', 'package:godot_dart/godot.dart'),
      ])
      ..methods.addAll([
        _generatePathFromType(typeMap),
        _generateTypeFromPath(typeMap),
        _generateGetGlobalClassPaths(typeMap),
      ]));

    return klass;
  }

  Future<c.Spec> _generateScriptResolver(
      BuildStep buildStep,
      String packageName,
      List<AssetId> assets,
      c.LibraryBuilder libraryBuilder) async {
    final methodBody = StringBuffer();
    methodBody.writeln('final TypeResolverImpl resolver = TypeResolverImpl();');
    methodBody.writeln('gde.dartBindings.attachTypeResolver(resolver);');

    final method = c.Method((b) => b
      ..name = 'attachScriptResolver'
      ..returns = c.refer('void')
      ..body = c.Code(methodBody.toString()));

    return method;
  }

  String _removePackage(String fullName, String packageName) {
    return fullName.replaceFirst('/$packageName/', '');
  }

  c.Method _generatePathFromType(List<TypePathPair> typeMap) {
    final pathFromTypeBody = StringBuffer();
    pathFromTypeBody.writeln('final Map<Type, String> typeFileMap = {');

    for (final t in typeMap) {
      pathFromTypeBody.writeln("${t.type}: '$godotPrefix/${t.path}',");
    }

    pathFromTypeBody.writeln('};');
    pathFromTypeBody.writeln('return typeFileMap[scriptType];');

    return c.Method((b) => b
      ..name = 'pathFromType'
      ..requiredParameters.add(c.Parameter((p) => p
        ..type = c.refer('Type')
        ..name = 'scriptType'))
      ..returns = c.refer('String?')
      ..annotations = ListBuilder([
        c.CodeExpression(c.Code('override')),
      ])
      ..body = c.Code(pathFromTypeBody.toString()));
  }

  c.Method _generateTypeFromPath(List<TypePathPair> typeMap) {
    final typeFromPathBody = StringBuffer();
    typeFromPathBody.writeln('final Map<String, Type> fileTypeMap = {');

    for (final t in typeMap) {
      typeFromPathBody.writeln("'$godotPrefix/${t.path}': ${t.type},");
    }

    typeFromPathBody.writeln('};');
    typeFromPathBody.writeln('return fileTypeMap[scriptPath];');

    return c.Method((b) => b
      ..name = 'typeFromPath'
      ..requiredParameters.add(c.Parameter((p) => p
        ..type = c.refer('String')
        ..name = 'scriptPath'))
      ..returns = c.refer('Type?')
      ..annotations = ListBuilder([
        c.CodeExpression(c.Code('override')),
      ])
      ..body = c.Code(typeFromPathBody.toString()));
  }

  c.Method _generateGetGlobalClassPaths(List<TypePathPair> typeMap) {
    final getGlobalClassesBody = StringBuffer();
    getGlobalClassesBody.writeln('return [');

    for (final t in typeMap.where((t) => t.isGlobal)) {
      getGlobalClassesBody.writeln("'$godotPrefix/${t.path}',");
    }

    getGlobalClassesBody.writeln('];');

    return c.Method((b) => b
      ..name = 'getGlobalClassPaths'
      ..returns = c.refer('List<String>')
      ..annotations = ListBuilder([
        c.CodeExpression(c.Code('override')),
      ])
      ..body = c.Code(getGlobalClassesBody.toString()));
  }
}
