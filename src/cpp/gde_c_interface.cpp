#include "gde_c_interface.h"

extern "C" {

static GDExtensionInterfaceGetLibraryPath _get_library_path_func = nullptr;
void gde_get_library_path(GDExtensionClassLibraryPtr p_library, GDExtensionUninitializedStringPtr r_path) {
  if (_get_library_path_func) {
    _get_library_path_func(p_library, r_path);
  }
}

static GDExtensionInterfacePrintError _print_error_func = nullptr;
void gde_print_error(const char *p_description, const char *p_function, const char *p_file, int32_t p_line,
                     GDExtensionBool p_editor_notify) {
  if (_print_error_func) {
    _print_error_func(p_description, p_function, p_file, p_line, p_editor_notify);
  }
}

static GDExtensionInterfacePrintWarning _print_warning_func = nullptr;
void gde_print_warning(const char *p_description, const char *p_function, const char *p_file, int32_t p_line,
                       GDExtensionBool p_editor_notify) {
  if (_print_warning_func) {
    _print_warning_func(p_description, p_function, p_file, p_line, p_editor_notify);
  }
}

static GDExtensionInterfaceMemAlloc _mem_alloc_func = nullptr;
void *gde_mem_alloc(size_t p_bytes) {
  if (_mem_alloc_func) {
    return _mem_alloc_func(p_bytes);
  }
  return nullptr;
}

static GDExtensionInterfaceMemFree _mem_free_func = nullptr;
void gde_mem_free(void* p_mem) {
  if (_mem_free_func) {
    _mem_free_func(p_mem);
  }  
}

static GDExtensionInterfaceVariantDestroy _variant_destroy_func = nullptr;
void gde_variant_destroy(GDExtensionVariantPtr p_self) {
  if (_variant_destroy_func) {
    return _variant_destroy_func(p_self);
  }
}

static GDExtensionInterfaceVariantGetPtrConstructor _variant_get_ptr_constructor_func = nullptr;
GDExtensionPtrConstructor gde_variant_get_ptr_constructor(GDExtensionVariantType p_type, int32_t p_constructor) {
  if (_variant_get_ptr_constructor_func) {
    return _variant_get_ptr_constructor_func(p_type, p_constructor);
  }
  return nullptr;
}

static GDExtensionInterfaceVariantGetPtrDestructor _variant_get_ptr_destructor_func = nullptr;
GDExtensionPtrDestructor gde_variant_get_ptr_destructor(GDExtensionVariantType p_type) {
  if (_variant_get_ptr_destructor_func) {
    return _variant_get_ptr_destructor_func(p_type);
  }
  return nullptr;
}

static GDExtensionInterfaceVariantNewCopy _variant_new_copy_func = nullptr;
void gde_variant_new_copy(GDExtensionUninitializedVariantPtr r_dest, GDExtensionConstVariantPtr p_src) {
  if (_variant_new_copy_func) {
    _variant_new_copy_func(r_dest, p_src);
  }
}

static GDExtensionInterfaceVariantNewNil _variant_new_nil_func = nullptr;
void gde_variant_new_nil(GDExtensionUninitializedVariantPtr r_dest) {
  if (_variant_new_nil_func) {
    _variant_new_nil_func(r_dest);
  }
}

static GDExtensionInterfaceVariantGetPtrBuiltinMethod _variant_get_ptr_builtin_method_func = nullptr;
GDExtensionPtrBuiltInMethod gde_variant_get_ptr_builtin_method(GDExtensionVariantType p_type,
                                                               GDExtensionConstStringNamePtr p_method,
                                                               GDExtensionInt p_hash) {
  if (_variant_get_ptr_builtin_method_func) {
    return _variant_get_ptr_builtin_method_func(p_type, p_method, p_hash);
  }
  return nullptr;
}

static GDExtensionInterfaceGetVariantFromTypeConstructor _get_variant_from_type_constructor_func = nullptr;
GDExtensionVariantFromTypeConstructorFunc gde_get_variant_from_type_constructor(GDExtensionVariantType p_type) {
  if (_get_variant_from_type_constructor_func) {
    return _get_variant_from_type_constructor_func(p_type);
  }
  return nullptr;
}

static GDExtensionInterfaceGetVariantToTypeConstructor _get_variant_to_type_constructor_func = nullptr;
GDExtensionTypeFromVariantConstructorFunc gde_get_variant_to_type_constructor(GDExtensionVariantType p_type) {
  if (_get_variant_to_type_constructor_func) {
    return _get_variant_to_type_constructor_func(p_type);
  }
  return nullptr;
}

static GDExtensionInterfaceVariantGetType _variant_get_type_func = nullptr;
GDExtensionVariantType gde_variant_get_type(GDExtensionConstVariantPtr p_self) {
  if (_variant_get_type_func) {
    return _variant_get_type_func(p_self);
  }
  return GDExtensionVariantType();
}

static GDExtensionInterfaceVariantCall _variant_call_func = nullptr;
void gde_variant_call(GDExtensionVariantPtr p_self, GDExtensionConstStringNamePtr p_method,
                      const GDExtensionConstVariantPtr *p_args, GDExtensionInt p_argument_count,
                      GDExtensionUninitializedVariantPtr r_return, GDExtensionCallError *r_error) {
  if (_variant_call_func) {
    _variant_call_func(p_self, p_method, p_args, p_argument_count, r_return, r_error);
  }
}

static GDExtensionInterfaceVariantGetPtrGetter _variant_get_ptr_getter_func = nullptr;
GDExtensionPtrGetter gde_variant_get_ptr_getter(GDExtensionVariantType p_type, GDExtensionConstStringNamePtr p_member) {
  if (_variant_get_ptr_getter_func) {
    return _variant_get_ptr_getter_func(p_type, p_member);
  }
  return nullptr;
}

static GDExtensionInterfaceVariantGetPtrSetter _variant_get_ptr_setter_func = nullptr;
GDExtensionPtrSetter gde_variant_get_ptr_setter(GDExtensionVariantType p_type, GDExtensionConstStringNamePtr p_member) {
  if (_variant_get_ptr_setter_func) {
    return _variant_get_ptr_setter_func(p_type, p_member);
  }
  return nullptr;
}

static GDExtensionInterfaceVariantGetPtrIndexedGetter _variant_get_ptr_indexed_getter_func = nullptr;
GDExtensionPtrIndexedGetter gde_variant_get_ptr_indexed_getter(GDExtensionVariantType p_type) {
  if (_variant_get_ptr_indexed_getter_func) {
    return _variant_get_ptr_indexed_getter_func(p_type);
  }
  return nullptr;
}

static GDExtensionInterfaceVariantGetPtrIndexedSetter _variant_get_ptr_indexed_setter_func = nullptr;
GDExtensionPtrIndexedSetter gde_variant_get_ptr_indexed_setter(GDExtensionVariantType p_type) {
  if (_variant_get_ptr_indexed_setter_func) {
    return _variant_get_ptr_indexed_setter_func(p_type);
  }
  return nullptr;
}

static GDExtensionInterfaceVariantGetPtrKeyedGetter _variant_get_ptr_keyed_getter_func = nullptr;
GDExtensionPtrKeyedGetter gde_variant_get_ptr_keyed_getter(GDExtensionVariantType p_type) {
  if (_variant_get_ptr_keyed_getter_func) {
    return _variant_get_ptr_keyed_getter_func(p_type);
  }
  return nullptr;
}

static GDExtensionInterfaceVariantGetPtrKeyedSetter _variant_get_ptr_keyed_setter_func = nullptr;
GDExtensionPtrKeyedSetter gde_variant_get_ptr_keyed_setter(GDExtensionVariantType p_type) {
  if (_variant_get_ptr_keyed_setter_func) {
    return _variant_get_ptr_keyed_setter_func(p_type);
  }
  return nullptr;
}

static GDExtensionInterfaceVariantGetPtrKeyedChecker _variant_get_ptr_keyed_checker_func = nullptr;
GDExtensionPtrKeyedChecker gde_variant_get_ptr_keyed_checker(GDExtensionVariantType p_type) {
  if (_variant_get_ptr_keyed_checker_func) {
    return _variant_get_ptr_keyed_checker_func(p_type);
  }
  return nullptr;
}

static GDExtensionInterfaceVariantGetIndexed _variant_get_indexed_func = nullptr;
void gde_variant_get_indexed(GDExtensionConstVariantPtr p_self, GDExtensionInt p_index,
                             GDExtensionUninitializedVariantPtr r_ret, GDExtensionBool *r_valid,
                             GDExtensionBool *r_oob) {
  if (_variant_get_indexed_func) {
    _variant_get_indexed_func(p_self, p_index, r_ret, r_valid, r_oob);
  }
}

static GDExtensionInterfaceVariantSetIndexed _variant_set_indexed_func = nullptr;
void gde_variant_set_indexed(GDExtensionVariantPtr p_self, GDExtensionInt p_index, GDExtensionConstVariantPtr p_value,
                             GDExtensionBool *r_valid, GDExtensionBool *r_oob) {
  if (_variant_set_indexed_func) {
    _variant_set_indexed_func(p_self, p_index, p_value, r_valid, r_oob);
  }
}

static GDExtensionInterfaceVariantGetPtrUtilityFunction _variant_get_ptr_utility_function_func = nullptr;
GDExtensionPtrUtilityFunction gde_variant_get_ptr_utility_function(GDExtensionConstStringNamePtr p_function,
                                                                   GDExtensionInt p_hash) {
  if (gde_variant_get_ptr_utility_function) {
    return _variant_get_ptr_utility_function_func(p_function, p_hash);
  }
  return nullptr;
}

static GDExtensionInterfaceStringNewWithUtf8Chars _string_new_with_utf8_chars_func = nullptr;
void gde_string_new_with_utf8_chars(GDExtensionUninitializedStringPtr r_dest, const char *p_contents) {
  if (_string_new_with_utf8_chars_func) {
    _string_new_with_utf8_chars_func(r_dest, p_contents);
  }
}

static GDExtensionInterfaceStringToUtf8Chars _string_to_utf8_chars_func = nullptr;
GDExtensionInt gde_string_to_utf8_chars(GDExtensionConstStringPtr p_self, char *r_text,
                                        GDExtensionInt p_max_write_length) {
  if (_string_to_utf8_chars_func) {
    return _string_to_utf8_chars_func(p_self, r_text, p_max_write_length);
  }
  return 0;
}

static GDExtensionInterfaceStringToUtf16Chars _string_to_utf16_chars_func = nullptr;
GDExtensionInt gde_string_to_utf16_chars(GDExtensionConstStringPtr p_self, char16_t *r_text,
                                         GDExtensionInt p_max_write_length) {
  if (_string_to_utf16_chars_func) {
    return _string_to_utf16_chars_func(p_self, r_text, p_max_write_length);
  }
  return 0;
}

static GDExtensionInterfaceGlobalGetSingleton _global_get_singleton_func = nullptr;
GDExtensionObjectPtr gde_global_get_singleton(GDExtensionConstStringNamePtr p_name) {
  if (_global_get_singleton_func) {
    return _global_get_singleton_func(p_name);
  }
  return nullptr;
}

static GDExtensionInterfaceClassdbGetClassTag _classdb_get_class_tag_func = nullptr;
void *gde_classdb_get_class_tag(GDExtensionConstStringNamePtr p_classname) {
  if (_classdb_get_class_tag_func) {
    return _classdb_get_class_tag_func(p_classname);
  }
  return nullptr;
}

static GDExtensionInterfaceClassdbRegisterExtensionClass2 _classdb_register_extension_class2_func = nullptr;
void gde_classdb_register_extension_class2(GDExtensionClassLibraryPtr p_library,
                                           GDExtensionConstStringNamePtr p_class_name,
                                           GDExtensionConstStringNamePtr p_parent_class_name,
                                           const GDExtensionClassCreationInfo2 *p_extension_funcs) {
  if (_classdb_register_extension_class2_func) {
    _classdb_register_extension_class2_func(p_library, p_class_name, p_parent_class_name, p_extension_funcs);
  }
}

static GDExtensionInterfaceClassdbRegisterExtensionClassMethod _classdb_register_extension_class_method_func = nullptr;
void gde_classdb_register_extension_class_method(GDExtensionClassLibraryPtr p_library,
                                                 GDExtensionConstStringNamePtr p_class_name,
                                                 const GDExtensionClassMethodInfo *p_method_info) {
  if (_classdb_register_extension_class_method_func) {
    _classdb_register_extension_class_method_func(p_library, p_class_name, p_method_info);
  }
}

static GDExtensionInterfaceClassdbRegisterExtensionClassProperty _classdb_register_extension_class_property_func =
    nullptr;
void gde_classdb_register_extension_class_property(GDExtensionClassLibraryPtr p_library,
                                                   GDExtensionConstStringNamePtr p_class_name,
                                                   const GDExtensionPropertyInfo *p_info,
                                                   GDExtensionConstStringNamePtr p_setter,
                                                   GDExtensionConstStringNamePtr p_getter) {
  if (_classdb_register_extension_class_property_func) {
    _classdb_register_extension_class_property_func(p_library, p_class_name, p_info, p_setter, p_getter);
  }
}

static GDExtensionInterfaceClassdbGetMethodBind _classdb_get_method_bind_func = nullptr;
GDExtensionMethodBindPtr gde_classdb_get_method_bind(GDExtensionConstStringNamePtr p_classname,
                                                     GDExtensionConstStringNamePtr p_methodname,
                                                     GDExtensionInt p_hash) {
  if (_classdb_get_method_bind_func) {
    return _classdb_get_method_bind_func(p_classname, p_methodname, p_hash);
  }
  return nullptr;
}

static GDExtensionInterfaceClassdbConstructObject _classdb_construct_object_func = nullptr;
GDExtensionObjectPtr gde_classdb_construct_object(GDExtensionConstStringNamePtr p_classname) {
  if (_classdb_construct_object_func) {
    return _classdb_construct_object_func(p_classname);
  }
  return nullptr;
}

static GDExtensionInterfaceObjectMethodBindCall _object_method_bind_call_func = nullptr;
void gde_object_method_bind_call(GDExtensionMethodBindPtr p_method_bind, GDExtensionObjectPtr p_instance,
                                 const GDExtensionConstVariantPtr *p_args, GDExtensionInt p_arg_count,
                                 GDExtensionUninitializedVariantPtr r_ret, GDExtensionCallError *r_error) {
  if (_object_method_bind_call_func) {
    _object_method_bind_call_func(p_method_bind, p_instance, p_args, p_arg_count, r_ret, r_error);
  }
}

static GDExtensionInterfaceObjectMethodBindPtrcall _object_method_bind_ptrcall_func = nullptr;
void gde_object_method_bind_ptrcall(GDExtensionMethodBindPtr p_method_bind, GDExtensionObjectPtr p_instance,
                                    const GDExtensionConstTypePtr *p_args, GDExtensionTypePtr r_ret) {
  if (_object_method_bind_ptrcall_func) {
    _object_method_bind_ptrcall_func(p_method_bind, p_instance, p_args, r_ret);
  }
}

static GDExtensionInterfaceObjectGetInstanceBinding _object_get_instance_binding_func = nullptr;
void *gde_object_get_instance_binding(GDExtensionObjectPtr p_o, void *p_token,
                                      const GDExtensionInstanceBindingCallbacks *p_callbacks) {
  if (_object_get_instance_binding_func) {
    return _object_get_instance_binding_func(p_o, p_token, p_callbacks);
  }
  return nullptr;
}

static GDExtensionInterfaceObjectSetInstanceBinding _object_set_instance_binding_func = nullptr;
void gde_object_set_instance_binding(GDExtensionObjectPtr p_o, void *p_token, void *p_binding,
                                     const GDExtensionInstanceBindingCallbacks *p_callbacks) {
  if (_object_set_instance_binding_func) {
    _object_set_instance_binding_func(p_o, p_token, p_binding, p_callbacks);
  }
}

static GDExtensionInterfaceObjectSetInstance _object_set_instance_func = nullptr;
void gde_object_set_instance(GDExtensionObjectPtr p_o, GDExtensionConstStringNamePtr p_classname,
                             GDExtensionClassInstancePtr p_instance) {
  if (_object_set_instance_func) {
    _object_set_instance_func(p_o, p_classname, p_instance);
  }
}

static GDExtensionInterfaceObjectCastTo _object_cast_to_func = nullptr;
GDExtensionObjectPtr gde_object_cast_to(GDExtensionConstObjectPtr p_object, void *p_class_tag) {
  if (_object_cast_to_func) {
    return _object_cast_to_func(p_object, p_class_tag);
  }
  return nullptr;
}

static GDExtensionInterfaceObjectDestroy _object_destroy_func = nullptr;
void gde_object_destroy(GDExtensionObjectPtr p_o) {
  if (_object_destroy_func) {
    _object_destroy_func(p_o);
  }
}

static GDExtensionInterfaceRefGetObject _ref_get_object_func = nullptr;
GDExtensionObjectPtr gde_ref_get_object(GDExtensionConstRefPtr p_ref) {
  if (_ref_get_object_func) {
    return _ref_get_object_func(p_ref);
  }
  return nullptr;
}

static GDExtensionInterfaceRefSetObject _ref_set_object_func = nullptr;
void gde_ref_set_object(GDExtensionRefPtr p_ref, GDExtensionObjectPtr p_object) {
  if (_ref_set_object_func) {
    _ref_set_object_func(p_ref, p_object);
  }
}

static GDExtensionInterfaceScriptInstanceCreate2 _script_instance_create2_func = nullptr;
GDExtensionScriptInstancePtr gde_script_instance_create2(const GDExtensionScriptInstanceInfo2 *p_info,
                                                        GDExtensionScriptInstanceDataPtr p_instance_data) {
  if (_script_instance_create2_func) {
    return _script_instance_create2_func(p_info, p_instance_data);
  }
  return nullptr;
}

static GDExtensionInterfaceObjectGetScriptInstance _object_get_script_instance_func = nullptr;
GDExtensionScriptInstanceDataPtr gde_object_get_script_instance(GDExtensionConstObjectPtr p_object,
                                                                GDExtensionObjectPtr p_language) {
  if (_object_get_script_instance_func) {
    return _object_get_script_instance_func(p_object, p_language);
  }
  return nullptr;
}

#define LOAD_METHOD(method, type) _##method##_func = (type)get_proc_address(#method)

void gde_init_c_interface(GDExtensionInterfaceGetProcAddress get_proc_address) {
  LOAD_METHOD(get_library_path, GDExtensionInterfaceGetLibraryPath);
  LOAD_METHOD(print_error, GDExtensionInterfacePrintError);
  LOAD_METHOD(print_warning, GDExtensionInterfacePrintWarning);
  LOAD_METHOD(mem_alloc, GDExtensionInterfaceMemAlloc);
  LOAD_METHOD(mem_free, GDExtensionInterfaceMemFree);
  LOAD_METHOD(variant_destroy, GDExtensionInterfaceVariantDestroy);
  LOAD_METHOD(variant_get_ptr_constructor, GDExtensionInterfaceVariantGetPtrConstructor);
  LOAD_METHOD(variant_get_ptr_destructor, GDExtensionInterfaceVariantGetPtrDestructor);
  LOAD_METHOD(variant_new_copy, GDExtensionInterfaceVariantNewCopy);
  LOAD_METHOD(variant_new_nil, GDExtensionInterfaceVariantNewNil);
  LOAD_METHOD(variant_get_ptr_builtin_method, GDExtensionInterfaceVariantGetPtrBuiltinMethod);
  LOAD_METHOD(get_variant_from_type_constructor, GDExtensionInterfaceGetVariantFromTypeConstructor);
  LOAD_METHOD(get_variant_to_type_constructor, GDExtensionInterfaceGetVariantToTypeConstructor);
  LOAD_METHOD(variant_get_type, GDExtensionInterfaceVariantGetType);
  LOAD_METHOD(variant_call, GDExtensionInterfaceVariantCall);
  LOAD_METHOD(variant_get_ptr_getter, GDExtensionInterfaceVariantGetPtrGetter);
  LOAD_METHOD(variant_get_ptr_setter, GDExtensionInterfaceVariantGetPtrSetter);
  LOAD_METHOD(variant_get_ptr_indexed_getter, GDExtensionInterfaceVariantGetPtrIndexedGetter);
  LOAD_METHOD(variant_get_ptr_indexed_setter, GDExtensionInterfaceVariantGetPtrIndexedSetter);
  LOAD_METHOD(variant_get_ptr_keyed_setter, GDExtensionInterfaceVariantGetPtrKeyedSetter);
  LOAD_METHOD(variant_get_ptr_keyed_getter, GDExtensionInterfaceVariantGetPtrKeyedGetter);
  LOAD_METHOD(variant_get_ptr_keyed_checker, GDExtensionInterfaceVariantGetPtrKeyedChecker);
  LOAD_METHOD(variant_get_indexed, GDExtensionInterfaceVariantGetIndexed);
  LOAD_METHOD(variant_set_indexed, GDExtensionInterfaceVariantSetIndexed);
  LOAD_METHOD(variant_get_ptr_utility_function, GDExtensionInterfaceVariantGetPtrUtilityFunction);
  LOAD_METHOD(string_new_with_utf8_chars, GDExtensionInterfaceStringNewWithUtf8Chars);
  LOAD_METHOD(string_to_utf8_chars, GDExtensionInterfaceStringToUtf8Chars);
  LOAD_METHOD(string_to_utf16_chars, GDExtensionInterfaceStringToUtf16Chars);
  LOAD_METHOD(global_get_singleton, GDExtensionInterfaceGlobalGetSingleton);
  LOAD_METHOD(classdb_get_class_tag, GDExtensionInterfaceClassdbGetClassTag);
  LOAD_METHOD(classdb_register_extension_class2, GDExtensionInterfaceClassdbRegisterExtensionClass2);
  LOAD_METHOD(classdb_register_extension_class_method, GDExtensionInterfaceClassdbRegisterExtensionClassMethod);
  LOAD_METHOD(classdb_register_extension_class_property, GDExtensionInterfaceClassdbRegisterExtensionClassProperty);
  LOAD_METHOD(classdb_get_method_bind, GDExtensionInterfaceClassdbGetMethodBind);
  LOAD_METHOD(classdb_construct_object, GDExtensionInterfaceClassdbConstructObject);
  LOAD_METHOD(object_method_bind_call, GDExtensionInterfaceObjectMethodBindCall);
  LOAD_METHOD(object_method_bind_ptrcall, GDExtensionInterfaceObjectMethodBindPtrcall);
  LOAD_METHOD(object_get_instance_binding, GDExtensionInterfaceObjectGetInstanceBinding);
  LOAD_METHOD(object_set_instance_binding, GDExtensionInterfaceObjectSetInstanceBinding);
  LOAD_METHOD(object_set_instance, GDExtensionInterfaceObjectSetInstance);
  LOAD_METHOD(object_cast_to, GDExtensionInterfaceObjectCastTo);
  LOAD_METHOD(object_destroy, GDExtensionInterfaceObjectDestroy);
  LOAD_METHOD(ref_get_object, GDExtensionInterfaceRefGetObject);
  LOAD_METHOD(ref_set_object, GDExtensionInterfaceRefSetObject);
  LOAD_METHOD(script_instance_create2, GDExtensionInterfaceScriptInstanceCreate2);
  LOAD_METHOD(object_get_script_instance, GDExtensionInterfaceObjectGetScriptInstance);
}
}