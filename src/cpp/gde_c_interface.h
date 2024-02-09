#pragma once

/// This is a simplified file with a c-interface for all of the Godot Extension functions
/// that are used in the C++ portion of this extension and in the Dart portion. This makes
/// generation of the Dart FFI layer easier (and gives us a cleaner final interface).
///
/// The funcitons are populated with static pointers during extension initialzation.

#include <gdextension_interface.h>

#if !defined(GDE_EXPORT)
#if defined(_WIN32)
#define GDE_EXPORT __declspec(dllexport)
#elif defined(__GNUC__)
#define GDE_EXPORT __attribute__((visibility("default")))
#else
#define GDE_EXPORT
#endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

GDE_EXPORT void gde_init_c_interface(GDExtensionInterfaceGetProcAddress p_get_proc_address);

GDE_EXPORT void gde_get_library_path(GDExtensionClassLibraryPtr p_library, GDExtensionUninitializedStringPtr r_path);

GDE_EXPORT void gde_print_error(const char *p_description, const char *p_function, const char *p_file, int32_t p_line,
                                GDExtensionBool p_editor_notify);
GDE_EXPORT void gde_print_warning(const char *p_description, const char *p_function, const char *p_file, int32_t p_line,
                                  GDExtensionBool p_editor_notify);
GDE_EXPORT void *gde_mem_alloc(size_t p_bytes);
GDE_EXPORT void gde_mem_free(void* ptr);

GDE_EXPORT void gde_variant_destroy(GDExtensionVariantPtr p_self);
GDE_EXPORT GDExtensionPtrConstructor gde_variant_get_ptr_constructor(GDExtensionVariantType p_type,
                                                                     int32_t p_constructor);
GDE_EXPORT GDExtensionPtrDestructor gde_variant_get_ptr_destructor(GDExtensionVariantType p_type);
GDE_EXPORT void gde_variant_new_copy(GDExtensionUninitializedVariantPtr r_dest, GDExtensionConstVariantPtr p_src);
GDE_EXPORT void gde_variant_new_nil(GDExtensionUninitializedVariantPtr r_dest);
GDE_EXPORT GDExtensionPtrBuiltInMethod gde_variant_get_ptr_builtin_method(GDExtensionVariantType p_type,
                                                                          GDExtensionConstStringNamePtr p_method,
                                                                          GDExtensionInt p_hash);
GDE_EXPORT GDExtensionVariantFromTypeConstructorFunc
gde_get_variant_from_type_constructor(GDExtensionVariantType p_type);
GDE_EXPORT GDExtensionTypeFromVariantConstructorFunc gde_get_variant_to_type_constructor(GDExtensionVariantType p_type);
GDE_EXPORT GDExtensionVariantType gde_variant_get_type(GDExtensionConstVariantPtr p_self);
GDE_EXPORT void gde_variant_call(GDExtensionVariantPtr p_self, GDExtensionConstStringNamePtr p_method,
                                 const GDExtensionConstVariantPtr *p_args, GDExtensionInt p_argument_count,
                                 GDExtensionUninitializedVariantPtr r_return, GDExtensionCallError *r_error);
GDE_EXPORT GDExtensionPtrGetter gde_variant_get_ptr_getter(GDExtensionVariantType p_type,
                                                           GDExtensionConstStringNamePtr p_member);
GDE_EXPORT GDExtensionPtrSetter gde_variant_get_ptr_setter(GDExtensionVariantType p_type,
                                                           GDExtensionConstStringNamePtr p_member);
GDE_EXPORT GDExtensionPtrIndexedGetter gde_variant_get_ptr_indexed_getter(GDExtensionVariantType p_type);
GDE_EXPORT GDExtensionPtrIndexedSetter gde_variant_get_ptr_indexed_setter(GDExtensionVariantType p_type);
GDE_EXPORT GDExtensionPtrKeyedSetter gde_variant_get_ptr_keyed_setter(GDExtensionVariantType p_type);
GDE_EXPORT GDExtensionPtrKeyedGetter gde_variant_get_ptr_keyed_getter(GDExtensionVariantType p_type);
GDE_EXPORT GDExtensionPtrKeyedChecker gde_variant_get_ptr_keyed_checker(GDExtensionVariantType p_type);
GDE_EXPORT void gde_variant_get_indexed(GDExtensionConstVariantPtr p_self, GDExtensionInt p_index,
                                        GDExtensionUninitializedVariantPtr r_ret, GDExtensionBool *r_valid,
                                        GDExtensionBool *r_oob);
GDE_EXPORT void gde_variant_set_indexed(GDExtensionVariantPtr p_self, GDExtensionInt p_index,
                                        GDExtensionConstVariantPtr p_value, GDExtensionBool *r_valid,
                                        GDExtensionBool *r_oob);

GDE_EXPORT void gde_string_new_with_utf8_chars(GDExtensionUninitializedStringPtr r_dest, const char *p_contents);
GDE_EXPORT GDExtensionInt gde_string_to_utf8_chars(GDExtensionConstStringPtr p_self, char *r_text,
                                                   GDExtensionInt p_max_write_length);
GDE_EXPORT GDExtensionInt gde_string_to_utf16_chars(GDExtensionConstStringPtr p_self, char16_t *r_text,
                                                    GDExtensionInt p_max_write_length);

GDE_EXPORT GDExtensionObjectPtr gde_global_get_singleton(GDExtensionConstStringNamePtr p_name);

GDE_EXPORT void *gde_classdb_get_class_tag(GDExtensionConstStringNamePtr p_classname);
GDE_EXPORT void gde_classdb_register_extension_class2(GDExtensionClassLibraryPtr p_library,
                                                     GDExtensionConstStringNamePtr p_class_name,
                                                     GDExtensionConstStringNamePtr p_parent_class_name,
                                                     const GDExtensionClassCreationInfo2 *p_extension_funcs);
GDE_EXPORT void gde_classdb_register_extension_class_method(GDExtensionClassLibraryPtr p_library,
                                                            GDExtensionConstStringNamePtr p_class_name,
                                                            const GDExtensionClassMethodInfo *p_method_info);
GDE_EXPORT void gde_classdb_register_extension_class_property(GDExtensionClassLibraryPtr p_library,
                                                              GDExtensionConstStringNamePtr p_class_name,
                                                              const GDExtensionPropertyInfo *p_info,
                                                              GDExtensionConstStringNamePtr p_setter,
                                                              GDExtensionConstStringNamePtr p_getter);
GDE_EXPORT GDExtensionMethodBindPtr gde_classdb_get_method_bind(GDExtensionConstStringNamePtr p_classname,
                                                                GDExtensionConstStringNamePtr p_methodname,
                                                                GDExtensionInt p_hash);
GDE_EXPORT GDExtensionObjectPtr gde_classdb_construct_object(GDExtensionConstStringNamePtr p_classname);

GDE_EXPORT void gde_object_method_bind_call(GDExtensionMethodBindPtr p_method_bind, GDExtensionObjectPtr p_instance,
                                            const GDExtensionConstVariantPtr *p_args, GDExtensionInt p_arg_count,
                                            GDExtensionUninitializedVariantPtr r_ret, GDExtensionCallError *r_error);
GDE_EXPORT void gde_object_method_bind_ptrcall(GDExtensionMethodBindPtr p_method_bind, GDExtensionObjectPtr p_instance,
                                               const GDExtensionConstTypePtr *p_args, GDExtensionTypePtr r_ret);
GDE_EXPORT void *gde_object_get_instance_binding(GDExtensionObjectPtr p_o, void *p_token,
                                                 const GDExtensionInstanceBindingCallbacks *p_callbacks);
GDE_EXPORT void gde_object_set_instance_binding(GDExtensionObjectPtr p_o, void *p_token, void *p_binding,
                                                const GDExtensionInstanceBindingCallbacks *p_callbacks);
GDE_EXPORT void gde_object_set_instance(GDExtensionObjectPtr p_o, GDExtensionConstStringNamePtr p_classname,
                                        GDExtensionClassInstancePtr p_instance);
GDE_EXPORT GDExtensionObjectPtr gde_object_cast_to(GDExtensionConstObjectPtr p_object, void *p_class_tag);
GDE_EXPORT void gde_object_destroy(GDExtensionObjectPtr p_o);

GDE_EXPORT GDExtensionObjectPtr gde_ref_get_object(GDExtensionConstRefPtr p_ref);
GDE_EXPORT void gde_ref_set_object(GDExtensionRefPtr p_ref, GDExtensionObjectPtr p_object);

GDE_EXPORT GDExtensionScriptInstancePtr gde_script_instance_create2(const GDExtensionScriptInstanceInfo2 *p_info,
                                                                   GDExtensionScriptInstanceDataPtr p_instance_data);
GDE_EXPORT GDExtensionScriptInstanceDataPtr gde_object_get_script_instance(GDExtensionConstObjectPtr p_object,
                                                                           GDExtensionObjectPtr p_language);

#ifdef __cplusplus
}
#endif