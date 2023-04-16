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
      o.p('static TypeInfo? _typeInfo;');
      o.p('static final _bindings = _${classInfo.name}Bindings();');
      o.p('static Map<String, Pointer<GodotVirtualFunction>>? _vTable;');
      o.b('static Map<String, Pointer<GodotVirtualFunction>> get vTable {', () {
        o.b('if (_vTable == null) {', () {
          o.p('_initVTable();');
        }, '}');
        o.p('return _vTable!;');
      }, '}');
      o.nl();

      o.b('static TypeInfo get typeInfo {', () {
        o.b('_typeInfo ??= TypeInfo(', () {
          o.p("StringName.fromString('${classInfo.name}'),");
          o.p("parentClass: StringName.fromString('${classInfo.inherits}'),");
          o.p('bindingCallbacks: bindingCallbacks,');
        }, ');');
        o.p('return _typeInfo!;');
      }, '}');
      o.nl();

      o.p('@override');
      o.p('TypeInfo get staticTypeInfo => typeInfo;');
      o.nl();

      o.p('Map<String, Pointer<GodotVirtualFunction>> get _staticVTable => vTable;');

      _writeSingleton(o, classInfo);
      _writeConstructors(o, classInfo);
      _writeMethods(o, classInfo);
      _writeBindingCallbacks(o, classInfo);
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
      o.p('_singletonPtr = gde.globalGetSingleton(typeInfo.className);');
      o.p('_singletonObj = gde.dartBindings.gdObjectToDartObject(');
      o.p('    _singletonPtr!.cast(), bindingCallbacks) as ${classInfo.dartName};');
    }, '}');

    o.p('return _singletonObj!;');
  }, '}');
  o.nl();
}

void _writeConstructors(CodeSink o, GodotExtensionApiJsonClass classInfo) {
  // Constructors
  o.p('${classInfo.dartName}() : super.forType(typeInfo.className);');
  o.nl();

  o.p('${classInfo.dartName}.forType(StringName type) : super.forType(type);');
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

    o.b('${makeEngineMethodSignature(method)} {', () {
      if (method.isVirtual) {
        if (hasReturn) {
          final defaultValue = returnInfo.defaultValue;
          o.p('return $defaultValue;');
        }
        return;
      }

      final arguments = method.arguments?.map((e) => e.proxy).toList() ?? [];

      // TODO: Research if we can do ptrCalls
      o.p('var method = _bindings.method${methodName.toUpperCamelCase()};');
      o.b('if (method == null) {', () {
        o.p('_bindings.method${methodName.toUpperCamelCase()} = gde.classDbGetMethodBind(');
        o.p("    typeInfo.className, StringName.fromString('${method.name}'), ${method.hash});");
        o.p('method = _bindings.method${methodName.toUpperCamelCase()};');
      }, '}');
      o.nl();

      o.b('${hasReturn ? 'final ret = ' : ''}gde.callNativeMethodBind(method!, ${method.isStatic ? 'null' : 'this'}, [',
          () {
        for (final argument in arguments) {
          o.p('convertToVariant(${escapeName(argument.name).toLowerCamelCase()}),');
        }
      }, ']);');

      if (hasReturn) {
        var bindingCallbacks = 'null';
        if (returnInfo.typeCategory == TypeCategory.engineClass) {
          bindingCallbacks = '${returnInfo.rawDartType}.bindingCallbacks';
        }

        if (returnInfo.typeCategory == TypeCategory.enumType) {
          o.p('return ${returnInfo.rawDartType}.fromValue(convertFromVariant(ret, $bindingCallbacks) as int);');
        } else {
          o.p('return convertFromVariant(ret, $bindingCallbacks) as ${returnInfo.dartType};');
        }
      }
    }, '}');
    o.nl();
  }
}

void _writeBindingCallbacks(CodeSink o, GodotExtensionApiJsonClass classInfo) {
  o.nl();
  o.p('// Binding callbacks');
  o.p('static Pointer<GDExtensionInstanceBindingCallbacks>? _bindingCallbacks;');
  o.b('static Pointer<GDExtensionInstanceBindingCallbacks>? get bindingCallbacks {',
      () {
    o.b('if (_bindingCallbacks == null) {', () {
      o.p('_initBindings();');
    }, '}');
    o.p('return _bindingCallbacks!;');
  }, '}');
  o.nl();

  o.b('static Pointer<Void> _bindingCreateCallback(Pointer<Void> token, Pointer<Void> instance) {',
      () {
    o.p('final dartInstance = ${classInfo.dartName}.withNonNullOwner(instance);');
    o.p('return gde.dartBindings.toPersistentHandle(dartInstance);');
  }, '}');
  o.nl();

  o.b('static void _bindingFreeCallback(Pointer<Void> token, Pointer<Void> instance, Pointer<Void> binding) {',
      () {
    o.p('gde.dartBindings.clearPersistentHandle(binding);');
  }, '}');
  o.nl();

  o.b('static int _bindingReferenceCallback(Pointer<Void> token, Pointer<Void> instance, int reference) {',
      () {
    o.p('return 1;');
  }, '}');
  o.nl();

  o.b('static void _initBindings() {', () {
    o.p('_bindingCallbacks = malloc<GDExtensionInstanceBindingCallbacks>();');
    o.p('_bindingCallbacks!.ref');
    o.p('  ..create_callback = Pointer.fromFunction(_bindingCreateCallback)');
    o.p('  ..free_callback = Pointer.fromFunction(_bindingFreeCallback)');
    o.p('  ..reference_callback = Pointer.fromFunction(_bindingReferenceCallback, 1);');
    o.p('_initVTable();');
  }, '}');
  o.nl();
}

void _writeVirtualFunctions(CodeSink o, GodotExtensionApiJsonClass classInfo) {
  final virtualMethods = classInfo.methods?.where((e) => e.isVirtual) ?? [];

  o.p('// Virtual functions');
  o.b('static void _initVTable() {', () {
    o.p('_vTable = {};');

    if (classInfo.inherits != null) {
      final correctedInherits = getCorrectedType(classInfo.dartName);
      o.p('_vTable!.addAll($correctedInherits.vTable);\n');
    }

    for (final method in virtualMethods) {
      final methodName = escapeMethodName(method.name).toLowerCamelCase();
      o.p("_vTable!['${method.name}'] = Pointer.fromFunction(__$methodName);");
    }
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
      o.p('final self = gde.dartBindings.fromPersistentHandle(instance) as ${classInfo.dartName};');
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
