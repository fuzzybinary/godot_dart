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
  List<String> getGlobalClassPaths() {
    // Native code is expecting a list
    return _globalClassPaths.toList();
  }

  @pragma('vm:entry-point')
  TypeInfo? getTypeInfoByName(String typeName) {
    final ret = _stringTypeInfoLookup[typeName];
    return ret;
  }

  @pragma('vm:entry-point')
  TypeInfo? getTypeInfoByType(Type type) {
    var info = _typeTypeInfoLookup[type];
    if (info != null) return info;
    // Not found, try the a primitive type
    info = PrimitiveTypeInfo.forType(type);
    if (info == null) {
      print('Could not find type info for $type!');
    }
    return info;
  }

  void clearScripts() {
    _scriptFileTypeMap.clear();
    _scriptTypeFileMap.clear();
    _globalClassPaths.clear();
  }

  void addScriptType(
      String path, Type scriptType, ExtensionTypeInfo<dynamic> typeInfo) {
    assert(!_scriptFileTypeMap.containsKey(path));
    assert(!_scriptTypeFileMap.containsKey(scriptType));
    _scriptFileTypeMap[path] = scriptType;
    _scriptTypeFileMap[scriptType] = path;
    _typeTypeInfoLookup[scriptType] = typeInfo;
    if (typeInfo.isGlobalClass) {
      _globalClassPaths.add(path);
    }
  }

  void addType(TypeInfo typeInfo) {
    final String dartName = typeInfo.className.toDartString();
    assert(!_stringTypeInfoLookup.containsKey(dartName));
    _stringTypeInfoLookup[dartName] = typeInfo;
    _typeTypeInfoLookup[typeInfo.type] = typeInfo;
  }

  void addGodotBuiltins() {
    addType(Variant.sTypeInfo);
    addType(GDString.sTypeInfo);
    addType(StringName.sTypeInfo);
    addType(GDArray.sTypeInfo);
    addType(Vector2.sTypeInfo);
    addType(Vector2i.sTypeInfo);
    addType(Rect2.sTypeInfo);
    addType(Rect2i.sTypeInfo);
    addType(Vector3.sTypeInfo);
    addType(Vector3i.sTypeInfo);
    addType(Transform2D.sTypeInfo);
    addType(Vector4.sTypeInfo);
    addType(Vector4i.sTypeInfo);
    addType(Plane.sTypeInfo);
    addType(Quaternion.sTypeInfo);
    addType(AABB.sTypeInfo);
    addType(Basis.sTypeInfo);
    addType(Transform3D.sTypeInfo);
    addType(Projection.sTypeInfo);
    addType(Color.sTypeInfo);
    addType(NodePath.sTypeInfo);
    addType(RID.sTypeInfo);
    addType(Callable.sTypeInfo);
    addType(Signal.sTypeInfo);
    addType(Dictionary.sTypeInfo);
    addType(PackedByteArray.sTypeInfo);
    addType(PackedInt32Array.sTypeInfo);
    addType(PackedInt64Array.sTypeInfo);
    addType(PackedFloat32Array.sTypeInfo);
    addType(PackedFloat64Array.sTypeInfo);
    addType(PackedStringArray.sTypeInfo);
    addType(PackedVector2Array.sTypeInfo);
    addType(PackedVector3Array.sTypeInfo);
    addType(PackedVector4Array.sTypeInfo);
    addType(PackedColorArray.sTypeInfo);
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

    final object = methodInfo.call(target, args);
    if (methodInfo.returnInfo case final returnInfo?) {
      final retPtr = Pointer<Void>.fromAddress(retAddress);

      final typeInfo = getTypeInfoByType(returnInfo.type)!;
      _dartToPtr(object, retPtr, typeInfo);
    }
  }

  @pragma('vm:entry-point')
  void invokeMethodVariantCall(Object target, MethodInfo<dynamic> methodInfo,
      int argsPtr, int argsCount, int variantReturnAddresss) {
    assert(methodInfo.args.length == argsCount);
    final Pointer<Pointer<Void>> variantsPtr =
        Pointer<Pointer<Void>>.fromAddress(argsPtr);

    var dartArgs = <Object?>[];
    for (int i = 0; i < argsCount; ++i) {
      var variantPtr = (variantsPtr + i).value;
      final argInfo = methodInfo.args[i];
      dartArgs.add(variantPtrToDart(variantPtr, argInfo.type));
    }
    if (methodInfo.returnInfo == null) {
      methodInfo.call(target, dartArgs);
    } else {
      final object = methodInfo.call(target, dartArgs);
      final retPtr = Pointer<Void>.fromAddress(variantReturnAddresss);
      final retVariant = Variant(object);
      retVariant.constructCopy(retPtr);
    }
  }

  @pragma('vm:entry-point')
  MethodInfo<dynamic>? findVirtualFunction(
      ExtensionTypeInfo<dynamic> typeInfo, String name) {
    MethodInfo<dynamic>? foundMethod;
    ExtensionTypeInfo<dynamic>? checkTypeInfo = typeInfo;
    while (checkTypeInfo != null) {
      final method =
          checkTypeInfo.methods.firstWhereOrNull((m) => m.name == name);
      if (method != null) {
        foundMethod = method;
        break;
      }

      checkTypeInfo = checkTypeInfo.parentTypeInfo;
    }

    return foundMethod;
  }

  Object? _ptrToDart(Pointer<Void> ptrArg, PropertyInfo argInfo) {
    if (ptrArg == nullptr) return null;

    final typeInfo = getTypeInfoByType(argInfo.type)!;
    switch (typeInfo) {
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
