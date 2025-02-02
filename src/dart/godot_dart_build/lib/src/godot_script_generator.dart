import 'dart:mirrors';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:godot_dart/godot_dart.dart';
import 'package:source_gen/source_gen.dart';

const _godotScriptChecker = TypeChecker.fromRuntime(GodotScript);
const _godotExportChecker = TypeChecker.fromRuntime(GodotExport);
const _godotSignalChecker = TypeChecker.fromRuntime(GodotSignal);
const _godotPropertyChecker = TypeChecker.fromRuntime(GodotProperty);
const _godotRpcInfoChecker = TypeChecker.fromRuntime(GodotRpc);

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

    // Find the first superclass that has nativeTypeName defined
    ClassElement? nativeType;
    InterfaceElement? searchElement = element;
    while (searchElement != null) {
      if (searchElement is ClassElement) {
        final nativeTypeNameField = searchElement.getField('nativeTypeName');
        if (nativeTypeNameField != null && nativeTypeNameField.isStatic) {
          nativeType = searchElement;
          break;
        }
      }
      // Continue searching up the tree
      searchElement = searchElement.supertype?.element;
    }

    if (nativeType == null) {
      log.warning('Could not determine nativeTypeName of ${element.name}');
    }

    final isGlobalClassReader = annotation.read('isGlobal');

    buffer.writeln('TypeInfo _\$${element.name}TypeInfo() => TypeInfo(');
    buffer.writeln('  ${element.name},');
    buffer.writeln('  StringName.fromString(\'${element.name}\'),');
    buffer.writeln(
        '  StringName.fromString(${nativeType?.name}.nativeTypeName),');
    buffer.writeln(
        '  isGlobalClass: ${isGlobalClassReader.isNull ? 'false' : isGlobalClassReader.boolValue},');
    buffer.writeln('  parentType: ${element.supertype},');
    buffer.writeln('  vTable: ${element.supertype}.sTypeInfo.vTable,');
    buffer.writeln('  scriptInfo: ScriptInfo(');

    // Methods
    buffer.writeln('    methods: [');
    for (final method in element.methods) {
      final exportAnnotation = _godotExportChecker.firstAnnotationOf(method,
          throwOnUnresolved: false);
      if (method.hasOverride || exportAnnotation != null) {
        buffer.write(_buildMethodInfo(method, exportAnnotation));
        buffer.writeln(',');
      }
      // Automatically export all RPC methods as well
      final rpcAnnotation = _godotRpcInfoChecker.firstAnnotationOf(method,
          throwOnUnresolved: false);
      if (rpcAnnotation != null) {
        buffer.write(_buildMethodInfo(method, rpcAnnotation));
        buffer.write(',');
      }
    }
    buffer.writeln('    ],');

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
    for (final accessor in element.accessors) {
      if (accessor.isGetter &&
          _godotPropertyChecker.hasAnnotationOf(accessor,
              throwOnUnresolved: false)) {
        propertyFields.add(accessor);
      }
      // TODO: Warn on properties having annotations on setters.
    }

    buffer.writeln('    signals: [');
    for (final signalField in signalFields) {
      final signalAnnotation =
          _godotSignalChecker.firstAnnotationOf(signalField);
      buffer.write(_buildSignalInfo(signalField, signalAnnotation));
      buffer.writeln(',');
    }
    buffer.writeln('    ],');

    buffer.writeln('    properties: [');
    for (final propertyField in propertyFields) {
      final propertyAnnotation =
          _godotPropertyChecker.firstAnnotationOf(propertyField);
      buffer.write(_generatePropertyInfo(
          propertyField, propertyAnnotation, packageName));
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
    buffer.writeln('    ]');

    buffer.writeln('  ),');
    buffer.writeln(');');

    buffer.writeln();

    return buffer.toString();
  }

  String _buildMethodInfo(MethodElement element, DartObject? exportAnnotation) {
    final buffer = StringBuffer();
    buffer.writeln('MethodInfo(');

    if (exportAnnotation != null) {
      final reader = ConstantReader(exportAnnotation);
      final nameReader = reader.peek('name');
      String? exportName =
          (nameReader?.isNull ?? true) ? element.name : nameReader?.stringValue;
      buffer.writeln('  name: \'$exportName\',');
      buffer.writeln('  dartMethodName: \'${element.name}\',');
    } else if (element.hasOverride) {
      final godotMethodName = _convertVirtualMethodName(element.name);
      buffer.writeln('  name: \'$godotMethodName\',');
      buffer.writeln('  dartMethodName: \'${element.name}\',');
    }

    buffer.writeln('  args: [');

    for (final argument in element.parameters) {
      buffer.write(_generateArgumentPropertyInfo(argument));
      buffer.writeln(',');
    }

    buffer.writeln('  ],');
    buffer.write(')');

    return buffer.toString();
  }

  String _buildSignalInfo(FieldElement element, DartObject? signalAnnotation) {
    final buffer = StringBuffer();
    buffer.writeln('MethodInfo(');

    final reader = ConstantReader(signalAnnotation);
    final signalName = reader.read('signalName').stringValue;
    buffer.writeln('  name: \'$signalName\',');

    final signalArguments = reader.read('args').listValue;
    buffer.writeln('  args:  [');
    for (final arg in signalArguments) {
      final argReader = ConstantReader(arg);
      final argName = argReader.read('name').stringValue;
      final argType = argReader.read('type').typeValue;
      buffer.writeln(
          '    PropertyInfo(name: \'$argName\', typeInfo: ${_typeInfoForType(argType)}),');
    }
    buffer.writeln(']');
    buffer.write(')');

    return buffer.toString();
  }

  String _generateArgumentPropertyInfo(ParameterElement parameter) {
    final buffer = StringBuffer();

    buffer.writeln('PropertyInfo(');
    buffer.writeln('  name: \'${parameter.name}\',');
    buffer.writeln('  typeInfo: ${_typeInfoForType(parameter.type)},');
    buffer.write(')');

    return buffer.toString();
  }

  String _generatePropertyInfo(
      Element field, DartObject? propertyAnnotation, String packageName) {
    final buffer = StringBuffer();

    final reader = ConstantReader(propertyAnnotation);
    final nameReader = reader.read('name');
    String? exportName =
        nameReader.isNull ? field.name : nameReader.stringValue;

    final type = field is FieldElement
        ? field.type
        : (field as PropertyAccessorElement).returnType;

    buffer.writeln('PropertyInfo(');
    buffer.writeln('  name: \'$exportName\',');
    buffer.writeln('  typeInfo: ${_typeInfoForType(type)},');

    final propertyHint = _getPropertyHint(type);
    if (propertyHint != null) {
      buffer.writeln('  hint: ${propertyHint.toString()},');
      buffer.writeln(
          '  hintString: \'${_getPropertyHintString(type, packageName)}\',');
    }

    buffer.write(')');

    return buffer.toString();
  }

  PropertyHint? _getPropertyHint(DartType type) {
    final element = type.element;
    if (element is ClassElement) {
      for (final supertype in element.allSupertypes) {
        if (supertype.element.name == 'Node') {
          return PropertyHint.nodeType;
        } else if (supertype.element.name == 'Resource') {
          return PropertyHint.resourceType;
        }
      }
    }
    return null;
  }

  String _getPropertyHintString(DartType type, String packageName) {
    final element = type.element;
    if (element is ClassElement &&
        _godotScriptChecker.hasAnnotationOf(element,
            throwOnUnresolved: false)) {
      final relativeName = element.library.librarySource.fullName
          .replaceFirst('/$packageName/', '');
      return 'res://src/$relativeName';
    }

    // Else, return its type
    return type.getDisplayString(withNullability: false);
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

    if (isPrimitive(type)) {
      return 'TypeInfo.forType(${type.getDisplayString(withNullability: false)})!';
    } else if (type.getDisplayString(withNullability: false) == 'Variant') {
      return 'TypeInfo.forType(Variant)';
    } else if (type is VoidType) {
      return 'TypeInfo.forType(null)';
    } else {
      return '${type.getDisplayString(withNullability: false)}.sTypeInfo';
    }
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

    StringBuffer buffer = StringBuffer();

    final className = element.name;
    final rpcMethodsClass = '\$${className}RpcMethods';
    buffer.writeln('class $rpcMethodsClass {');
    buffer.writeln('  $className self;');
    buffer.writeln('  $rpcMethodsClass(this.self);');

    for (final method in rpcMethods) {
      var methodSignature = method.getDisplayString(withNullability: true);
      var withIdParam =
          '${methodSignature.substring(0, methodSignature.length - 1)}, {int? peerId})';
      buffer.write(withIdParam);
      buffer.writeln('{');
      buffer.writeln('  final args = [');
      for (final arg in method.parameters) {
        buffer.write('Variant(${arg.name}),');
      }
      buffer.writeln('];');
      buffer.writeln('  if (peerId != null) {');
      buffer.writeln("    self.rpcId(peerId, '${method.name}', vargs: args);");
      buffer.writeln('  } else {');
      buffer.writeln("    self.rpc('${method.name}', vargs: args);");
      buffer.writeln('  }');
      buffer.writeln('}');
    }
    buffer.writeln('}');

    buffer.writeln('extension ${className}RpcExtension on $className {');
    buffer.writeln('  $rpcMethodsClass get \$rpc => $rpcMethodsClass(this);');
    buffer.writeln('}');

    return buffer.toString();
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
