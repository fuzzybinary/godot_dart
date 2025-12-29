#pragma once

#include <vector>
#include <functional>

#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/classes/editor_plugin.hpp>
#include <godot_cpp/classes/thread.hpp>

class DartProgressDialog;

namespace godot_dart {
class DartCommandRunner;
}

class GodotDartEditorPlugin : public godot::EditorPlugin {
  GDCLASS(GodotDartEditorPlugin, EditorPlugin)

public:
  GodotDartEditorPlugin();
  ~GodotDartEditorPlugin();

  void _enter_tree() override;
  void _exit_tree() override;

  bool run_pub_get();
  bool run_build_runner();

protected:
  static void _bind_methods();

private:
  struct WorkStep {
    godot::String description;
    std::function<bool ()> step;
  };

  // SDK Initialization
  bool initialize_dart_sdk();
  void show_download_dart_dialog();
  void download_dart();
  void create_dart_command_runner();

  // Building 
  void push_build_work();
  
  // Project creation
  void show_create_project_dialog();  
  void create_project();

  void hot_reload();

  void run_work();

  godot_dart::DartCommandRunner *_command_runner;

  std::vector<WorkStep> _work_steps;

  DartProgressDialog *_progress_dialog;
  godot::Ref<godot::Thread> _plugin_work_thread;
  godot::Button* _reload_button;
};