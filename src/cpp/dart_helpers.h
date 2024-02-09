#pragma once

#include <dart_api.h>

#include "gde_c_interface.h"

#define GD_PRINT_ERROR(msg)                                                                                            \
  { gde_print_error(msg, __func__, __FILE__, __LINE__, true); }

#define GD_PRINT_WARNING(msg)                                                                                          \
  { gde_print_warning(msg, __func__, __FILE__, __LINE__, true); }

#define DART_CHECK_RET(var, expr, ret, message)                                                                        \
  Dart_Handle var = (expr);                                                                                            \
  if (Dart_IsError(var)) {                                                                                             \
    GD_PRINT_ERROR("GodotDart: " message ": ");                                                                      \
    GD_PRINT_ERROR(Dart_GetError(var));                                                                                \
    return ret;                                                                                                        \
  }

#define DART_CHECK(var, expr, message) DART_CHECK_RET(var, expr, , message)

class DartBlockScope {

public:
  DartBlockScope() {
    Dart_EnterScope();
  }

  ~DartBlockScope() {
    Dart_ExitScope();
  }
};