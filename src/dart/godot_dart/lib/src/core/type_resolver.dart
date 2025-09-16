import 'dart:ffi';

import 'package:collection/collection.dart';

import '../gen/builtins.dart';
import '../gen/classes/graph_edit.dart';
import '../variant/variant.dart';
import 'core.dart';

/// Created by the godot_dart bindings generator to map
/// godot script paths to types and visa versa
class TypeResolver {
  final Map<Type, String> _scriptTypeFileMap = {};
  final Map<String, Type> _scriptFileTypeMap = {};
  final Set<String> _globalClassPaths = {};

  final Map<String, TypeInfo> _stringTypeInfoLookup = {};
  final Map<Type, TypeInfo> _typeTypeInfoLookup = {};

  @pragma('vm:entry-point')
  String? scriptPathFromType(Type type) {
    return _scriptTypeFileMap[type];
  }

  @pragma('vm:entry-point')
  Type? scriptTypeFromPath(String path) {
    return _scriptFileTypeMap[path];
  }

  @pragma('vm:entry-point')
  Set<String> getGlobalClassPaths() {
    return _globalClassPaths;
  }

  @pragma('vm:entry-point')
  TypeInfo? getTypeInfoByName(String typeName) {
    return _stringTypeInfoLookup[typeName];
  }

  @pragma('vm:entry-point')
  TypeInfo? getTypeInfoByType(Type type) {
    return _typeTypeInfoLookup[type];
  }

  void addScriptType(String path, Type scriptType, bool isGlobal) {
    assert(!_scriptFileTypeMap.containsKey(path));
    assert(!_scriptTypeFileMap.containsKey(scriptType));
    _scriptFileTypeMap[path] = scriptType;
    _scriptTypeFileMap[scriptType] = path;
    if (isGlobal) {
      _globalClassPaths.add(path);
    }
  }

  void addType(TypeInfo typeInfo) {
    final String dartName = typeInfo.className.toDartString();
    assert(!_stringTypeInfoLookup.containsKey(dartName));
    _stringTypeInfoLookup[dartName] = typeInfo;
    _typeTypeInfoLookup[typeInfo.type] = typeInfo;
  }

  @pragma('vm:entry-point')
  Object? constructFromGodotObject(Type type, int ptr) {
    final typeInfo = getTypeInfoByType(type);
    if (typeInfo is ExtensionTypeInfo) {
      return typeInfo.constructFromGodotObject(Pointer.fromAddress(ptr));
    }
    return null;
  }

  @pragma('vm:entry-point')
  Object? constructObjectDefault(String typeName) {
    final typeInfo = getTypeInfoByName(typeName);
    if (typeInfo is BuiltinTypeInfo) {
      return typeInfo.constructObjectDefault();
    }
    if (typeInfo is ExtensionTypeInfo) {
      return typeInfo.constructObjectDefault();
    }
    return null;
  }

  @pragma('vm:entry-point')
  Object? constructObjectCopy(String typeName, int ptr) {
    final typeInfo = getTypeInfoByName(typeName);
    if (typeInfo is BuiltinTypeInfo) {
      return typeInfo.constructCopy(GDExtensionConstObjectPtr.fromAddress(ptr));
    }
    return null;
  }

  // TODO: Not sure if method invokation should go in type resolver or not
  @pragma('vm:entry-point')
  void invokeMethodPtrCall(Object target, MethodInfo<dynamic> methodInfo,
      int argsAddress, int retAddress) {
    final Pointer<Pointer<Void>> ptrCallArgs =
        Pointer<Pointer<Void>>.fromAddress(argsAddress);
    final args = methodInfo.args.mapIndexed((i, argInfo) {
      return _ptrToDart((ptrCallArgs + i).value, argInfo);
    }).toList();

    final object = methodInfo.dartMethodCall(target, args);
    if (methodInfo.returnInfo case final returnInfo?) {
      final retPtr = Pointer<Void>.fromAddress(retAddress);

      _dartToPtr(object, retPtr, returnInfo.typeInfo);
    }
  }

  @pragma('vm:entry-point')
  Object? invokeMethodVariantCall(Object target, MethodInfo<dynamic> methodInfo,
      int argsPtr, int argsCount) {
    assert(methodInfo.args.length == argsCount);
    final Pointer<Pointer<Void>> variantsPtr =
        Pointer<Pointer<Void>>.fromAddress(argsPtr);

    var dartArgs = <Object?>[];
    for (int i = 0; i < argsCount; ++i) {
      var variantPtr = (variantsPtr + i).value;
      final argInfo = methodInfo.args[i];
      dartArgs.add(variantPtrToDart(variantPtr, argInfo.typeInfo));
    }

    return methodInfo.dartMethodCall(target, dartArgs);
  }

  Object? _ptrToDart(Pointer<Void> ptrArg, PropertyInfo argInfo) {
    if (ptrArg == nullptr) return null;

    switch (argInfo.typeInfo) {
      case final PrimitiveTypeInfo<dynamic> info:
        return info.fromPointer(ptrArg);
      case final BuiltinTypeInfo<dynamic> info:
        // Strings and Variant are special
        if (info.type == GDString) {
          return GDString.copyPtr(ptrArg).toDartString();
        } else if (info.type == StringName) {
          return StringName.copyPtr(ptrArg).toDartString();
        } else if (info.type == Variant) {
          return Variant.fromVariantPtr(ptrArg);
        }
        // Everything else can use constructCopy
        return info.constructCopy(ptrArg);
      case final ExtensionTypeInfo<dynamic> info:
        if (info.isRefCounted) {
          return gde.ffiBindings.gde_ref_get_object(ptrArg).toDart();
        }
        return ptrArg.cast<GDExtensionObjectPtr>().value.toDart();
      case final NativeStructureTypeInfo<dynamic> info:
        return info.fromPointer(ptrArg);
    }
    throw InvalidPrimitiveCastException(argInfo.name);
  }

  void _dartToPtr(Object? object, Pointer<Void> retPtr, TypeInfo retInfo) {
    switch (retInfo) {
      case final PrimitiveTypeInfo<dynamic> info:
        info.toPointer(object, retPtr);
        break;
      case final BuiltinTypeInfo<dynamic> info:
        // Strings and Variant are special
        if (info.type == GDString) {
          final gdString = GDString.fromString(object as String);
          gdString.constructCopy(retPtr);
        } else if (info.type == StringName) {
          final stringName = StringName.fromString(object as String);
          stringName.constructCopy(retPtr);
        } else if (info.type == Variant) {
          final variant = object as Variant;
          variant.constructCopy(retPtr);
        } else {
          final builtin = object as BuiltinType;
          builtin.constructCopy(retPtr);
        }
        break;
      case final ExtensionTypeInfo<dynamic> _:
        final extensionObject = object as ExtensionType?;
        retPtr.cast<GDExtensionTypePtr>().value =
            extensionObject?.nativePtr ?? nullptr;
        break;
      case final NativeStructureTypeInfo<dynamic> info:
        info.toPointer(object, retPtr);
        break;
    }
  }
}

class InvalidPrimitiveCastException implements Exception {
  final String argName;

  InvalidPrimitiveCastException(this.argName);
}
