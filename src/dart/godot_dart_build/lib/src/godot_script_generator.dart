import 'dart:mirrors';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart' as c;
import 'package:collection/collection.dart';
import 'package:godot_dart/godot_dart.dart';
// ignore: implementation_imports
import 'package:godot_dart/src/core/signals.dart';
import 'package:source_gen/source_gen.dart';

const _godotScriptChecker = TypeChecker.typeNamed(GodotScript);
const _godotExportChecker = TypeChecker.typeNamed(GodotExport);
const _godotSignalChecker = TypeChecker.typeNamed(GodotSignal);
const _godotPropertyChecker = TypeChecker.typeNamed(GodotProperty);
const _godotRpcInfoChecker = TypeChecker.typeNamed(GodotRpc);
// ignore: invalid_use_of_internal_member
const _godotSignalCallableChecker = TypeChecker.typeNamed(SignalCallable);

/// Generates code for @GodotScript annotated classes
class GodotScriptAnnotationGenerator
    extends GeneratorForAnnotation<GodotScript> {
  @override
  Iterable<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) sync* {
    if (element is! ClassElement || element is EnumElement) {
      throw InvalidGenerationSourceError(
        '`@GodotScript` can only be used on classes.',
        element: element,
      );
    }

    final packageName = buildStep.inputId.package;

    log.info('Trying to write output for ${element.name}');
    yield _createTypeInfo(element, annotation, packageName);
    yield _createRpcExtension(element);
  }

  String _createTypeInfo(
      ClassElement element, ConstantReader annotation, String packageName) {
    final buffer = StringBuffer();

    // Find the first superclass that has nativeTypeName defined and see if we're RefCounted
    ClassElement? nativeType;
    InterfaceElement? searchElement = element;
    bool isRefCounted = false;
    while (searchElement != null) {
      if (searchElement is ClassElement) {
        if (nativeType == null) {
          final nativeTypeNameField = searchElement.getField('nativeTypeName');
          if (nativeTypeNameField != null && nativeTypeNameField.isStatic) {
            nativeType = searchElement;
          }
        }
        if (searchElement.name == 'RefCounted') {
          isRefCounted = true;
        }
      }

      // Continue searching up the tree
      searchElement = searchElement.supertype?.element;
    }

    if (nativeType == null) {
      log.warning('Could not determine nativeTypeName of ${element.name}');
    }

    final isGlobalClassReader = annotation.read('isGlobal');

    buffer.writeln(
        'ExtensionTypeInfo<${element.name}> _\$${element.name}TypeInfo() {');
    buffer.writeln('  final typeInfo = ExtensionTypeInfo<${element.name}>(');
    buffer
        .writeln('    className: StringName.fromString(\'${element.name}\'),');
    buffer.writeln('    parentTypeInfo: ${element.supertype}.sTypeInfo,');
    buffer.writeln(
        '    nativeTypeName: StringName.fromString(${nativeType?.name}.nativeTypeName),');
    buffer.writeln('    isRefCounted: $isRefCounted,');
    buffer.writeln('    constructObjectDefault: () => ${element.name}(),');
    buffer.writeln(
        '    constructFromGodotObject: (ptr) => ${element.name}.withNonNullOwner(ptr),');
    buffer.writeln('    isScript: true,');
    buffer.writeln(
        '    isGlobalClass: ${isGlobalClassReader.isNull ? 'false' : isGlobalClassReader.boolValue},');

    // TODO sepearate out signals and properties in case they self reference
    List<FieldElement> signalFields = [];
    List<Element> propertyFields = [];
    for (final field in element.fields) {
      if (_godotSignalChecker.hasAnnotationOf(field,
          throwOnUnresolved: false)) {
        signalFields.add(field);
      } else if (_godotPropertyChecker.hasAnnotationOf(field,
          throwOnUnresolved: false)) {
        propertyFields.add(field);
      }
    }
    for (final getter in element.getters) {
      if (_godotPropertyChecker.hasAnnotationOf(getter,
          throwOnUnresolved: false)) {
        propertyFields.add(getter);
      }
    }
    for (final setter in element.setters) {
      if (_godotPropertyChecker.hasAnnotationOf(setter,
          throwOnUnresolved: false)) {
        log.warning(
            'Found `@GodotProperty` on setter `${setter.name}`. `@GodotProperty` should not be used on setters, only getters.');
      }
    }
    buffer.writeln('    signals: [');
    for (final signalField in signalFields) {
      final signalAnnotation =
          _godotSignalChecker.firstAnnotationOf(signalField);
      if (_godotSignalCallableChecker.isAssignableFromType(signalField.type) &&
          signalField.hasInitializer) {
        final signalInfo = _buildSignalInfo(signalField, signalAnnotation);
        if (signalInfo != null) {
          buffer.write(signalInfo);
          buffer.writeln(',');
        }
      } else {
        log.severe(
            'Use of `@GodotSignal` on invalid field `${signalField.name}`. The type must be one of the SignalX classes and have a default initialier.');
      }
    }
    buffer.writeln('    ],');

    buffer.writeln('    properties: [');
    for (final propertyField in propertyFields) {
      final propertyAnnotation =
          _godotPropertyChecker.firstAnnotationOf(propertyField);
      buffer.write(_generatePropertyInfo(
          element.displayName, propertyField, propertyAnnotation, packageName));
      buffer.writeln(',');
    }
    buffer.writeln('    ],');

    buffer.writeln('    rpcInfo: [');
    for (final method in element.methods) {
      final rpcAnnotation = _godotRpcInfoChecker.firstAnnotationOf(method,
          throwOnUnresolved: false);
      if (rpcAnnotation != null) {
        buffer.write(_buildRpcMethodInfo(method, rpcAnnotation));
      }
    }
    buffer.writeln('    ],');
    buffer.writeln('  );');

    buffer.writeln('  typeInfo.methods = [');

    // Methods
    for (final method in element.methods) {
      final exportAnnotation = _godotExportChecker.firstAnnotationOf(method,
          throwOnUnresolved: false);
      // Automatically export all RPC methods as well
      final rpcAnnotation = _godotRpcInfoChecker.firstAnnotationOf(method,
          throwOnUnresolved: false);

      if ((exportAnnotation != null || rpcAnnotation != null) &&
          method.formalParameters.firstWhereOrNull((p) => p.isNamed) != null) {
        log.severe(
            'Method ${method.name} cannot be exported (or an RPC method) because it has named parameters, which is not supported by Godot.');
        continue;
      }
      if (method.metadata.hasOverride || exportAnnotation != null) {
        buffer.write(_buildMethodInfo(method, exportAnnotation));
        buffer.writeln(',');
      }
      if (rpcAnnotation != null) {
        buffer.write(_buildMethodInfo(method, rpcAnnotation));
        buffer.write(',');
      }
    }
    buffer.writeln('  ];');
    buffer.writeln('  return typeInfo;');
    buffer.writeln('}');

    buffer.writeln();

    return buffer.toString();
  }

  String _buildMethodInfo(MethodElement element, DartObject? exportAnnotation) {
    final buffer = StringBuffer();
    buffer.writeln('MethodInfo(');

    final call = StringBuffer();
    call.write('dartMethodCall: (o, a) => o.${element.name}(');
    call.write(element.formalParameters.indexed
        .map((e) => 'a[${e.$1}] as ${e.$2.type}')
        .join(','));
    call.write(')');

    if (exportAnnotation != null) {
      final reader = ConstantReader(exportAnnotation);
      final nameReader = reader.peek('name');
      String? exportName =
          (nameReader?.isNull ?? true) ? element.name : nameReader?.stringValue;
      buffer.writeln('  name: \'$exportName\',');
    } else if (element.metadata.hasOverride) {
      final godotMethodName = _convertVirtualMethodName(element.displayName);
      buffer.writeln('  name: \'$godotMethodName\',');
    }

    buffer.writeln('  $call,');
    buffer.writeln('  args: [');

    for (final argument in element.formalParameters) {
      buffer.write(_generateArgumentPropertyInfo(argument));
      buffer.writeln(',');
    }

    buffer.writeln('  ],');
    buffer.write(')');

    return buffer.toString();
  }

  AstNode? getAstNodeFromElement(Element element) {
    final session = element.session;
    final parsedLibResult = session?.getParsedLibraryByElement(element.library!)
        as ParsedLibraryResult?;
    final fragmentDelcaration =
        parsedLibResult?.getFragmentDeclaration(element.firstFragment);
    return fragmentDelcaration?.node;
  }

  String? _buildSignalInfo(
      VariableElement element, DartObject? signalAnnotation) {
    final buffer = StringBuffer();
    buffer.writeln('SignalInfo(');

    // Find the name of the signal through the AST
    final node = getAstNodeFromElement(element);
    if (node == null) {
      log.severe('Could not find AST Node for ${element.name}?');
      return null;
    }
    final constructorNode =
        node.childEntities.whereType<MethodInvocation>().firstOrNull;
    if (constructorNode == null) {
      log.severe(
          'Could not find constructor for ${element.name}! Is it initialized properly?');
      return null;
    }
    final signalNameArg = constructorNode.argumentList.arguments[1];
    if (signalNameArg is! StringLiteral) {
      log.severe('Signal name for ${element.name} must be a StringLiteral!');
      return null;
    }

    final signalName = signalNameArg.stringValue!;
    buffer.writeln('  name: \'$signalName\',');

    //final signalArguments = reader.read('args').listValue;
    final interfaceType = element.type as InterfaceType;
    buffer.writeln('  args:  [');
    for (final param in interfaceType.typeArguments.indexed) {
      buffer.writeln(
          '    PropertyInfo(name: \'p${param.$1}\', typeInfo: ${_typeInfoForType(param.$2)}),');
    }
    buffer.writeln(']');
    buffer.write(')');

    return buffer.toString();
  }

  String _generateArgumentPropertyInfo(FormalParameterElement parameter) {
    final buffer = StringBuffer();

    buffer.writeln('PropertyInfo(');
    buffer.writeln('  name: \'${parameter.name}\',');
    buffer.writeln('  typeInfo: ${_typeInfoForType(parameter.type)},');
    buffer.write(')');

    return buffer.toString();
  }

  String _generatePropertyInfo(String parentType, Element field,
      DartObject? propertyAnnotation, String packageName) {
    final buffer = StringBuffer();

    final reader = ConstantReader(propertyAnnotation);
    final nameReader = reader.read('name');
    String? exportName =
        nameReader.isNull ? field.name : nameReader.stringValue;

    final type = field is FieldElement
        ? field.type
        : (field as PropertyAccessorElement).returnType;

    // Handle lists super spec
    bool isList = type.isDartCoreList;
    DartType? listType;
    if (isList && type is ParameterizedType) {
      listType = type.typeArguments.first;
    }

    buffer.writeln(
        'DartPropertyInfo<$parentType, ${isList ? 'GDArray' : type}>(');
    buffer.writeln('  name: \'$exportName\',');
    buffer.writeln('  typeInfo: ${_typeInfoForType(type)},');

    final propertyHint = _getPropertyHint(type, packageName);
    if (propertyHint != null) {
      buffer.writeln('  hint: ${propertyHint.hint.toString()},');
      buffer.writeln('  hintString: \'${propertyHint.hintString}\',');
    }
    var getterBody = 'self.${field.name}';
    var setterBody = 'self.${field.name} = value';
    if (isList && listType != null) {
      if (listType.nullabilitySuffix != NullabilitySuffix.question) {
        log.warning(
            '$parentType.$exportName has a non-nullable element type. It is highly recommended'
            ' that you make List elements nullable in order to make editing them possible.');
      }
      getterBody = 'GDArrayExtensions.fromList(self.${field.name})';
      setterBody = 'self.${field.name} = value.toDartList()';
    }
    buffer.writeln('  getter: (self) => $getterBody,');
    buffer.writeln('  setter: (self, value) => $setterBody,');

    buffer.write(')');

    return buffer.toString();
  }

  ({PropertyHint hint, String hintString})? _getPropertyHint(
      DartType type, String packageName) {
    final element = type.element;

    String getScriptResourceForType(DartType type) {
      final element = type.element;
      if (element is ClassElement &&
          _godotScriptChecker.hasAnnotationOf(element,
              throwOnUnresolved: false)) {
        final relativeName = element.library.firstFragment.source.fullName
            .replaceFirst('/$packageName/', '');
        return 'res://src/$relativeName';
      }

      // Else, return its type
      return type.element!.name!;
    }

    if (element case ClassElement ce) {
      if (ce.isSubClassOf('Node')) {
        return (
          hint: PropertyHint.nodeType,
          hintString: getScriptResourceForType(type)
        );
      } else if (ce.isSubClassOf('Resource')) {
        return (
          hint: PropertyHint.resourceType,
          hintString: getScriptResourceForType(type)
        );
      }
    }

    if (type.isDartCoreList) {
      final arrayElementType = (type as ParameterizedType).typeArguments.first;
      final arrayElementVariantType = _variantTypeForType(arrayElementType);

      if (arrayElementVariantType != null) {
        final elementHint = _getPropertyHint(arrayElementType, packageName);
        if (elementHint != null) {
          final hintString =
              '${arrayElementVariantType.value}/${elementHint.hint.value}:${elementHint.hintString}';

          return (hint: PropertyHint.typeString, hintString: hintString);
        } else {
          final hintString =
              '${arrayElementVariantType.value}/${PropertyHint.none.value}:';
          return (hint: PropertyHint.typeString, hintString: hintString);
        }
      }
    }

    return null;
  }

  String _buildRpcMethodInfo(MethodElement method, DartObject rpcAnnotation) {
    final buffer = StringBuffer();
    buffer.writeln('RpcInfo(');
    buffer.writeln('  name: \'${method.name}\',');

    final reader = ConstantReader(rpcAnnotation);
    final modeReader = reader.read('mode');
    buffer.writeln(
        '  mode: ${modeReader.enumValue<MultiplayerAPIRPCMode>().toString()},');
    buffer.writeln('  callLocal: ${reader.read('callLocal').boolValue},');
    buffer.writeln(
        '  transferMode: ${reader.read('transferMode').enumValue<MultiplayerPeerTransferMode>()},');
    buffer.writeln(
        '  transferChannel: ${reader.read('transferChannel').intValue},');
    buffer.writeln('),');

    return buffer.toString();
  }

  String _typeInfoForType(DartType type) {
    bool isPrimitive(DartType type) {
      return type.isDartCoreBool ||
          type.isDartCoreDouble ||
          type.isDartCoreInt ||
          type.isDartCoreString;
    }

    final typeName = type.element?.name;

    if (isPrimitive(type)) {
      return 'PrimitiveTypeInfo.forType($typeName)!';
    } else if (type.isDartCoreList) {
      return 'GDArray.sTypeInfo';
    } else if (typeName == 'Variant') {
      return 'Variant.sTypeInfo';
    } else if (type is VoidType) {
      return 'PrimitiveTypeInfo.forType(null)';
    } else {
      return '$typeName.sTypeInfo';
    }
  }

  VariantType? _variantTypeForType(DartType type) {
    if (type.isDartCoreInt) {
      return VariantType.integer;
    } else if (type.isDartCoreDouble) {
      return VariantType.float;
    } else if (type.isDartCoreBool) {
      return VariantType.bool;
    } else if (type.isDartCoreString) {
      return VariantType.string;
    } else if (type.isDartCoreEnum) {
      return VariantType.integer;
    } else if (type.element case ClassElement ce) {
      if (ce.isSubClassOf('GodotObject')) {
        return VariantType.object;
      }
    }

    const variantTypeMap = <String, VariantType>{
      'Vector2': VariantType.vector2,
      'Vector2i': VariantType.vector2i,
      'Rect2': VariantType.rect2,
      'Rect2i': VariantType.rect2i,
      'Vector3': VariantType.vector3,
      'Vector3i': VariantType.vector3i,
      'Transform2D': VariantType.transform2d,
      'Vector4': VariantType.vector4,
      'Vector4i': VariantType.vector4i,
      'Plane': VariantType.plane,
      'Quaternion': VariantType.quaternion,
      'AABB': VariantType.aabb,
      'Basis': VariantType.basis,
      'Transform3D': VariantType.transform3d,
      'Projection': VariantType.projection,
      'Color': VariantType.color,
      'StringName': VariantType.stringName,
      'GDStringName': VariantType.string,
      'NodePath': VariantType.nodePath,
      'RID': VariantType.rid,
      'PackedByteArray': VariantType.packedByteArray,
      'PackedInt32Array': VariantType.packedInt32Array,
      'PackedInt64Array': VariantType.packedFloat64Array,
      'PackedFloatArray': VariantType.packedFloat64Array,
      'PackedStringArray': VariantType.packedStringArray,
      'PackedVector2Array': VariantType.packedVector2Array,
      'PackedVector3Array': VariantType.packedVector3Array,
      'PackedVector4Array': VariantType.packedVector4Array,
      'PackedColor4Array': VariantType.packedColorArray,
      // Not supported via conversion
      // Object
      // Callable
      // Signal
      // Dictionary
      // Array
    };

    return variantTypeMap[type.element?.name];
  }

  String _convertVirtualMethodName(String methodName) {
    var name = methodName;
    if (methodName.startsWith(RegExp('v[A-Z]'))) {
      name =
          '_${name.substring(1, 2).toLowerCase()}${name.substring(2).toSnakeCase()}';
    }
    return name;
  }

  String _createRpcExtension(ClassElement element) {
    final rpcMethods = element.methods.where((m) =>
        _godotRpcInfoChecker.firstAnnotationOf(m, throwOnUnresolved: false) !=
        null);
    if (rpcMethods.isEmpty) return '';

    final className = element.name;
    final rpcMethodsClassName = '\$${className}RpcMethods';
    final rpcMethodClass = c.Class((b) => b
      ..name = rpcMethodsClassName
      ..fields.addAll([
        c.Field((f) => f
          ..type = c.Reference(className)
          ..name = 'self'),
      ])
      ..constructors.add(c.Constructor((e) => e
        ..requiredParameters.add(c.Parameter((p) => p
          ..toThis = true
          ..name = 'self'))))
      ..methods.addAll(rpcMethods.map(_generateRpcMethod)));

    final c.DartEmitter emitter = c.DartEmitter(useNullSafetySyntax: true);
    StringBuffer buffer = StringBuffer();
    buffer.write(rpcMethodClass.accept(emitter).toString());

    final rpcExtension = c.Extension((b) => b
      ..name = '${className}RpcExtension'
      ..on = c.Reference(className)
      ..methods.add(c.Method((m) => m
        ..returns = c.Reference(rpcMethodsClassName)
        ..type = c.MethodType.getter
        ..name = '\$rpc'
        ..body = c.Code('return $rpcMethodsClassName(this);'))));

    buffer.write(rpcExtension.accept(emitter).toString());
    return buffer.toString();
  }

  c.Method _generateRpcMethod(MethodElement method) {
    StringBuffer methodBody = StringBuffer();
    methodBody.writeln('  final args = <Variant>[');
    for (final arg in method.formalParameters) {
      methodBody.write('Variant(${arg.name}),');
    }
    methodBody.writeln('];');
    methodBody.writeln('  if (peerId != null) {');
    methodBody
        .writeln("    self.rpcId(peerId, '${method.name}', vargs: args);");
    methodBody.writeln('  } else {');
    methodBody.writeln("    self.rpc('${method.name}', vargs: args);");
    methodBody.writeln('  }');

    final optionalParameters = method.formalParameters
        .where((e) => e.isOptional)
        .map((e) => c.Parameter((p) => p
          ..named = e.isNamed
          ..name = e.displayName
          ..type = c.Reference(e.type.getDisplayString())))
        .toList()
      ..add(c.Parameter((b) => b
        ..name = 'peerId'
        ..named = true
        ..type = c.Reference('int?')));
    final requiredParametrs = method.formalParameters
        .where((e) => !e.isOptional)
        .map((e) => c.Parameter((p) => p
          ..named = e.isNamed
          ..name = e.displayName
          ..type = c.Reference(e.type.getDisplayString())));

    return c.Method.returnsVoid((b) => b
      ..optionalParameters.addAll(optionalParameters)
      ..requiredParameters.addAll(requiredParametrs)
      ..name = method.name
      ..body = c.Code(methodBody.toString()));
  }
}

extension StringHelper on String {
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
}

extension EnumHelper on ConstantReader {
  T enumValue<T>() {
    final classMirror = reflectClass(T);
    final values = classMirror.getField(Symbol('values')).reflectee as List<T>;
    final index = peek('index')?.intValue;

    return values[index!];
  }
}

extension InheritanceHelper on ClassElement {
  bool isSubClassOf(String superclass) {
    for (final supertype in allSupertypes) {
      if (supertype.element.name == superclass) {
        return true;
      }
    }
    return false;
  }
}
