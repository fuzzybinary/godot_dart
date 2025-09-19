import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as path;

import '../code_sink.dart';
import '../common_helpers.dart';
import '../godot_api_info.dart';
import '../godot_extension_api_json.dart';
import '../string_extensions.dart';
import '../type_helpers.dart';

final coreClassesImports = '''
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../../core/core.dart';
export '../../extensions/core_extensions.dart';
import '../../variant/variant.dart';
import '../global_constants.dart';

import '../variant/string_name.dart';
import '../variant/string.dart';
''';

Future<void> generateEngineBindings(
  GodotApiInfo api,
  String rootDirectory,
  String targetDir,
  String buildConfig,
) async {
  final classesTarget = path.join(targetDir, 'classes');
  var directory = Directory(classesTarget);
  if (!directory.existsSync()) {
    await directory.create(recursive: true);
  }

  // Holds all the classes that we generate that will be a global
  // 'engine_classes.dart' library at the end of generation
  var libraryParts = '';

  for (final classInfo in api.engineClasses.values) {
    if (hasDartType(classInfo.name)) {
      continue;
    }

    final destPath =
        path.join(classesTarget, '${classInfo.name.toSnakeCase()}.dart');
    final o = CodeSink(File(destPath));

    o.write(header);
    o.write(_generateImportsFor(api, classInfo, rootDirectory, classesTarget));
    o.nl();

    final inheritsType = api.engineClasses[classInfo.inherits];
    final inheritsClass = inheritsType?.dartName ?? 'ExtensionType';
    final inheritsTypeInfo =
        inheritsType == null ? 'null' : '$inheritsClass.sTypeInfo';

    o.p("@pragma('vm:entry-point')");
    o.b('class ${classInfo.dartName} extends $inheritsClass {', () {
      o.p('static ExtensionTypeInfo<${classInfo.dartName}>? _sTypeInfo;');
      o.b('static ExtensionTypeInfo<${classInfo.dartName}> get sTypeInfo {',
          () {
        o.b('if(_sTypeInfo == null) {', () {
          o.b('_sTypeInfo = ExtensionTypeInfo<${classInfo.dartName}>(', () {
            o.p("className: StringName.fromString('${classInfo.name}'),");
            o.p('parentTypeInfo: $inheritsTypeInfo,');
            o.p('nativeTypeName: StringName.fromString(nativeTypeName),');
            o.p('isRefCounted: ${classInfo.isRefcounted},');
            o.p('constructObjectDefault: () => ${classInfo.dartName}(),');
            o.p('constructFromGodotObject: (ptr) => ${classInfo.dartName}.withNonNullOwner(ptr),');
          }, ');');
          o.p('_populateMethodInfo();');
        }, '}');
        o.p('return _sTypeInfo!;');
      }, '}');
      o.p('static final _bindings = _${classInfo.name}Bindings();');
      o.p("static const String nativeTypeName = '${classInfo.name}';");
      o.nl();

      o.p('@override');
      o.p("@pragma('vm:entry-point')");
      o.p('ExtensionTypeInfo<${classInfo.dartName}> get typeInfo => sTypeInfo;');

      _writeSignals(o, classInfo);
      _writeSingleton(o, classInfo);
      _writeConstructors(o, classInfo);
      _writeMethods(o, classInfo);
      _writePopulateMethodInfo(o, classInfo);
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

    libraryParts += "export 'classes/${classInfo.name.toSnakeCase()}.dart';\n";
  }

  var classesLibrary = File(path.join(targetDir, 'engine_classes.dart'));
  var out = classesLibrary.openWrite();
  out.write(header);
  out.write(libraryParts);

  await out.close();
}

String _generateImportsFor(GodotApiInfo apiInfo,
    GodotExtensionApiJsonClass classInfo, String rootLibDir, String targetDir) {
  StringBuffer buffer = StringBuffer(coreClassesImports);
  final importSet = <String>{};
  importSet.addAll(classInfo.inherits?.findImport() ?? []);

  // TODO: Properties
  // if (classInfo.properties case final members?) {
  //   for (final m in members) {
  //     if (findImportForType(apiInfo, m.type) case final import?) {
  //       importSet.add(import);
  //     }
  //   }
  // }
  if (classInfo.methods case final methods?) {
    for (final m in methods) {
      importSet.addAll(m.arguments?.findImports((e) => e.type) ?? []);
      importSet.addAll(m.returnValue?.type.findImport() ?? []);
    }
  }
  if (classInfo.signals case final signals?) {
    for (final s in signals) {
      importSet.addAll(s.arguments?.findImports((e) => e.type) ?? []);
    }
  }

  final importList = importSet.toList().sorted();
  for (final import in importList) {
    final importLoc = path.join(rootLibDir, import);
    final resolvedRelativeImport =
        path.relative(importLoc, from: targetDir).replaceAll('\\', '/');
    buffer.writeln("import '$resolvedRelativeImport';");
  }

  return buffer.toString();
}

void _writePopulateMethodInfo(
    CodeSink o, GodotExtensionApiJsonClass classInfo) {
  o.b('static void _populateMethodInfo() {', () {
    o.b('_sTypeInfo!.methods = <MethodInfo<${classInfo.dartName}>>[', () {
      _writeMethodInfo(o, classInfo);
    }, '];');
  }, '}');
}

void _writeMethodInfo(CodeSink o, GodotExtensionApiJsonClass classInfo) {
  if (classInfo.methods == null) return;

  // Only the virtual methods that need to be in the MethodInfo table,
  // because all other methods won't be called from Godot => Dart.
  for (final method in classInfo.methods!.where((m) => m.isVirtual)) {
    final dartMethodName = getDartMethodName(method.name, true);
    o.b('MethodInfo(', () {
      o.p("name: '${method.name}',");
      o.indent();
      o.write('dartMethodCall: (self, args) => self.$dartMethodName(');
      if (method.arguments case final args?) {
        for (final (i, arg) in args.indexed) {
          if (arg.proxy.isPointer) {
            o.write('(args[$i] as Pointer<Void>).cast(),');
          } else {
            o.write('args[$i] as ${arg.proxy.dartType},');
          }
        }
      }
      o.write('),');
      o.nl();
      o.b('args: <PropertyInfo>[', () {
        if (method.arguments case final args?) {
          for (final arg in args) {
            o.b('PropertyInfo(', () {
              o.p('typeInfo: ${arg.proxy.typeInfo},'); // Need to get the type info for this item
              o.p("name: '${arg.name}',");
            }, '),');
          }
        }
      }, '],');
      if (method.returnValue case final returnValue?) {
        o.b('returnInfo: PropertyInfo(', () {
          o.p('typeInfo: ${returnValue.proxy.typeInfo},'); // Need to get the type info for this item
          o.p("name: 'return',");
        }, '),');
      }
    }, '),');
  }
}

void _writeSignals(CodeSink o, GodotExtensionApiJsonClass classInfo) {
  if (classInfo.signals == null) return;

  for (final signal in classInfo.signals!) {
    int numArgs = signal.arguments?.length ?? 0;

    // Right now we're using lazy signal construction, but we should see if we
    // want to connect the signals as part of the construcor, or with an initialization
    // call instead.
    final signalVarName = signal.name.toLowerCamelCase();
    if (numArgs == 0) {
      o.p('late final $signalVarName = Signal0(this, \'${signal.name}\');');
    } else {
      final arguments = signal.arguments!;
      final argTypeList =
          arguments.map((e) => godotTypeToDartType(e.type)).join(', ');
      o.p('late final $signalVarName = Signal$numArgs<$argTypeList>(this, \'${signal.name}\');');
    }
  }
  o.nl();
}

void _writeSingleton(CodeSink o, GodotExtensionApiJsonClass classInfo) {
  if (!GodotApiInfo.instance().singletons.contains(classInfo.name)) return;

  // Singleton
  o.p('static GDExtensionObjectPtr? _singletonPtr;');
  o.p('static ${classInfo.dartName}? _singletonObj;');
  o.b('static ${classInfo.dartName} get singleton {', () {
    o.b('if (_singletonPtr == null) {', () {
      o.p('_singletonPtr = gde.globalGetSingleton(sTypeInfo.className);');
      o.p('_singletonObj = _singletonPtr!.toDart() as ${classInfo.dartName};');
    }, '}');

    o.p('return _singletonObj!;');
  }, '}');
  o.nl();
}

void _writeConstructors(CodeSink o, GodotExtensionApiJsonClass classInfo) {
  // Constructors
  o.p('${classInfo.dartName}() : super();');
  o.nl();
  o.p("@pragma('vm:entry-point')");
  o.p('${classInfo.dartName}.withNonNullOwner(Pointer<Void> owner) : super.withNonNullOwner(owner);');
  o.nl();
}

void _writeMethods(CodeSink o, GodotExtensionApiJsonClass classInfo) {
  final methods = classInfo.methods ?? [];

  for (final method in methods) {
    // TODO: Don't generate toString yet
    if (method.name == 'to_string') continue;

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

      if (method.isVararg) {
        _generateVarargMethod(o, method);
        return;
      }

      _generatePtrcallMethod(o, method);
    }, '}');
    o.nl();
  }
}

void _generateVarargMethod(CodeSink o, ClassMethod method) {
  final methodName = escapeMethodName(method.name);
  final returnInfo = method.returnValue?.proxy;
  final hasReturn =
      returnInfo != null && returnInfo.typeCategory != TypeCategory.voidType;
  final arguments = method.arguments?.map((e) => e.proxy).toList() ?? [];

  o.b('${hasReturn ? 'final ret = ' : ''}gde.callNativeMethodBind(_bindings.method${methodName.toUpperCamelCase()}, ${method.isStatic ? 'null' : 'this'}, [',
      () {
    for (final argument in arguments) {
      if (argument.typeCategory == TypeCategory.enumType) {
        o.p('Variant(${escapeName(argument.name).toLowerCamelCase()}.value),');
      } else if (argument.dartType == 'Variant') {
        o.p('${escapeName(argument.name).toLowerCamelCase()},');
      } else {
        o.p('Variant(${escapeName(argument.name).toLowerCamelCase()}),');
      }
    }
    o.p('...vargs,');
  }, ']);');

  if (hasReturn) {
    if (returnInfo.typeCategory == TypeCategory.enumType) {
      o.p('return ${returnInfo.rawDartType}.fromValue(ret.cast<int>());');
    } else if (returnInfo.dartType == 'Variant') {
      o.p('return ret;');
    } else {
      o.p('return ret.cast<${returnInfo.dartType}>()');
    }
  }
}

void _generatePtrcallMethod(CodeSink o, ClassMethod method) {
  final methodName = escapeMethodName(method.name);
  final arguments = method.arguments?.map((e) => e.proxy).toList() ?? [];
  final returnInfo = method.returnValue?.proxy;
  final hasReturn =
      returnInfo != null && returnInfo.typeCategory != TypeCategory.voidType;
  final retString = hasReturn ? 'return ' : '';

  o.b('${retString}using((arena) {', () {
    final argumentsVar = createPtrcallArguments(o, arguments);

    if (hasReturn) {
      writeReturnAllocation(returnInfo, o);
    }

    o.p('gde.ffiBindings.gde_object_method_bind_ptrcall(');
    o.p('  _bindings.method${methodName.toUpperCamelCase()}, ${method.isStatic ? 'nullptr.cast()' : 'nativePtr.cast()'}, $argumentsVar, ${hasReturn ? 'retPtr' : 'nullptr'}.cast());');

    if (hasReturn) {
      writeReturnRead(returnInfo, o);
    }
  }, '});');
}

void _writeBindingsClass(CodeSink o, GodotExtensionApiJsonClass classInfo) {
  o.b('class _${classInfo.name}Bindings {', () {
    final methods = classInfo.methods ?? [];
    for (final method in methods) {
      if (method.isVirtual) {
        continue;
      }

      final methodName = escapeMethodName(method.name).toUpperCamelCase();
      o.p('GDExtensionMethodBindPtr? _method$methodName;');
      o.b('GDExtensionMethodBindPtr get method$methodName {', () {
        o.p('_method$methodName ??= gde.classDbGetMethodBind(${classInfo.dartName}.sTypeInfo.className,');
        o.p("    StringName.fromString('${method.name}'), ${method.hash});");
        o.p('return _method$methodName!;');
      }, '}');
    }
  }, '}');
}
