#pragma once

#include <godot_cpp/variant/string.hpp>

namespace godot_dart {

// Wrapper around the dart sdk that runs the various commands
// needed to build the dart project and start DDS.
//
// This may be expanded to do things like start the analysis server or
// run `build_runner` in the future.
class DartCommandRunner {
public:
  DartCommandRunner(godot::String sdk_path, godot::String project_path);

  int32_t pub_get();
  int32_t dart_build_runner();
  int32_t build_dill();

private:
  int32_t execute_command(const godot::String &command, godot::Array &output);

  godot::String _sdk_path;
  godot::String _dart_exe_path; 
  godot::String _project_path;
};

} // namespace godot_dart