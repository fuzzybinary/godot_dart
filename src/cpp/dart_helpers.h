#pragma once

#include <dart_api.h>

#include "gde_c_interface.h"
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

inline bool is_print_verbose_enabled() {
  auto os_singleton = godot::OS::get_singleton();
  if (os_singleton && os_singleton->is_stdout_verbose()) return true;
  return false;
}

inline void __print_verbose(const char *msg) {
  if (is_print_verbose_enabled()) {
    godot::String godot_msg(msg);
    godot::UtilityFunctions::print(msg);
  }
}

#define GD_PRINT_ERROR(msg)                                                                                            \
  { gde_print_error(msg, __func__, __FILE__, __LINE__, true); }

#define GD_PRINT_WARNING(msg)                                                                                          \
  { gde_print_warning(msg, __func__, __FILE__, __LINE__, true); }

#define GD_PRINT_VERBOSE(msg)                                                                                          \
  { __print_verbose(msg); }

#define DART_CHECK_RET(var, expr, ret, message)                                                                        \
  Dart_Handle var = (expr);                                                                                            \
  if (Dart_IsError(var)) {                                                                                             \
    GD_PRINT_ERROR("GodotDart: " message ": ");                                                                        \
    GD_PRINT_ERROR(Dart_GetError(var));                                                                                \
    return ret;                                                                                                        \
  }

#define DART_CHECK(var, expr, message) DART_CHECK_RET(var, expr, , message)

#define DART_HANDLE_ERROR(var, message)                                                                                \
  if (Dart_IsError(var)) {                                                                                             \
    GD_PRINT_ERROR("GodotDart: " message ": ");                                                                        \
    GD_PRINT_ERROR(Dart_GetError(var));                                                                                \
    return;                                                                                                            \
  }

class DartBlockScope {

public:
  DartBlockScope() {
    Dart_EnterScope();
  }

  ~DartBlockScope() {
    Dart_ExitScope();
  }
};