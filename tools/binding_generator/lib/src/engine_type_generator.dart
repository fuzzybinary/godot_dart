import 'dart:io';

import 'package:path/path.dart' as path;

import 'common_helpers.dart';
import 'string_extensions.dart';
import 'type_helpers.dart';

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

  for (Map<String, dynamic> classApi in api.engineClasses.values) {
    String className = classApi['name'];
    // This is unlikely for classes but, better safe than sorty
    String correctedName = getCorrectedType(className);
    if (hasDartType(className)) {
      continue;
    }

    final destPath = path.join(targetDir, '${className.toSnakeCase()}.dart');
    final out = File(destPath).openWrite();

    out.write(header);

    writeImports(out, api, classApi, false);

    final inherits = (classApi['inherits'] as String?) ?? 'ExtensionType';
    final correctedInherits = getCorrectedType(inherits);

    out.write('''

class $correctedName extends $correctedInherits {
  static TypeInfo? _typeInfo;
  static final _bindings = _${className}Bindings();

  static TypeInfo get typeInfo {
    _typeInfo ??= TypeInfo(
      StringName.fromString('$className'),
      parentClass: StringName.fromString('$inherits'),
      bindingCallbacks: bindingCallbacks,
    );
    return _typeInfo!;
  }
  @override
  TypeInfo get staticTypeInfo => typeInfo;
''');

    // Singleton
    if (api.singletons.contains(className)) {
      out.write('''
  
  static GDExtensionObjectPtr? _singletonPtr;
  static $correctedName? _singletonObj;
  
  static $correctedName get singleton {
    if (_singletonPtr == null) {
      _singletonPtr = gde.globalGetSingleton(typeInfo.className);
      _singletonObj = gde.dartBindings.gdObjectToDartObject(
          _singletonPtr!.cast(), bindingCallbacks) as $correctedName;
    }
    return _singletonObj!;
  }
''');
    }

    // Constructors
    out.write('''
  $correctedName() : super.forType(typeInfo.className);
  
  $correctedName.forType(StringName type) : super.forType(type);
  $correctedName.fromOwner(Pointer<Void> owner) : super.fromOwner(owner);

''');

    List<dynamic> methods = classApi['methods'] ?? <Map<String, dynamic>>[];
    // TODO: Virtual methods
    methods = methods
        .where((dynamic method) => !(method['is_virtual'] as bool))
        .toList();

    for (Map<String, dynamic> method in methods) {
      final methodName = escapeMethodName(method['name'] as String);
      final hasReturn = method.containsKey('return_value') &&
          method['return_value']!['type'] != 'void';
      final isStatic = method['is_static'] as bool;
      final signature = makeSignature(method);

      out.write('''
  $signature {
''');

      List<dynamic> arguments = method['arguments'] ?? <Map<String, dynamic>>[];

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
      for (Map<String, dynamic> argument in arguments) {
        final name = escapeName(argument['name'] as String);
        out.write('      convertToVariant(${name.toLowerCamelCase()}),\n');
      }

      out.write('''
    ]);
''');

      if (hasReturn) {
        final dartReturnType = getDartReturnType(method);
        var bindingCallbacks = 'null';
        if (api.engineClasses.containsKey(dartReturnType)) {
          bindingCallbacks = '$dartReturnType.bindingCallbacks';
        }

        out.write(
            '    return convertFromVariant(ret, $bindingCallbacks) as $dartReturnType;\n');
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
    final dartInstance = $correctedName.fromOwner(instance);
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
''');

    out.write('''
  }
}

''');

    // Class Enums
    List<dynamic> enums = classApi['enums'] ?? <dynamic>[];
    for (Map<String, dynamic> classEnum in enums) {
      writeEnum(classEnum, className, out);
    }

    out.write('''
class _${className}Bindings {\n''');

    for (Map<String, dynamic> method in methods) {
      var methodName = escapeMethodName(method['name'] as String);
      methodName = methodName.toUpperCamelCase();
      out.write('''  GDExtensionMethodBindPtr? method$methodName;\n''');
    }
    out.write('}\n');

    await out.close();

    exportsString += "export '${className.toSnakeCase()}.dart';\n";
  }

  var exportsFile = File(path.join(targetDir, 'engine_classes.dart'));
  var out = exportsFile.openWrite();
  out.write(header);
  out.write(exportsString);

  await out.close();
}
