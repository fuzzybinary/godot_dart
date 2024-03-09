#pragma once

#include <gdextension_interface.h>
#include <dart_api.h>

#include <godot_cpp/variant/string.hpp>
#include <godot_cpp/variant/string_name.hpp>

godot::StringName create_godot_string_name(const Dart_Handle &from_dart);
godot::StringName* create_godot_string_name_ptr(const Dart_Handle &from_dart);
Dart_Handle to_dart_string(const godot::StringName &from_godot);


godot::String create_godot_string(const Dart_Handle &from_dart);
godot::String *create_godot_string_ptr(const Dart_Handle &from_dart);
Dart_Handle to_dart_string(const godot::String &from_godot);
