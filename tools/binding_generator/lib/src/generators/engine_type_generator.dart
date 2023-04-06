import 'dart:io';

import 'package:collection/collection.dart';
import 'package:path/path.dart' as path;

import '../common_helpers.dart';
import '../godot_api_info.dart';
import '../string_extensions.dart';
import '../type_helpers.dart';
import '../type_info.dart';

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

  for (TypeInfo classInfo in api.engineClasses.values) {
    if (hasDartType(classInfo.godotType)) {
      continue;
    }

    final destPath =
        path.join(targetDir, '${classInfo.godotType.toSnakeCase()}.dart');
    final out = File(destPath).openWrite();

    out.write(header);

    writeImports(out, api, classInfo.api, false);

    final inherits = (classInfo.api['inherits'] as String?) ?? 'ExtensionType';
    final correctedInherits = getCorrectedType(inherits);

    out.write('''

class ${classInfo.dartType} extends $correctedInherits {
  static TypeInfo? _typeInfo;
  static final _bindings = _${classInfo.godotType}Bindings();
  static Map<String, Pointer<GodotVirtualFunction>>? _vTable;
  static Map<String, Pointer<GodotVirtualFunction>> get vTable {
    if (_vTable == null) {
      _initVTable();
    }
    return _vTable!;
  }

  static TypeInfo get typeInfo {
    _typeInfo ??= TypeInfo(
      StringName.fromString('${classInfo.godotType}'),
      parentClass: StringName.fromString('$inherits'),
      bindingCallbacks: bindingCallbacks,
    );
    return _typeInfo!;
  }
  @override
  TypeInfo get staticTypeInfo => typeInfo;

  Map<String, Pointer<GodotVirtualFunction>> get _staticVTable => vTable;
''');

    // Singleton
    if (api.singletons.contains(classInfo.godotType)) {
      out.write('''
  
  static GDExtensionObjectPtr? _singletonPtr;
  static ${classInfo.dartType}? _singletonObj;
  
  static ${classInfo.dartType} get singleton {
    if (_singletonPtr == null) {
      _singletonPtr = gde.globalGetSingleton(typeInfo.className);
      _singletonObj = gde.dartBindings.gdObjectToDartObject(
          _singletonPtr!.cast(), bindingCallbacks) as ${classInfo.dartType};
    }
    return _singletonObj!;
  }
''');
    }

    // Constructors
    out.write('''
  ${classInfo.dartType}() : super.forType(typeInfo.className);
  
  ${classInfo.dartType}.forType(StringName type) : super.forType(type);
  ${classInfo.dartType}.withNonNullOwner(Pointer<Void> owner) : super.withNonNullOwner(owner);
  static ${classInfo.dartType}? fromOwner(Pointer<Void> owner) {
    if (owner == nullptr) return null;
    return ${classInfo.dartType}.withNonNullOwner(owner);
  }

''');

    List<dynamic> methods =
        classInfo.api['methods'] ?? <Map<String, dynamic>>[];

    for (Map<String, dynamic> method in methods) {
      final methodName = escapeMethodName(method['name'] as String);
      final returnInfo = api.getReturnInfo(method);
      final hasReturn =
          returnInfo.typeInfo.typeCategory != TypeCategory.voidType;
      final isStatic = method['is_static'] as bool;
      final signature = makeSignature(api, method);

      out.write('''
  $signature {
''');

      if (method['is_virtual'] as bool) {
        if (returnInfo.typeInfo.typeCategory != TypeCategory.voidType) {
          final defaultValue = getDefaultValueForAgument(returnInfo);
          out.write('    return $defaultValue;\n');
        }
      } else {
        final arguments = (method['arguments'] as List<dynamic>? ?? <dynamic>[])
            .map((dynamic e) => api.getArgumentInfo(e))
            .toList();

        // TODO: Research if we can do ptrCalls
        out.write('''
    var method = _bindings.method${methodName.toUpperCamelCase()};
    if (method == null) {
      _bindings.method${methodName.toUpperCamelCase()} = gde.classDbGetMethodBind(
             typeInfo.className, StringName.fromString('${method['name']}'), ${method['hash']});
      method = _bindings.method${methodName.toUpperCamelCase()};
    }
    ${hasReturn ? 'final ret = ' : ''}gde.callNativeMethodBind(method!, ${isStatic ? 'null' : 'this'}, [
''');
        for (final argument in arguments) {
          out.write('      convertToVariant(${argument.name}),\n');
        }

        out.write('''
    ]);
''');

        if (hasReturn) {
          var bindingCallbacks = 'null';
          if (returnInfo.typeInfo.typeCategory == TypeCategory.engineClass) {
            bindingCallbacks = '${returnInfo.dartType}.bindingCallbacks';
          }

          if (returnInfo.typeInfo.typeCategory == TypeCategory.enumType) {
            out.write(
                '    return ${returnInfo.fullDartType}.fromValue(convertFromVariant(ret, $bindingCallbacks) as int);');
          } else {
            out.write(
                '    return convertFromVariant(ret, $bindingCallbacks) as ${returnInfo.fullDartType};\n');
          }
        }
      }

      out.write('  }\n\n');
    }

    out.write('''
  // Binding callbacks
  static Pointer<GDExtensionInstanceBindingCallbacks>? _bindingCallbacks;
  static Pointer<GDExtensionInstanceBindingCallbacks>? get bindingCallbacks {
    if (_bindingCallbacks == null) {
      _initBindings();
    }
    return _bindingCallbacks!;
  }

  static Pointer<Void> _bindingCreateCallback(
      Pointer<Void> token, Pointer<Void> instance) {
    final dartInstance = ${classInfo.dartType}.withNonNullOwner(instance);
    return gde.dartBindings.toPersistentHandle(dartInstance);
  }

  static void _bindingFreeCallback(
      Pointer<Void> token, Pointer<Void> instance, Pointer<Void> binding) {
    gde.dartBindings.clearPersistentHandle(binding);
  }

  static int _bindingReferenceCallback(
      Pointer<Void> token, Pointer<Void> instance, int reference) {
    return 1;
  }

  static void _initBindings() {
    _bindingCallbacks = malloc<GDExtensionInstanceBindingCallbacks>();
    _bindingCallbacks!.ref
      ..create_callback = Pointer.fromFunction(_bindingCreateCallback)
      ..free_callback = Pointer.fromFunction(_bindingFreeCallback)
      ..reference_callback = Pointer.fromFunction(_bindingReferenceCallback, 1);
    _initVTable();
  }

  // Virtual functions
  static void _initVTable() {
    _vTable = {};
''');

    if (correctedInherits != 'ExtensionType') {
      out.write('    _vTable!.addAll($correctedInherits.vTable);\n');
    }

    for (Map<String, dynamic> method
        in methods.where((dynamic m) => m['is_virtual'] == true)) {
      var methodName = method['name'] as String;
      methodName = escapeMethodName(methodName).toLowerCamelCase();
      out.write('''
    _vTable!['${method['name']}'] = Pointer.fromFunction(__$methodName);
''');
    }

    out.write('''
  }

''');

    for (Map<String, dynamic> method
        in methods.where((dynamic m) => m['is_virtual'] == true)) {
      var methodName = method['name'] as String;
      methodName = escapeMethodName(methodName).toLowerCamelCase();
      final dartMethodName = getDartMethodName(method);
      final arguments = (method['arguments'] as List?)
              ?.map((dynamic e) => api.getArgumentInfo(e)) ??
          [];
      final returnInfo = api.getReturnInfo(method);
      final hasReturn =
          returnInfo.typeInfo.typeCategory != TypeCategory.voidType;
      out.write('''
  static void __$methodName(GDExtensionClassInstancePtr instance,
    Pointer<GDExtensionConstTypePtr> args, GDExtensionTypePtr retPtr) {
    
    final self = gde.dartBindings.fromPersistentHandle(instance) as ${classInfo.dartType};
''');
      arguments.forEachIndexed((i, e) {
        out.write(convertPtrArgument(i, e));
      });
      out.write('''
    ${hasReturn ? 'final ret = ' : ''}self.$dartMethodName(${arguments.map((e) => e.name).join(',')});
''');
      if (hasReturn) {
        out.write(writePtrReturn(returnInfo));
      }

      out.write('''
  }

''');
    }

    out.write('''
}

''');

    // Class Enums
    List<dynamic> enums = classInfo.api['enums'] ?? <dynamic>[];
    for (Map<String, dynamic> classEnum in enums) {
      writeEnum(classEnum, classInfo.godotType, out);
    }

    out.write('''
class _${classInfo.godotType}Bindings {\n''');

    for (Map<String, dynamic> method in methods) {
      if (method['is_virtual'] as bool) {
        continue;
      }

      var methodName = escapeMethodName(method['name'] as String);
      methodName = methodName.toUpperCamelCase();
      out.write('''  GDExtensionMethodBindPtr? method$methodName;\n''');
    }
    out.write('}\n');

    await out.close();

    exportsString += "export '${classInfo.godotType.toSnakeCase()}.dart';\n";
  }

  var exportsFile = File(path.join(targetDir, 'engine_classes.dart'));
  var out = exportsFile.openWrite();
  out.write(header);
  out.write(exportsString);

  await out.close();
}
