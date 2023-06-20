import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:godot_dart/godot_dart.dart';
import 'package:source_gen/source_gen.dart';

const _godotExportChecker = TypeChecker.fromRuntime(GodotExport);
const _godotSignalChecker = TypeChecker.fromRuntime(GodotSignal);
const _godotPropertyChecker = TypeChecker.fromRuntime(GodotProperty);

class GodotDartGenerator extends GeneratorForAnnotation<GodotScript> {
  @override
  Iterable<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) sync* {
    if (element is! ClassElement || element is EnumElement) {
      throw InvalidGenerationSourceError(
        '`@GodotScript` can only be used on classes.',
        element: element,
      );
    }

    log.info('Trying to write output for ${element.name}');
    yield _createTypeInfo(element);
  }

  String _createTypeInfo(ClassElement element) {
    final buffer = StringBuffer();

    buffer.writeln('TypeInfo _\$${element.name}TypeInfo() => TypeInfo(');
    buffer.writeln('  ${element.name},');
    buffer.writeln('  StringName.fromString(\'${element.name}\'),');
    buffer.writeln('  parentClass: ${element.supertype}.sTypeInfo.className,');
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
    }
    buffer.writeln('    ],');

    List<FieldElement> signalFields = [];
    List<FieldElement> propertyFields = [];
    for (final field in element.fields) {
      if (_godotSignalChecker.hasAnnotationOf(field,
          throwOnUnresolved: false)) {
        signalFields.add(field);
      } else if (_godotPropertyChecker.hasAnnotationOf(field,
          throwOnUnresolved: false)) {
        propertyFields.add(field);
      }
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
      buffer.write(_generatePropertyInfo(propertyField, propertyAnnotation));
      buffer.writeln(',');
    }
    buffer.writeln('    ],');

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
      final nameReader = reader.read('name');
      String? exportName =
          nameReader.isNull ? element.name : nameReader.stringValue;
      buffer.writeln('  name: \'$exportName\',');
      buffer.writeln('  dartMethodName: \'${element.name}\',');
    } else if (element.hasOverride) {
      // TODO - I might change the naming scheme here
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

    // TODO: Signals that take parameters....
    buffer.writeln('  args:  [],');
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
      FieldElement field, DartObject? propertyAnnotation) {
    final buffer = StringBuffer();

    final reader = ConstantReader(propertyAnnotation);
    final nameReader = reader.read('name');
    String? exportName =
        nameReader.isNull ? field.name : nameReader.stringValue;

    buffer.writeln('PropertyInfo(');
    buffer.writeln('  name: \'$exportName\',');
    buffer.writeln('  typeInfo: ${_typeInfoForType(field.type)},');
    buffer.write(')');

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
      name = '_${name.substring(1, 2).toLowerCase()}${name.substring(2)}';
    }
    return name;
  }
}
