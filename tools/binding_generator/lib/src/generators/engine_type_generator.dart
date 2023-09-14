import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as path;

import '../code_sink.dart';
import '../common_helpers.dart';
import '../godot_api_info.dart';
import '../godot_extension_api_json.dart';
import '../string_extensions.dart';
import '../type_helpers.dart';

Future<void> generateEngineBindings(
  GodotApiInfo api,
  String targetDir,
  String buildConfig,
) async {
  targetDir = path.join(targetDir, 'classes');
  var directory = Directory(targetDir);
  if (!directory.existsSync()) {
    await directory.create(recursive: true);
  }

  // Holds all the exports an initializations for the builtins, written as
  // 'classes.dart' at the end of generation
  var exportsString = '';

  for (final classInfo in api.engineClasses.values) {
    if (hasDartType(classInfo.name)) {
      continue;
    }

    final destPath =
        path.join(targetDir, '${classInfo.name.toSnakeCase()}.dart');
    final o = CodeSink(File(destPath));

    o.write(header);

    writeImports(o, api, classInfo, false);
    o.nl();

    final inherits = classInfo.inherits ?? 'ExtensionType';
    final correctedInherits = getCorrectedType(inherits);

    o.b('class ${classInfo.dartName} extends $correctedInherits {', () {
      o.b('static TypeInfo sTypeInfo = TypeInfo(', () {
        o.p('${classInfo.dartName},');
        o.p("StringName.fromString('${classInfo.name}'),");
        o.p("parentClass: StringName.fromString('${classInfo.inherits}'),");
        o.p('vTable: _getVTable(),');
      }, ');');
      o.p('static final _bindings = _${classInfo.name}Bindings();');
      // o.p('static Map<String, Pointer<GodotVirtualFunction>>? _vTable;');
      // o.b('static Map<String, Pointer<GodotVirtualFunction>> get vTable {', () {
      //   o.b('if (_vTable == null) {', () {
      //     o.p('_initVTable();');
      //   }, '}');
      //   o.p('return _vTable!;');
      // }, '}');
      o.nl();

      o.p('@override');
      o.p('TypeInfo get typeInfo => sTypeInfo;');
      o.p('@override');
      o.p('StringName get nativeTypeName => sTypeInfo.className;');
      o.nl();

      //o.p('Map<String, Pointer<GodotVirtualFunction>> get _staticVTable => vTable;');

      _writeSingleton(o, classInfo);
      _writeConstructors(o, classInfo);
      _writeMethods(o, classInfo);
      //_writeMethodTable(o, classInfo);
      _writeVirtualFunctions(o, classInfo);
    }, '}');
    o.nl();

    // Class Enums
    final enums = classInfo.enums ?? [];
    for (final classEnum in enums) {
      writeEnum(classEnum, classInfo.name, o);
    }
    o.nl();

    _writeBindingsClass(o, classInfo);

    await o.close();

    exportsString += "export '${classInfo.name.toSnakeCase()}.dart';\n";
  }

  var exportsFile = File(path.join(targetDir, 'engine_classes.dart'));
  var out = exportsFile.openWrite();
  out.write(header);
  out.write(exportsString);

  await out.close();
}

void _writeSingleton(CodeSink o, GodotExtensionApiJsonClass classInfo) {
  if (!GodotApiInfo.instance().singletons.contains(classInfo.name)) return;

  // Singleton
  o.p('static GDExtensionObjectPtr? _singletonPtr;');
  o.p('static ${classInfo.dartName}? _singletonObj;');
  o.b('static ${classInfo.dartName} get singleton {', () {
    o.b('if (_singletonPtr == null) {', () {
      o.p('_singletonPtr = gde.globalGetSingleton(sTypeInfo.className);');
      o.p('_singletonObj = gde.dartBindings.gdObjectToDartObject(');
      o.p('    _singletonPtr!.cast(), sTypeInfo.bindingToken) as ${classInfo.dartName};');
    }, '}');

    o.p('return _singletonObj!;');
  }, '}');
  o.nl();
}

void _writeConstructors(CodeSink o, GodotExtensionApiJsonClass classInfo) {
  // Constructors
  o.p('${classInfo.dartName}() : super();');
  o.nl();
  o.p('${classInfo.dartName}.withNonNullOwner(Pointer<Void> owner) : super.withNonNullOwner(owner);');
  o.b('static ${classInfo.dartName}? fromOwner(Pointer<Void> owner) {', () {
    o.p('if (owner == nullptr) return null;');
    o.p('return ${classInfo.dartName}.withNonNullOwner(owner);');
  }, '}');
  o.nl();
}

void _writeMethods(CodeSink o, GodotExtensionApiJsonClass classInfo) {
  final methods = classInfo.methods ?? [];

  for (final method in methods) {
    // TODO: Don't generate toString yet
    if (method.name == 'to_string') continue;

    final methodName = escapeMethodName(method.name);
    final returnInfo = method.returnValue?.proxy;
    final hasReturn =
        returnInfo != null && returnInfo.typeCategory != TypeCategory.voidType;

    o.b('${makeSignature(method)} {', () {
      if (method.isVirtual) {
        if (hasReturn) {
          final defaultValue = returnInfo.defaultReturnValue;
          o.p('return $defaultValue;');
        }
        return;
      }

      final arguments = method.arguments?.map((e) => e.proxy).toList() ?? [];

      // TODO: Research if we can do ptrCalls
      o.p('var methodBind = _bindings.method${methodName.toUpperCamelCase()};');
      o.b('if (methodBind == null) {', () {
        o.p('_bindings.method${methodName.toUpperCamelCase()} = gde.classDbGetMethodBind(');
        o.p("    sTypeInfo.className, StringName.fromString('${method.name}'), ${method.hash});");
        o.p('methodBind = _bindings.method${methodName.toUpperCamelCase()};');
      }, '}');
      o.nl();

      assignMethodDefaults(method.arguments ?? [], o);

      o.b('${hasReturn ? 'final ret = ' : ''}gde.callNativeMethodBind(methodBind!, ${method.isStatic ? 'null' : 'this'}, [',
          () {
        for (final argument in arguments) {
          if (argument.typeCategory == TypeCategory.enumType) {
            o.p('convertToVariant(${escapeName(argument.name).toLowerCamelCase()}.value),');
          } else if (argument.dartType == 'Variant') {
            o.p('${escapeName(argument.name).toLowerCamelCase()},');
          } else {
            o.p('convertToVariant(${escapeName(argument.name).toLowerCamelCase()}),');
          }
        }
      }, ']);');

      if (hasReturn) {
        var typeInfo = 'null';
        if (returnInfo.typeCategory == TypeCategory.engineClass) {
          typeInfo = '${returnInfo.rawDartType}.sTypeInfo';
        }

        if (returnInfo.typeCategory == TypeCategory.enumType) {
          o.p('return ${returnInfo.rawDartType}.fromValue(convertFromVariant(ret, null) as int);');
        } else if (returnInfo.dartType == 'Variant') {
          o.p('return ret;');
        } else {
          o.p('return convertFromVariant(ret, $typeInfo) as ${returnInfo.dartType};');
        }
      }
    }, '}');
    o.nl();
  }
}

void _writeVirtualFunctions(CodeSink o, GodotExtensionApiJsonClass classInfo) {
  final virtualMethods = classInfo.methods?.where((e) => e.isVirtual) ?? [];

  o.p('// Virtual functions');
  o.b('static Map<String, Pointer<GodotVirtualFunction>> _getVTable() {', () {
    o.p('Map<String, Pointer<GodotVirtualFunction>> vTable = {};');

    if (classInfo.inherits != null) {
      final correctedInherits = getCorrectedType(classInfo.inherits!);
      o.p('vTable.addAll($correctedInherits.sTypeInfo.vTable);\n');
    }

    for (final method in virtualMethods) {
      final methodName = escapeMethodName(method.name).toLowerCamelCase();
      o.p("vTable['${method.name}'] = Pointer.fromFunction(__$methodName);");
    }
    o.p('return vTable;');
  }, '}');
  o.nl();

  for (final method in virtualMethods) {
    final methodName = escapeMethodName(method.name).toLowerCamelCase();
    final dartMethodName = getDartMethodName(method.name, true);
    final arguments = method.arguments?.map((e) => e.proxy) ?? [];
    final returnInfo = method.returnValue?.proxy;
    final hasReturn =
        returnInfo != null && returnInfo.typeCategory != TypeCategory.voidType;

    o.b('static void __$methodName(GDExtensionClassInstancePtr instance, Pointer<GDExtensionConstTypePtr> args, GDExtensionTypePtr retPtr) {',
        () {
      o.p('final self = gde.dartBindings.objectFromInstanceBinding(instance) as ${classInfo.dartName};');
      arguments.forEachIndexed((i, e) {
        convertPtrArgument(i, e, o);
      });
      o.p("${hasReturn ? 'final ret = ' : ''}self.$dartMethodName(${arguments.map((e) => escapeName(e.name).toLowerCamelCase()).join(',')});");
      if (hasReturn) {
        writePtrReturn(returnInfo, o);
      }
    }, '}');
    o.nl();
  }
}

void _writeBindingsClass(CodeSink o, GodotExtensionApiJsonClass classInfo) {
  o.b('class _${classInfo.name}Bindings {', () {
    final methods = classInfo.methods ?? [];
    for (final method in methods) {
      if (method.isVirtual) {
        continue;
      }

      final methodName = escapeMethodName(method.name).toUpperCamelCase();
      o.p('GDExtensionMethodBindPtr? method$methodName;');
    }
  }, '}');
}
