import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as path;

import '../code_sink.dart';
import '../common_helpers.dart';
import '../gdstring_additional.dart';
import '../godot_api_info.dart';
import '../godot_extension_api_json.dart';
import '../string_extensions.dart';
import '../type_helpers.dart';

final coreBuiltinImports = '''
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:meta/meta.dart';

import '../../core/core.dart';
import '../../extensions/core_extensions.dart';
import '../../variant/variant.dart';

import 'string_name.dart';
import 'string.dart';
import '../global_constants.dart';
''';

Future<void> generateBuiltinBindings(
  GodotApiInfo api,
  String rootDirectory,
  String targetDir,
  String buildConfig,
) async {
  final variantTargetDir = path.join(targetDir, 'variant');
  var directory = Directory(variantTargetDir);
  if (!directory.existsSync()) {
    await directory.create(recursive: true);
  }

  // Holds all the parts to be written as the library
  // 'builtins.dart' at the end of generation
  var builtinExports = '';

  var builtinSizes = {for (final e in api.classSize.sizes) e.name: e.size};

  for (final builtin in api.builtinClasses.values) {
    if (hasDartType(builtin.name)) {
      continue;
    }
    if (hasCustomImplementation(builtin.name)) {
      continue;
    }

    final size = builtinSizes[builtin.name]!;

    final destPath =
        path.join(variantTargetDir, '${builtin.name.toSnakeCase()}.dart');
    final o = CodeSink(File(destPath));

    o.write(header);
    o.write(_generateImportsFor(builtin, rootDirectory, variantTargetDir));
    o.nl();

    o.nl();

    // Class
    o.b('class ${builtin.dartName} extends BuiltinType {', () {
      o.p('static const int _size = $size;');
      o.p('static final _${builtin.name}Bindings _bindings = _${builtin.name}Bindings();');
      o.p('static late TypeInfo sTypeInfo;');
      o.nl();
      o.p('@override');
      o.p('TypeInfo get typeInfo => sTypeInfo;');
      o.nl();

      o.b('static void initBindingsConstructorDestructor() {', () {
        for (final constructor in builtin.constructors) {
          o.p('_bindings.constructor_${constructor.index} = gde.variantGetConstructor(');
          o.p('    GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_${builtin.name.toUpperSnakeCase()}, ${constructor.index});');
        }

        if (builtin.hasDestructor) {
          o.p('_bindings.destructor = gde.variantGetDestructor(');
          o.p('    GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_${builtin.name.toUpperSnakeCase()});');
        }
      }, '}');

      _writeBindingInitializer(o, builtin);
      _writeConstructors(o, builtin);
      _writeMembers(o, builtin);
      _writeMethods(o, builtin);
    }, '}');

    // Class Enums
    final enums = builtin.enums ?? [];
    for (final classEnum in enums) {
      writeEnum(classEnum, builtin.name, o);
    }

    _writeBindingClass(o, builtin);

    await o.close();

    builtinExports += "export 'variant/${builtin.name.toSnakeCase()}.dart';\n";
  }

  var exportsFile = File(path.join(targetDir, 'builtins.dart'));
  var out = exportsFile.openWrite();
  out.write(header);
  out.write(builtinExports);

  await out.close();
}

String _generateImportsFor(
    BuiltinClass builtin, String rootLibDir, String targetDir) {
  StringBuffer buffer = StringBuffer(coreBuiltinImports);
  final importSet = <String>{};
  for (final c in builtin.constructors) {
    importSet.addAll(c.arguments?.findImports((a) => a.type) ?? []);
  }
  importSet.addAll(builtin.members?.findImports((m) => m.type) ?? []);
  if (builtin.methods case final methods?) {
    for (final m in methods) {
      importSet.addAll(m.arguments?.findImports((a) => a.type) ?? []);
      importSet.addAll(m.returnType?.findImport() ?? []);
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

void _writeBindingInitializer(CodeSink o, BuiltinClass builtin) {
  var variantEnum =
      'GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_${builtin.name.toUpperSnakeCase()}';
  o.nl();
  o.b('static void initBindings() {', () {
    o.p('initBindingsConstructorDestructor();');
    o.nl();
    o.b('sTypeInfo = TypeInfo(', () {
      o.p('${builtin.dartName},');
      o.p("StringName.fromString('${builtin.name}'),");
      o.p('StringName(),');
      o.p('variantType: $variantEnum,');
      o.p('size: _size,');
    }, ');');

    final members = builtin.members ?? [];
    for (final member in members) {
      o.p('_bindings.member${member.name.toUpperCamelCase()}Getter = gde.variantGetPtrGetter(');
      o.p('  $variantEnum,');
      o.p("  StringName.fromString('${member.name}'),");
      o.p(');');
      o.p('_bindings.member${member.name.toUpperCamelCase()}Setter = gde.variantGetPtrSetter(');
      o.p('  $variantEnum,');
      o.p("  StringName.fromString('${member.name}'),");
      o.p(');');
    }

    final methods = builtin.methods ?? [];
    for (final method in methods) {
      var dartMethodName = escapeMethodName(method.name);
      o.p('_bindings.method${dartMethodName.toUpperCamelCase()} = gde.variantGetBuiltinMethod(');
      o.p('  $variantEnum,');
      o.p("  StringName.fromString('${method.name}'),");
      o.p('  ${method.hash},');
      o.p(');');
    }

    if (builtin.indexingReturnType != null) {
      o.p('_bindings.indexedSetter = gde.variantGetIndexedSetter($variantEnum);');
      o.p('_bindings.indexedGetter = gde.variantGetIndexedGetter($variantEnum);');
    }
    if (builtin.isKeyed) {
      o.p('_bindings.keyedSetter = gde.variantGetKeyedSetter($variantEnum);');
      o.p('_bindings.keyedGetter = gde.variantGetKeyedGetter($variantEnum);');
      o.p('_bindings.keyedChecker = gde.variantGetKeyedChecker($variantEnum);');
    }
  }, '}');
  o.nl();
}

void _writeConstructors(CodeSink o, BuiltinClass builtin) {
  final superConstructor =
      'super(_size, ${builtin.hasDestructor ? '_bindings.destructor' : 'null'})';

  o.b('${builtin.dartName}.fromVariantPtr(GDExtensionVariantPtr ptr)', () {
    o.p('  : $superConstructor {');
    o.p('final c = getToTypeConstructor(GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_${builtin.name.toUpperSnakeCase()});');
    o.p('c!(nativePtr.cast(), ptr);');
  }, '}');
  o.nl();

  for (final constructor in builtin.constructors) {
    final arguments = constructor.arguments?.map((e) => e.proxy).toList() ?? [];
    final constructorName = getConstructorName(builtin.name, constructor);

    if (constructorName == '.copy') {
      // Add a second constructor to copy from a Pointer (used in Ptr calls)
      o.b('${builtin.dartName}.copyPtr(GDExtensionConstTypePtr ptr)', () {
        o.p('  : $superConstructor {');
        o.b('gde.callBuiltinConstructor(_bindings.constructor_${constructor.index}!, nativePtr.cast(), [',
            () {
          o.p('ptr.cast(),');
        }, ']);');
      }, '}');

      // Add constructCopy, which help us return builtin types
      o.p('@override');
      o.b('void constructCopy(GDExtensionTypePtr ptr) {', () {
        o.b('gde.callBuiltinConstructor(_bindings.constructor_${constructor.index}!, ptr, [',
            () {
          o.p('nativePtr.cast(),');
        }, ']);');
      }, '}');
    }

    // Special cases -- fromGDString, fromStringName, and copy constructors for GDString and StringName
    if ((builtin.name == 'String' || builtin.name == 'StringName') &&
        constructorName == '.copy') {
      o.b('${builtin.dartName}.copy(final ${builtin.dartName} from)', () {
        o.p('  : $superConstructor {');
        o.b('gde.callBuiltinConstructor(_bindings.constructor_${constructor.index}!, nativePtr.cast(), [',
            () {
          o.p('from.nativePtr.cast(),');
        }, ']);');
      }, '}');
      o.nl();
      continue;
    }

    if (constructorName == '.fromGDString') {
      o.b('${builtin.dartName}$constructorName(final GDString from)', () {
        o.p('  : $superConstructor {');
        o.b('gde.callBuiltinConstructor(_bindings.constructor_${constructor.index}!, nativePtr.cast(), [',
            () {
          o.p('from.nativePtr.cast(),');
        }, ']);');
      }, '}');
      o.nl();

      // Allow anything with .fromGDString to also have .fromString (except GDString and Color)
      if (builtin.dartName != 'GDString' && builtin.dartName != 'Color') {
        o.p('${builtin.dartName}.fromString(final String from) : this.fromGDString(GDString.fromString(from));');
        o.nl();
      }
      continue;
    } else if (constructorName == '.fromStringName') {
      o.b('${builtin.dartName}$constructorName(final StringName from)', () {
        o.p('  : $superConstructor {');
        o.b('gde.callBuiltinConstructor(_bindings.constructor_${constructor.index}!, nativePtr.cast(), [',
            () {
          o.p('from.nativePtr.cast(),');
        }, ']);');
      }, '}');
      o.nl();
      continue;
    }

    o.b('${builtin.dartName}$constructorName(', () {
      // Argument list
      for (final argument in arguments) {
        var type = argument.dartType;
        o.p('final $type ${escapeName(argument.name).toLowerCamelCase()},');
      }
    }, ')', newLine: false);
    o.b('', () {
      o.p('  : $superConstructor {');
      withAllocationBlock(arguments, null, o, () {
        final argumentsVar = createPtrcallArguments(o, arguments);

        o.p('final void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>) ctor =');
        o.p('    _bindings.constructor_${constructor.index}!.asFunction();');
        o.p('ctor(nativePtr.cast(), $argumentsVar);');
      });
    }, '}');
    o.nl();
  }

  if (builtin.name == 'String') {
    gdStringFromString(o);
    gdStringToDartString(o);
  } else if (builtin.name == 'StringName') {
    stringNameToDartString(o);
  }
}

void _writeMembers(CodeSink o, BuiltinClass builtin) {
  final members = builtin.members ?? [];
  for (final member in members) {
    final memberProxy = member.proxy;
    o.b('${memberProxy.dartType} get ${member.name} {', () {
      o.b('return using((arena) {', () {
        writeReturnAllocation(memberProxy, o);
        o.p('final f = _bindings.member${member.name.toUpperCamelCase()}Getter!.asFunction<void Function(GDExtensionConstTypePtr, GDExtensionTypePtr)>(isLeaf: true);');
        o.p('f(nativePtr.cast(), retPtr.cast());');

        writeReturnRead(memberProxy, o);
      }, '});');
    }, '}');
    o.nl();

    o.b('set ${member.name}(${memberProxy.dartType} value) {', () {
      var valueMemberProxy = memberProxy.renamed('value');
      withAllocationBlock([valueMemberProxy], null, o, () {
        writeArgumentAllocations([valueMemberProxy], o);
        String valueCast;
        if (memberProxy.needsAllocation) {
          valueCast = '${valueMemberProxy.name}Ptr.cast()';
        } else if (valueMemberProxy.type == 'String') {
          valueCast = 'GDString.fromString(${member.name}).nativePtr.cast()';
        } else if (valueMemberProxy.isOptional) {
          valueCast = '${valueMemberProxy.name}?.nativePtr.cast() ?? nullptr';
        } else {
          valueCast = '${valueMemberProxy.name}.nativePtr.cast()';
        }
        o.p('final f = _bindings.member${member.name.toUpperCamelCase()}Setter!.asFunction<void Function(GDExtensionConstTypePtr, GDExtensionTypePtr)>(isLeaf: true);');
        o.p('f(nativePtr.cast(), $valueCast);');
      });
    }, '}');
    o.nl();
  }
}

void _writeMethods(CodeSink o, BuiltinClass builtin) {
  final methods = builtin.methods ?? [];
  for (final method in methods) {
    o.b('${makeSignature(method)} {', () {
      if (method.isVararg) {
        _generateVarargMethod(o, method);
        return;
      }

      _generatePtrcallMethod(o, method);
    }, '}');
    o.nl();
  }

  // TODO: This can be made more efficient for PackedXArray, but for now we're going
  // to just use Variant's indexed getter / setters
  if (builtin.indexingReturnType != null && builtin.name != 'Dictionary') {
    var dartReturnType = godotTypeToDartType(builtin.indexingReturnType);
    o.b('$dartReturnType operator [](int index) {', () {
      o.p('final self = Variant(this);');
      o.p('final ret = gde.variantGetIndexed(self, index);');
      if (dartReturnType == 'Variant') {
        o.p('return ret;');
      } else {
        o.p('return convertFromVariant(ret) as $dartReturnType;');
      }
    }, '}');
    o.nl();
    o.b('void operator []=(int index, $dartReturnType value) {', () {
      o.p('final self = Variant(this);');
      if (dartReturnType == 'Variant') {
        o.p('gde.variantSetIndexed(self, index, value);');
      } else {
        o.p('final variantValue = Variant(value);');
        o.p('gde.variantSetIndexed(self, index, variantValue);');
      }
    }, '}');
    o.nl();
  }

  if (builtin.name == 'Dictionary') {
    o.b('Variant operator [](Variant key) {', () {
      o.p('final ret = Variant();');
      o.p('_bindings.keyedGetter?.asFunction<');
      o.p('        void Function(GDExtensionConstTypePtr, GDExtensionConstTypePtr,');
      o.p('            GDExtensionTypePtr)>(isLeaf: true)(');
      o.p('    nativePtr.cast(), key.nativePtr.cast(), ret.nativePtr.cast());');
      o.p('return ret;');
    }, '}');
    o.nl();
    o.b('void operator []=(Variant key, Variant value) {', () {
      o.p('_bindings.keyedSetter?.asFunction<');
      o.p('      void Function(GDExtensionTypePtr, GDExtensionConstTypePtr,');
      o.p('          GDExtensionTypePtr)>(isLeaf: true)(');
      o.p('  nativePtr.cast(), key.nativePtr.cast(), value.nativePtr.cast());');
    }, '}');
    o.nl();
  }
}

void _generateVarargMethod(CodeSink o, BuiltinClassMethod method) {
  final hasReturn = method.returnType != null;
  final arguments = method.arguments?.map((e) => e.proxy).toList() ?? [];

  o.p('final self = Variant(this);');
  o.b("${hasReturn ? 'final retVal = ' : ''}gde.variantCall(self, '${method.name}', [",
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
    if (method.returnType == 'Variant') {
      o.p('return retVal;');
    } else {
      o.p('return convertFromVariant(retVal) as ${method.returnType};');
    }
  }
}

void _generatePtrcallMethod(CodeSink o, BuiltinClassMethod method) {
  final methodName = escapeMethodName(method.name);
  final arguments = method.arguments?.map((e) => e.proxy).toList() ?? [];
  final returnInfo = ArgumentProxy.fromTypeName(method.returnType);
  final hasReturn = returnInfo.typeCategory != TypeCategory.voidType;
  final retString = hasReturn ? 'return ' : '';

  o.b('${retString}using((arena) {', () {
    final argumentsVar = createPtrcallArguments(o, arguments);

    if (hasReturn) {
      writeReturnAllocation(returnInfo, o);
    }

    final selfPtr = method.isStatic ? 'nullptr.cast()' : 'nativePtr.cast()';
    final returnPtr = hasReturn ? 'retPtr.cast()' : 'nullptr.cast()';

    o.p('void Function(GDExtensionTypePtr, Pointer<GDExtensionConstTypePtr>,');
    o.p('    GDExtensionTypePtr, int) m = _bindings.method${methodName.toUpperCamelCase()}!.asFunction();');
    o.p('m($selfPtr, $argumentsVar, $returnPtr, ${method.arguments?.length ?? 0});');

    if (hasReturn) {
      writeReturnRead(returnInfo, o);
    }
  }, '});');
}

void _writeBindingClass(CodeSink o, BuiltinClass builtin) {
  // Binding Class
  o.b('class _${builtin.name}Bindings {', () {
    for (final constructor in builtin.constructors) {
      o.p('GDExtensionPtrConstructor? constructor_${constructor.index};');
    }
    if (builtin.hasDestructor) {
      o.p('GDExtensionPtrDestructor? destructor;');
    }
    final members = builtin.members ?? [];
    for (final member in members) {
      final memberName = member.name.toUpperCamelCase();
      o.p('GDExtensionPtrGetter? member${memberName}Getter;');
      o.p('GDExtensionPtrSetter? member${memberName}Setter;');
    }
    final methods = builtin.methods ?? [];
    for (final method in methods) {
      final methodName = method.name.toUpperCamelCase();
      o.p('GDExtensionPtrBuiltInMethod? method$methodName;');
    }
    if (builtin.indexingReturnType != null) {
      o.p('GDExtensionPtrIndexedSetter? indexedSetter;');
      o.p('GDExtensionPtrIndexedGetter? indexedGetter;');
    }
    if (builtin.isKeyed) {
      o.p('GDExtensionPtrKeyedSetter? keyedSetter;');
      o.p('GDExtensionPtrKeyedGetter? keyedGetter;');
      o.p('GDExtensionPtrKeyedChecker? keyedChecker;');
    }
  }, '}');
  o.nl();
}
