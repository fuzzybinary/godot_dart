#include "dart_command_runner.h"

#include <godot_cpp/classes/os.hpp>
#include <dart_helpers.h>

namespace godot_dart {
DartCommandRunner::DartCommandRunner(godot::String sdk_path, godot::String project_path)
    : _sdk_path(sdk_path), _project_path(project_path) {
  _dart_exe_path = sdk_path.path_join("bin/dart");
}

int32_t DartCommandRunner::pub_get() {  
  godot::String command("pub get");

  godot::Array output;
  int32_t error_code = execute_command(command, output);

  if (error_code != 0) {
    GD_PRINT_ERROR("Error running pub get.");
    for (int i = 0; i < output.size(); ++i) {
      godot::UtilityFunctions::print(output[i]);
    }
  }

  return error_code;
}

int32_t DartCommandRunner::dart_build_runner() {
  godot::String command("run build_runner build --delete-conflicting-outputs");

  godot::Array output;
  int32_t error_code = execute_command(command, output);

  if (error_code != 0) {
    GD_PRINT_ERROR("Error running build_runner.");
    for (int i = 0; i < output.size(); ++i) {
      godot::UtilityFunctions::print(output[i]);
    }
  }

  return error_code;
}

int32_t DartCommandRunner::build_dill() {
  godot::String command("compile kernel main.dart");

  godot::Array output;
  int32_t error_code = execute_command(command, output);

  if (error_code != 0) {
    GD_PRINT_ERROR("Error compiling Dart code.");
    for (int i = 0; i < output.size(); ++i) {
      godot::UtilityFunctions::print(output[i]);
    }
  }

  return error_code;
}

int32_t DartCommandRunner::execute_command(const godot::String &command, godot::Array &output) {
  auto os = godot::OS::get_singleton();

  godot::String format_string("cd \"{0}\" && \"{1}\" {2}");
  godot::Array array;
  array.append(_project_path);
  array.append(_dart_exe_path);
  array.append(command);
  godot::String full_command = format_string.format(array);  

  godot::UtilityFunctions::print(full_command);

  // IFDEF Windows
  godot::PackedStringArray args;
  args.append("/C");
  args.append(full_command);
  return os->execute("CMD.exe", args, output);
  // ENDIF Windows
}

} // namespace godot_dart