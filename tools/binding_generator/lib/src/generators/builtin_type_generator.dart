import 'dart:io';

import 'package:path/path.dart' as path;

import '../code_sink.dart';
import '../common_helpers.dart';
import '../gdstring_additional.dart';
import '../godot_api_info.dart';
import '../godot_extension_api_json.dart';
import '../string_extensions.dart';
import '../type_helpers.dart';

Future<void> generateBuiltinBindings(
  GodotApiInfo api,
  String targetDir,
  String buildConfig,
) async {
  targetDir = path.join(targetDir, 'variant');
  var directory = Directory(targetDir);
  if (!directory.existsSync()) {
    await directory.create(recursive: true);
  }

  // Holds all the exports an initializations for the builtins, written as
  // 'builtins.dart' at the end of generation
  var exportsString = '';

  var builtinSizes = {for (final e in api.classSize.sizes) e.name: e.size};

  for (final builtin in api.builtinClasses.values) {
    if (hasDartType(builtin.name)) {
      continue;
    }
    // Check for types we've implemented ourselves

    final size = builtinSizes[builtin.name]!;

    final destPath = path.join(targetDir, '${builtin.name.toSnakeCase()}.dart');
    final o = CodeSink(File(destPath));

    o.write(header);

    // Imports
    writeImports(o, api, builtin, true);

    // Class
    o.b('class ${builtin.dartName} extends BuiltinType {', () {
      o.p('static const int _size = $size;');
      o.p('static final _${builtin.name}Bindings _bindings = _${builtin.name}Bindings();');
      o.p('static late TypeInfo sTypeInfo;');
      o.nl();
      o.p('@override');
      o.p('TypeInfo get typeInfo => sTypeInfo;');
      o.nl();
      o.p('final Pointer<Uint8> _opaque = calloc<Uint8>(_size);');
      o.nl();
      o.p('@override');
      o.p('Pointer<Uint8> get nativePtr => _opaque;');

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

    exportsString += "export '${builtin.name.toSnakeCase()}.dart';\n";
  }

  var exportsFile = File(path.join(targetDir, 'builtins.dart'));
  var out = exportsFile.openWrite();
  out.write(header);
  out.write(exportsString);

  await out.close();
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
  o.b('${builtin.dartName}.fromPointer(Pointer<Void> ptr) {', () {
    o.p('gde.dartBindings.variantCopyFromNative(this, ptr);');
  }, '}');
  o.nl();

  for (final constructor in builtin.constructors) {
    final arguments = constructor.arguments?.map((e) => e.proxy).toList() ?? [];
    final constructorName = getConstructorName(builtin.name, constructor);
    // Special cases -- fromGDString, fromStringName, and copy constructors for GDString and StringName
    if ((builtin.name == 'String' || builtin.name == 'StringName') &&
        constructorName == '.copy') {
      o.b('${builtin.dartName}.copy(final ${builtin.dartName} from) {', () {
        o.b('gde.callBuiltinConstructor(_bindings.constructor_${constructor.index}!, nativePtr.cast(), [',
            () {
          o.p('from.nativePtr.cast(),');
        }, ']);');
      }, '}');
      o.nl();
      continue;
    }
    if (constructorName == '.fromGDString' ||
        constructorName == '.fromStringName') {
      final fromArgument = constructor.arguments!.first;
      final dartType =
          fromArgument.type == 'String' ? 'GDString' : 'StringName';
      o.b('${builtin.dartName}$constructorName(final $dartType from) {', () {
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
    o.b(' {', () {
      withAllocationBlock(arguments, null, o, () {
        var stringArguments = arguments
            .where((e) => e.type == 'String' || e.type == 'StringName');
        for (final strArg in stringArguments) {
          final type = strArg.name == 'String' ? 'GDString' : 'StringName';
          final escapedName = escapeName(strArg.name).toLowerCamelCase();
          o.p('final $type gd$escapedName = $type.fromString($escapedName);');
        }
        o.b('gde.callBuiltinConstructor(_bindings.constructor_${constructor.index}!, nativePtr.cast(), [',
            () {
          for (final argument in arguments) {
            final escapedName = escapeName(argument.name).toLowerCamelCase();
            if (argument.needsAllocation) {
              o.p('${escapedName}Ptr.cast(),');
            } else if (argument.isOptional) {
              o.p('$escapedName?.nativePtr.cast() ?? nullptr,');
            } else if (argument.type == 'String' ||
                argument.type == 'StringName') {
              o.p('gd$escapedName.nativePtr.cast(),');
            } else {
              o.p('$escapedName.nativePtr.cast(),');
            }
          }
        }, ']);');
      });
    }, '}');
    o.nl();
  }

  if (builtin.name == 'String') {
    gdStringFromString(o);
    gdStringToDartString(o);
  } else if (builtin.name == 'StringName') {
    stringNameFromString(o);
    stringNameToDartString(o);
  }
}

void _writeMembers(CodeSink o, BuiltinClass builtin) {
  final members = builtin.members ?? [];
  for (final member in members) {
    final memberProxy = member.proxy;
    o.b('${memberProxy.dartType} get ${member.name} {', () {
      if (member.type == 'String') {
        o.p('GDString retVal = GDString();');
      } else {
        o.p('${memberProxy.dartType} retVal = ${memberProxy.defaultValue};');
      }
      withAllocationBlock([], memberProxy, o, () {
        bool extractReturnValue = writeReturnAllocation(memberProxy, o);
        o.p('final f = _bindings.member${member.name.toUpperCamelCase()}Getter!.asFunction<void Function(GDExtensionConstTypePtr, GDExtensionTypePtr)>(isLeaf: true);');
        o.p('f(nativePtr.cast(), retPtr.cast());');
        if (extractReturnValue) {
          if (memberProxy.typeCategory == TypeCategory.engineClass) {
            o.p('retVal = retPtr == nullptr ? null : ${memberProxy.rawDartType}.fromOwner(retPtr.value);');
          } else {
            o.p('retVal = retPtr.value;');
          }
        }
      });

      if (member.type == 'String') {
        o.p('return retVal.toDartString();');
      } else {
        o.p('return retVal;');
      }
    }, '}');
    o.nl();

    o.b('set ${member.name}(${memberProxy.dartType} value) {', () {
      var valueMemberProxy = memberProxy.renamed('value');
      withAllocationBlock([valueMemberProxy], null, o, () {
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
    var methodName = escapeMethodName(method.name);
    o.b('${makeSignature(method)} {', () {
      final arguments = method.arguments?.map((e) => e.proxy).toList() ?? [];

      if (method.isVararg) {
        // Special case.. use `variantCall` instead
        final retValStr = method.returnType != null ? 'Variant retVal = ' : '';
        o.p('Variant self = convertToVariant(this);');
        o.p("${retValStr}gde.variantCall(self, '${method.name}', args);");
        if (method.returnType != null) {
          if (method.returnType == 'Variant') {
            o.p('return retVal;');
          } else {
            o.p('return convertFromVariant(retVal, null) as ${method.returnType};');
          }
        }
        return;
      }

      final retArg = argumentFromType(method.returnType).proxy;

      if (retArg.typeCategory != TypeCategory.voidType) {
        if (method.returnType == 'String') {
          o.p('GDString retVal = GDString();');
        } else if (method.returnType == 'StringName') {
          o.p('StringName retVal = StringName();');
        } else if (retArg.isOptional) {
          o.p('${retArg.dartType} retVal;');
        } else {
          o.p('${retArg.dartType} retVal = ${retArg.defaultValue};');
        }
      }

      final stringArguments = method.arguments
              ?.where((e) => e.type == 'String' || e.type == 'StringName') ??
          [];
      withAllocationBlock(arguments, retArg, o, () {
        bool extractReturnValue = false;
        if (retArg.typeCategory != TypeCategory.voidType) {
          extractReturnValue = writeReturnAllocation(retArg, o);
        }
        for (final strParam in stringArguments) {
          final type = strParam.name == 'String' ? 'GDString' : 'StringName';
          final escapedName = escapeName(strParam.name).toLowerCamelCase();
          o.p('final $type gd$escapedName = $type.fromString($escapedName);');
        }
        final retParam = retArg.typeCategory == TypeCategory.voidType
            ? 'nullptr'
            : 'retPtr.cast()';
        final thisParam =
            method.isStatic == true ? 'nullptr' : 'nativePtr.cast()';
        o.b('gde.callBuiltinMethodPtr(_bindings.method${methodName.toUpperCamelCase()}, $thisParam, $retParam, [',
            () {
          for (final argument in arguments) {
            final escapedName = escapeName(argument.name).toLowerCamelCase();
            if (argument.needsAllocation) {
              o.p('${escapedName}Ptr.cast(),');
            } else if (argument.isOptional) {
              o.p('$escapedName?.nativePtr.cast() ?? nullptr,');
            } else if (argument.type == 'String' ||
                argument.type == 'StringName') {
              o.p('gd$escapedName.nativePtr.cast(),');
            } else {
              o.p('$escapedName.nativePtr.cast(),');
            }
          }
        }, ']);');

        if (retArg.typeCategory != TypeCategory.voidType &&
            extractReturnValue) {
          if (retArg.typeCategory == TypeCategory.engineClass) {
            o.p('retVal = retPtr == nullptr ? null : ${retArg.rawDartType}.fromOwner(retPtr.value);');
          } else {
            o.p('retVal = retPtr.value;');
          }
        }
      });

      if (retArg.typeCategory != TypeCategory.voidType) {
        if (retArg.type == 'String' || retArg.type == 'StringName') {
          o.p('return retVal.toDartString();');
        } else {
          o.p('return retVal;');
        }
      }
    }, '}');
    o.nl();
  }

  // TODO: Double check this logic, godot-cpp hasn't gotten around to implementing this
  if (builtin.indexingReturnType != null && builtin.name != 'Dictionary') {
    var dartReturnType = godotTypeToDartType(builtin.indexingReturnType);
    o.b('$dartReturnType operator [](int index) {', () {
      o.p('final ret = Variant();');
      o.p('_bindings.indexedGetter?.asFunction<');
      o.p('        void Function(GDExtensionConstTypePtr, int, GDExtensionTypePtr)>(');
      o.p('    isLeaf: true)(nativePtr.cast(), index, ret.nativePtr.cast());');
      o.p('return convertFromVariant(ret, null) as $dartReturnType;');
    }, '}');
    o.nl();
    o.b('void operator []=(int index, $dartReturnType value) {', () {
      o.p('var variantValue = convertToVariant(value);');
      o.p('_bindings.indexedSetter?.asFunction<');
      o.p('        void Function(GDExtensionTypePtr, int, GDExtensionTypePtr)>(');
      o.p('    isLeaf: true)(nativePtr.cast(), index, variantValue.nativePtr.cast());');
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
