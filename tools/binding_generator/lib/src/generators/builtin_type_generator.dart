import 'dart:io';

import 'package:path/path.dart' as path;

import '../code_sink.dart';
import '../common_helpers.dart';
import '../godot_api_info.dart';
import '../godot_extension_api_json.dart';
import '../string_extensions.dart';
import '../type_helpers.dart';
import '../type_info.dart';

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
      o.p('static late TypeInfo typeInfo;');
      o.nl();
      o.p('@override');
      o.p('TypeInfo get staticTypeInfo => typeInfo;');
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
    final enums = builtin.enums ?? <dynamic>[];
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
  o.nl();
  o.b('static void initBindings() {', () {
    o.p('initBindingsConstructorDestructor();');
    o.nl();
    o.b('typeInfo = TypeInfo(', () {
      o.p('StringName.fromString(builtin.name),');
      o.p('variantType: GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_${builtin.name.toUpperSnakeCase()},');
      o.p('size: _size,');
    }, ');');

    final members = builtin.members ?? [];
    for (final member in members) {
      o.p('_bindings.member${member.name.toUpperCamelCase()}Getter = gde.variantGetPtrGetter(');
      o.p('  GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_${builtin.name.toUpperSnakeCase()},');
      o.p("  StringName.fromString('${member.name}'),");
      o.p(');');
      o.p('_bindings.member${member.name.toUpperCamelCase()}Setter = gde.variantGetPtrSetter(');
      o.p('  GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_${builtin.name.toUpperSnakeCase()}');
      o.p("  StringName.fromString('${member.name}'),");
      o.p(');');
    }

    final methods = builtin.methods ?? [];
    for (final method in methods) {
      var dartMethodName = escapeMethodName(method.name);
      o.p('_bindings.method${dartMethodName.toUpperCamelCase()} = gde.variantGetBuiltinMethod(');
      o.p('  GDExtensionVariantType.GDEXTENSION_VARIANT_TYPE_${builtin.name.toUpperSnakeCase()},');
      o.p("  StringName.fromString('${method.name}'),");
      o.p('  ${method.hash},');
      o.p(');');
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
    o.b('${builtin.dartName}$constructorName(', () {
      // Argument list
      for (final argument in arguments) {
        o.p('final ${argument.dartType} ${escapeName(argument.name)},');
      }
    }, ')', newLine: false);
    o.b(' {', () {
      withAllocationBlock(arguments, null, o, () {
        o.b('gde.callBuiltinConstructor(_bindings.constructor_${constructor.index}!, nativePtr.cast(), [',
            () {
          for (final argument in arguments) {
            if (argument.needsAllocation) {
              o.p('${argument.name}Ptr.cast(),');
            } else if (argument.isOptional) {
              o.p('${argument.name}?.nativePtr.cast() ?? nullptr,');
            } else {
              o.p('${argument.name}.nativePtr.cast(),');
            }
          }
        }, ']);');
      });
    }, '}');
    o.nl();
  }

  // if (builtin.godotType == 'String') {
  //   out.write(gdStringFromString());
  //   out.write(gdStringToDartString());
  // } else if (builtin.godotType == 'StringName') {
  //   out.write(stringNameFromString());
  // }
}

void _writeMembers(CodeSink o, BuiltinClass builtin) {
  final members = builtin.members ?? [];
  for (final member in members) {
    final memberProxy = member.proxy;
    o.b('${memberProxy.dartType} get ${member.name} {', () {
      if (member.type == 'String') {
        o.p('GDString retVal = GDString();');
      } else {
        o.p('${memberProxy.dartType} retVal = ${memberProxy.getDefaultValue()};');
      }
      withAllocationBlock([], memberProxy, o, () {
        bool extractReturnValue = writeReturnAllocation(memberProxy, o);
        o.p('final f = _bindings.member${member.name.toUpperCamelCase()}Getter!.asFunction<void Function(GDExtensionConstTypePtr, GDExtensionTypePtr)>(isLeaf: true);');
        o.p('f(nativePtr.cast(), retPtr.cast());');
        if (extractReturnValue) {
          if (memberProxy.typeCategory == TypeCategory.engineClass) {
            o.p('retVal = retPtr == nullptr ? null : ${memberProxy.dartType}.fromOwner(retPtr.value);');
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
      withAllocationBlock([memberProxy], null, o, () {
        String valueCast;
        if (memberProxy.needsAllocation) {
          valueCast = '${member.name}Ptr.cast()';
        } else if (member.type == 'String') {
          valueCast = 'GDString.fromString(${member.name}).nativePtr.cast()';
        } else if (memberProxy.isOptional) {
          valueCast = '${member.name}?.nativePtr.cast() ?? nullptr';
        } else {
          valueCast = '${member.name}.nativePtr.cast()';
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
      final retArg = argumentFromType(method.returnType).proxy;

      if (retArg.typeCategory != TypeCategory.voidType) {
        if (method.returnType == 'String') {
          o.p('GDString retVal = GDString();');
        } else {
          final dartType = godotTypeToDartType(method.returnType);
          o.p('$dartType retVal = ${retArg.getDefaultValue()};');
        }
      }

      final arguments = method.arguments?.map((e) => e.proxy).toList() ?? [];
      withAllocationBlock(arguments, retArg, o, () {
        bool extractReturnValue = false;
        if (retArg.typeCategory != TypeCategory.voidType) {
          extractReturnValue = writeReturnAllocation(retArg, o);
        }
        final retParam = retArg.typeCategory == TypeCategory.voidType
            ? 'nullptr'
            : 'retPtr.cast()';
        final thisParam =
            method.isStatic == true ? 'nullptr' : 'nativePtr.cast()';
        o.b('gde.callBuiltinMethodPtr(_bindings.method${methodName.toUpperCamelCase()}, $thisParam, $retParam, [',
            () {
          for (final argument in arguments) {
            if (argument.needsAllocation) {
              o.p('${argument.name}Ptr.cast(),');
            } else if (argument.isOptional) {
              o.p('${argument.name}?.nativePtr.cast() ?? nullptr,');
            } else {
              o.p('${argument.name}.nativePtr.cast(),');
            }
          }
        }, ']);');

        if (retArg.typeCategory != TypeCategory.voidType &&
            extractReturnValue) {
          if (retArg.typeCategory == TypeCategory.engineClass) {
            final dartType = godotTypeToDartType(method.returnType);
            o.p('retVal = retPtr == nullptr ? null : $dartType.fromOwner(retPtr.value);');
          } else {
            o.p('retVal = retPtr.value;');
          }
        }
      });

      if (retArg.typeCategory != TypeCategory.voidType) {
        if (method.returnType == 'String') {
          o.p('return retVal.toDartString();\n');
        } else {
          o.p('return retVal;\n');
        }
      }
    }, '}');
  }
  o.nl();
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
  }, '}');
  o.nl();
}
