#include "dart_script_instance.h"

#include <dart_api.h>

#include <godot_cpp/classes/object.hpp>

#include "dart_bindings.h"
#include "dart_helpers.h"
#include "gde_wrapper.h"
#include "ref_counted_wrapper.h"

#include "script/dart_script_language.h"

std::map<intptr_t, DartScriptInstance*> DartScriptInstance::s_instanceMap;

DartScriptInstance::DartScriptInstance(Dart_Handle for_object, godot::Ref<DartScript> script, godot::Object* owner,
                                       bool is_placeholder, bool is_refcounted)
    : _is_placeholder(is_placeholder), _binding(nullptr, owner), _godot_object(owner) {
  
  s_instanceMap[(intptr_t)this] = this;
  _binding.initialize(for_object, is_refcounted);
  _dart_script = script;
}

DartScriptInstance::~DartScriptInstance() {
  s_instanceMap.erase((intptr_t)this);
}

bool DartScriptInstance::set(const godot::StringName &p_name, GDExtensionConstVariantPtr p_value) {
  GodotDartBindings *gde = GodotDartBindings::instance();
  if (gde == nullptr) {
    return false;
  }

  bool set_value = false;
  gde->execute_on_dart_thread([&] {
    DartBlockScope scope;

    Dart_Handle field_name = to_dart_string(p_name);
    DART_CHECK(object, _binding.get_dart_object(), "Failed to get instance from persistent handle");
    DART_CHECK(obj_type_info, Dart_GetField(object, Dart_NewStringFromCString("typeInfo")), "Failed to find typeInfo");
    DART_CHECK(script_info, Dart_GetField(obj_type_info, Dart_NewStringFromCString("scriptInfo")),
               "Failed to find scriptInfo");

    Dart_Handle prop_info_args[] = {field_name};
    DART_CHECK(dart_property_info,
               Dart_Invoke(script_info, Dart_NewStringFromCString("getPropertyInfo"), 1, prop_info_args),
               "Failed to get property");
    if (Dart_IsNull(dart_property_info)) {
      return;
    }

    DART_CHECK(prop_type_info, Dart_GetField(dart_property_info, Dart_NewStringFromCString("typeInfo")),
               "Failed to get typeInfo for property");
    Dart_Handle value_address = Dart_NewInteger(reinterpret_cast<intptr_t>(p_value));
    Dart_Handle native_library = Dart_HandleFromPersistent(gde->_native_library);
    Dart_Handle args[] = {
        value_address,
        prop_type_info,
    };
    DART_CHECK(dart_property_value,
               Dart_Invoke(native_library, Dart_NewStringFromCString("_variantAddressToDart"), 2, args),
               "Failed to convert variant to Dart object");
    DART_CHECK(result, Dart_SetField(object, field_name, dart_property_value), "Failed to set field");

    set_value = true;
  });

  return set_value;
}

bool DartScriptInstance::get(const godot::StringName &p_name, GDExtensionVariantPtr r_ret) {
  GodotDartBindings *gde = GodotDartBindings::instance();
  if (gde == nullptr) {
    return false;
  }

  bool got_value = false;
  gde->execute_on_dart_thread([&] {
    DartBlockScope scope;
    Dart_Handle field_name = to_dart_string(p_name);

    DART_CHECK(object, _binding.get_dart_object(), "Failed to get instance from persistent handle");
    DART_CHECK(obj_type_info, Dart_GetField(object, Dart_NewStringFromCString("typeInfo")), "Failed to find typeInfo");
    DART_CHECK(script_info, Dart_GetField(obj_type_info, Dart_NewStringFromCString("scriptInfo")),
               "Failed to find scriptInfo");

    // Need to check if the property exists, because Godot asks for properties we never told it about
    {
      Dart_Handle args[] = {field_name};
      DART_CHECK(dart_property_info, Dart_Invoke(script_info, Dart_NewStringFromCString("getPropertyInfo"), 1, args),
                 "Failed to get property");
      if (Dart_IsNull(dart_property_info)) {
        return;
      }
    }

    DART_CHECK(dart_value, Dart_GetField(object, field_name), "Failed to get property");
    Dart_Handle variant_type = Dart_HandleFromPersistent(gde->_variant_type);
    Dart_Handle args[] = {dart_value};
    DART_CHECK(variant_result, Dart_New(variant_type, Dart_Null(), 1, args),
               "Failed to convert prop to variant");

    void *variantDataPtr = get_object_address(variant_result);
    if (variantDataPtr) {
      gde_variant_new_copy(r_ret, reinterpret_cast<GDExtensionConstVariantPtr>(variantDataPtr));
      got_value = true;
    }
  });

  return got_value;
}

bool DartScriptInstance::get_class_category(GDExtensionPropertyInfo *p_class_category) {
  return false;
}

const GDExtensionPropertyInfo *DartScriptInstance::get_property_list(uint32_t *r_count) {
  GDExtensionPropertyInfo *prop_list{nullptr};
  const auto &prop_map = _dart_script->get_properties();
  size_t prop_count = prop_map.size();
  *r_count = prop_count;
  if (prop_count > 0) {
    prop_list = new GDExtensionPropertyInfo[prop_count];
    size_t index = 0;
    for (const auto &property : prop_map) {
      prop_list[index] = property.second;
      ++index;
    }
  }

  return prop_list;
}

void DartScriptInstance::free_property_list(const GDExtensionPropertyInfo *p_list) {
  delete[] p_list;
}

GDExtensionVariantType DartScriptInstance::get_property_type(const godot::StringName &p_name,
                                                             GDExtensionBool *r_is_valid) {
  const auto &properties = _dart_script->get_properties();
  const auto &prop_itr = properties.find(p_name);
  *r_is_valid = prop_itr != properties.end();
  if (r_is_valid) {
    return prop_itr->second.type;
  }
  return GDExtensionVariantType{};
}

bool DartScriptInstance::validate_property(GDExtensionPropertyInfo *p_property) {
  return false;
}

GDExtensionBool DartScriptInstance::property_can_revert(const godot::StringName &p_name) {
  return false;
}

GDExtensionBool DartScriptInstance::property_get_revert(const godot::StringName &p_name, GDExtensionVariantPtr r_ret) {
  return false;
}

GDExtensionObjectPtr DartScriptInstance::get_owner() {
  return _binding.get_godot_object();
}

void DartScriptInstance::get_property_state(GDExtensionScriptInstancePropertyStateAdd p_add_func, void *p_userdata) {
}

const GDExtensionMethodInfo *DartScriptInstance::get_method_list(uint32_t *r_count) {
  GodotDartBindings *gde = GodotDartBindings::instance();
  if (gde == nullptr) {
    return nullptr;
  }

  GDExtensionMethodInfo *method_list = nullptr;
  gde->execute_on_dart_thread([&] {
    DartBlockScope scope;

    // This is a lot of work just to get the size of the list
    DART_CHECK(object, _binding.get_dart_object(), "Failed to get instance from persistent handle");
    DART_CHECK(obj_type_info, Dart_GetField(object, Dart_NewStringFromCString("typeInfo")), "Failed to find typeInfo");
    DART_CHECK(dart_script_info, Dart_GetField(obj_type_info, Dart_NewStringFromCString("scriptInfo")),
               "Failed to get scirpt info");
    DART_CHECK(dart_method_list, Dart_GetField(dart_script_info, Dart_NewStringFromCString("methods")),
               "Failed to get properties info");
    intptr_t method_count = 0;
    Dart_ListLength(dart_method_list, &method_count);
    *r_count = method_count;

    if (method_count > 0) {
      method_list = new GDExtensionMethodInfo[method_count];
      for (auto i = 0; i < method_count; ++i) {
        DART_CHECK(dart_method, Dart_ListGetAt(dart_method_list, i), "Failed to get property at index");
        gde_method_info_from_dart(dart_method, &method_list[i]);
      }
    }
  });

  return method_list;
}

void DartScriptInstance::free_method_list(const GDExtensionMethodInfo *p_list) {
  GodotDartBindings *gde = GodotDartBindings::instance();
  if (gde == nullptr) {
    return;
  }

  gde->execute_on_dart_thread([&] {
    DartBlockScope scope;

    // This is a lot of work just to get the size of the list
    DART_CHECK(object, _binding.get_dart_object(), "Failed to get instance from persistent handle");
    DART_CHECK(obj_type_info, Dart_GetField(object, Dart_NewStringFromCString("typeInfo")), "Failed to find typeInfo");
    DART_CHECK(dart_script_info, Dart_GetField(obj_type_info, Dart_NewStringFromCString("scriptInfo")),
               "Failed to get scirpt info");
    DART_CHECK(dart_method_list, Dart_GetField(dart_script_info, Dart_NewStringFromCString("methods")),
               "Failed to get properties info");
    intptr_t prop_count = 0;
    Dart_ListLength(dart_method_list, &prop_count);

    if (p_list != nullptr) {
      for (intptr_t i = 0; i < prop_count; ++i) {
        gde_free_method_info_fields(const_cast<GDExtensionMethodInfo *>(&p_list[i]));
      }

      delete[] p_list;
    }
  });
}

GDExtensionBool DartScriptInstance::has_method(const godot::StringName &p_name) {
  GodotDartBindings *gde = GodotDartBindings::instance();
  if (gde == nullptr) {
    return false;
  }

  bool hasMethod = false;
  gde->execute_on_dart_thread([&] {
    DartBlockScope scope;

    DART_CHECK(object, _binding.get_dart_object(), "Failed to get instance from persistent handle");
    DART_CHECK(obj_type_info, Dart_GetField(object, Dart_NewStringFromCString("typeInfo")), "Failed to find typeInfo");
    DART_CHECK(dart_script_info, Dart_GetField(obj_type_info, Dart_NewStringFromCString("scriptInfo")),
               "Failed to get scirpt info");

    Dart_Handle method_info_args[] = {to_dart_string(p_name)};
    DART_CHECK(method_info,
               Dart_Invoke(dart_script_info, Dart_NewStringFromCString("getMethodInfo"), 1, method_info_args),
               "Failed getting method");

    hasMethod = !Dart_IsNull(method_info);
  });

  return hasMethod;
}

void DartScriptInstance::call(const godot::StringName *p_method, const GDExtensionConstVariantPtr *p_args,
                              GDExtensionInt p_argument_count, GDExtensionVariantPtr r_return,
                              GDExtensionCallError *r_error) {
  GodotDartBindings *gde = GodotDartBindings::instance();
  if (gde == nullptr) {
    return;
  }

  // TODO: Figure out wth placeholders do
  if (_is_placeholder) {
    // Placeholders always return CALL_ERROR_INVALID_METHOD
    r_error->error = GDEXTENSION_CALL_ERROR_INVALID_METHOD;
    return;
  }

  Dart_Handle *dart_args = nullptr;

  // TODO: Revisit this, we can probably do it simpler now
  gde->execute_on_dart_thread([&] {
    DartBlockScope scope;

    DART_CHECK(object, _binding.get_dart_object(), "Failed to get instance from persistent handle");
    DART_CHECK(obj_type_info, Dart_GetField(object, Dart_NewStringFromCString("typeInfo")), "Failed to find typeInfo");
    DART_CHECK(dart_script_info, Dart_GetField(obj_type_info, Dart_NewStringFromCString("scriptInfo")),
               "Failed to get scirpt info");

    Dart_Handle method_info_args[] = {to_dart_string(*p_method)};
    DART_CHECK(method_info,
               Dart_Invoke(dart_script_info, Dart_NewStringFromCString("getMethodInfo"), 1, method_info_args),
               "Failed getting method");
    if (Dart_IsNull(method_info)) {
      r_error->error = GDEXTENSION_CALL_ERROR_INVALID_METHOD;
      return;
    }

    DART_CHECK(dart_method_call, Dart_GetField(method_info, Dart_NewStringFromCString("dartMethodCall")), "Failed to get dart method call");

    DART_CHECK(args_list, Dart_GetField(method_info, Dart_NewStringFromCString("args")),
               "Failed getting method arguments");
    intptr_t arg_count = 0;
    Dart_ListLength(args_list, &arg_count);

    Dart_Handle dart_converted_arg_list;
    if (arg_count != 0) {
      Dart_Handle args_address = Dart_NewInteger(reinterpret_cast<intptr_t>(p_args));
      Dart_Handle convert_args[3]{
          args_address,
          Dart_NewInteger(arg_count),
          args_list,
      };
      dart_converted_arg_list = Dart_Invoke(gde->_native_library, Dart_NewStringFromCString("_variantsToDart"), 3, convert_args);
      if (Dart_IsError(dart_converted_arg_list)) {
        r_error->error = GDEXTENSION_CALL_ERROR_INVALID_METHOD;
        return;
      }
    } else {
      dart_converted_arg_list = Dart_NewList(0);
    }

    Dart_Handle dart_args[2] = {
      object, dart_converted_arg_list,
    };
    DART_CHECK(dart_ret, Dart_InvokeClosure(object, arg_count, dart_args), "Failed to call method");
    Dart_Handle variant_type = Dart_HandleFromPersistent(gde->_variant_type);
    Dart_Handle args[] = {dart_ret};
    Dart_Handle variant_result = Dart_New(variant_type, Dart_Null(), 1, args);

    if (Dart_IsError(variant_result)) {
      GD_PRINT_ERROR("GodotDart: Error converting return to variant: ");
      GD_PRINT_ERROR(Dart_GetError(variant_result));
    } else {
      void *variantDataPtr = get_object_address(variant_result);
      if (variantDataPtr) {
        gde_variant_new_copy(r_return, reinterpret_cast<GDExtensionConstVariantPtr>(variantDataPtr));
      }
    }

    r_error->error = GDEXTENSION_CALL_OK;
  });

  if (dart_args != nullptr) {
    delete[] dart_args;
  }
}

void DartScriptInstance::notification(int32_t p_what, bool p_reversed) {
}

void DartScriptInstance::to_string(GDExtensionBool *r_is_valid, GDExtensionStringPtr r_out) {
}

void DartScriptInstance::ref_count_incremented() {
  RefCountedWrapper ref_counted(_binding.get_godot_object());
  int refcount = ref_counted.get_reference_count();

  // Refcount incremented, change our reference to strong to prevent Dart from finalizing
  if (refcount > 1 && _binding.is_weak()) {
    _binding.convert_to_strong();
  }
}

GDExtensionBool DartScriptInstance::ref_count_decremented() {
  RefCountedWrapper ref_counted(_binding.get_godot_object());
  int refcount = ref_counted.get_reference_count();

  if (refcount == 1 && !_binding.is_weak()) {
    // We're the only ones holding on, switch us to weak so Dart will delete when it
    // has no more references
    _binding.convert_to_weak();
  }

  return refcount == 0;
}

GDExtensionObjectPtr DartScriptInstance::get_script() {
  return _dart_script->_owner;
}

GDExtensionBool DartScriptInstance::is_placeholder() {
  return _is_placeholder;
}

bool DartScriptInstance::set_fallback(const godot::StringName &p_name, GDExtensionConstVariantPtr p_value) {
  return false;
}

bool DartScriptInstance::get_fallback(const godot::StringName &p_name, GDExtensionVariantPtr r_ret) {
  return false;
}

GDExtensionScriptLanguagePtr DartScriptInstance::get_language() {
  auto ptr = DartScriptLanguage::instance();
  if (ptr == nullptr) {
    return nullptr;
  }
  return ptr->_owner;
}

void DartScriptInstance::notify_property_list_changed() {
  if (_godot_object && _is_placeholder) {    
    _godot_object->notify_property_list_changed();
  }
}

// * Static Callback Functions for Godot */

GDExtensionBool script_instance_set(GDExtensionScriptInstanceDataPtr p_instance, GDExtensionConstStringNamePtr p_name,
                                    GDExtensionConstVariantPtr p_value) {
  const godot::StringName *gd_name = reinterpret_cast<const godot::StringName *>(p_name);
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->set(*gd_name, p_value);
}

GDExtensionBool script_instance_get(GDExtensionScriptInstanceDataPtr p_instance, GDExtensionConstStringNamePtr p_name,
                                    GDExtensionVariantPtr r_ret) {
  const godot::StringName *gd_name = reinterpret_cast<const godot::StringName *>(p_name);
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->get(*gd_name, r_ret);
}

GDExtensionBool script_instance_get_class_category(GDExtensionScriptInstanceDataPtr p_instance, GDExtensionPropertyInfo* p_class_category) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->get_class_category(p_class_category);
}

const GDExtensionPropertyInfo *script_instance_get_property_list(GDExtensionScriptInstanceDataPtr p_instance,
                                                                 uint32_t *r_count) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->get_property_list(r_count);
}

void script_instance_free_property_list(GDExtensionScriptInstanceDataPtr p_instance,
                                        const GDExtensionPropertyInfo *p_list) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  instance->free_property_list(p_list);
}

GDExtensionVariantType script_instance_get_property_type(GDExtensionScriptInstanceDataPtr p_instance,
                                                         GDExtensionConstStringNamePtr p_name,
                                                         GDExtensionBool *r_is_valid) {
  const godot::StringName *gd_name = reinterpret_cast<const godot::StringName *>(p_name);
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->get_property_type(*gd_name, r_is_valid);
}

GDExtensionBool script_instance_validate_property(GDExtensionScriptInstanceDataPtr p_instance,
                                                  GDExtensionPropertyInfo *p_property) {

  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->validate_property(p_property);
}

GDExtensionBool script_instance_property_can_revert(GDExtensionScriptInstanceDataPtr p_instance,
                                                    GDExtensionConstStringNamePtr p_name) {
  const godot::StringName *gd_name = reinterpret_cast<const godot::StringName *>(p_name);
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->property_can_revert(*gd_name);
}

GDExtensionBool script_instance_property_get_revert(GDExtensionScriptInstanceDataPtr p_instance,
                                                    GDExtensionConstStringNamePtr p_name, GDExtensionVariantPtr r_ret) {
  const godot::StringName *gd_name = reinterpret_cast<const godot::StringName *>(p_name);
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->property_get_revert(*gd_name, r_ret);
}

GDExtensionObjectPtr script_instance_get_owner(GDExtensionScriptInstanceDataPtr p_instance) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->get_owner();
}

void script_instance_get_property_state(GDExtensionScriptInstanceDataPtr p_instance,
                                        GDExtensionScriptInstancePropertyStateAdd p_add_func, void *p_userdata) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  instance->get_property_state(p_add_func, p_userdata);
}

const GDExtensionMethodInfo *script_instance_get_method_list(GDExtensionScriptInstanceDataPtr p_instance,
                                                             uint32_t *r_count) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->get_method_list(r_count);
}

void script_instance_free_method_list(GDExtensionScriptInstanceDataPtr p_instance,
                                      const GDExtensionMethodInfo *p_list) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  instance->free_method_list(p_list);
}

GDExtensionBool script_instance_has_method(GDExtensionScriptInstanceDataPtr p_instance,
                                           GDExtensionConstStringNamePtr p_name) {
  const godot::StringName *gd_name = reinterpret_cast<const godot::StringName *>(p_name);
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->has_method(*gd_name);
}

void script_instance_call(GDExtensionScriptInstanceDataPtr p_self, GDExtensionConstStringNamePtr p_method,
                          const GDExtensionConstVariantPtr *p_args, GDExtensionInt p_argument_count,
                          GDExtensionVariantPtr r_return, GDExtensionCallError *r_error) {
  const godot::StringName *gd_method = reinterpret_cast<const godot::StringName *>(p_method);
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_self);
  instance->call(gd_method, p_args, p_argument_count, r_return, r_error);
}

void script_instance_notification(GDExtensionScriptInstanceDataPtr p_instance, int32_t p_what,
                                  GDExtensionBool p_reversed) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  instance->notification(p_what, p_reversed);
}

void script_instance_to_string(GDExtensionScriptInstanceDataPtr p_instance, GDExtensionBool *r_is_valid,
                               GDExtensionStringPtr r_out) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  instance->to_string(r_is_valid, r_out);
}

void script_instance_ref_count_incremented(GDExtensionScriptInstanceDataPtr p_instance) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  instance->ref_count_incremented();
}

GDExtensionBool script_instance_ref_count_decremented(GDExtensionScriptInstanceDataPtr p_instance) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->ref_count_decremented();
}

GDExtensionObjectPtr script_instance_get_script(GDExtensionScriptInstanceDataPtr p_instance) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->get_script();
}

GDExtensionBool script_instance_is_placeholder(GDExtensionScriptInstanceDataPtr p_instance) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->is_placeholder();
}

GDExtensionBool script_instance_set_fallback(GDExtensionScriptInstanceDataPtr p_instance,
                                             GDExtensionConstStringNamePtr p_name, GDExtensionConstVariantPtr p_value) {
  const godot::StringName *gd_name = reinterpret_cast<const godot::StringName *>(p_name);
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->set_fallback(*gd_name, p_value);
}

GDExtensionBool script_instance_get_fallback(GDExtensionScriptInstanceDataPtr p_instance,
                                             GDExtensionConstStringNamePtr p_name, GDExtensionVariantPtr r_ret) {
  const godot::StringName *gd_name = reinterpret_cast<const godot::StringName *>(p_name);
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->get_fallback(*gd_name, r_ret);
}

GDExtensionScriptLanguagePtr script_instance_get_language(GDExtensionScriptInstanceDataPtr p_instance) {
  DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
  return instance->get_language();
}

void script_instance_free(GDExtensionScriptInstanceDataPtr p_instance) {
  // Needs to be done from the dart thread
  GodotDartBindings *gde = GodotDartBindings::instance();
  if (gde == nullptr) {
    return;
  }

  gde->execute_on_dart_thread([&] {
    DartBlockScope scope;

    DartScriptInstance *instance = reinterpret_cast<DartScriptInstance *>(p_instance);
    if (instance->is_placeholder()) {
      instance->get_dart_script()->dart_placeholder_erased(instance);
    }

    Dart_Handle dart_object = instance->get_dart_object();

    if (!Dart_IsNull(dart_object)) {
      Dart_Handle result = Dart_Invoke(dart_object, Dart_NewStringFromCString("detachOwner"), 0, nullptr);
      if (Dart_IsError(result)) {
        GD_PRINT_ERROR("GodotDart: Error detaching owner during instance free: ");
        GD_PRINT_ERROR(Dart_GetError(result));
      }      
    }

    delete instance;
  });
}

const GDExtensionScriptInstanceInfo2 *DartScriptInstance::get_script_instance_info() {
  return &script_instance_info;
}

GDExtensionScriptInstanceInfo2 DartScriptInstance::script_instance_info = {
    script_instance_set,
    script_instance_get,
    script_instance_get_property_list,
    script_instance_free_property_list,
    nullptr,  // TODO: Check if we need to override this
    script_instance_property_can_revert,
    script_instance_property_get_revert,
    script_instance_get_owner,
    script_instance_get_property_state,
    script_instance_get_method_list,
    script_instance_free_method_list,
    script_instance_get_property_type,
    script_instance_validate_property,
    script_instance_has_method,
    script_instance_call,
    script_instance_notification,
    script_instance_to_string,
    script_instance_ref_count_incremented,
    script_instance_ref_count_decremented,
    script_instance_get_script,
    script_instance_is_placeholder,
    script_instance_set_fallback,
    script_instance_get_fallback,
    script_instance_get_language,
    script_instance_free,
};