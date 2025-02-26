#pragma once

#include <vector>
#include <functional>

#include <godot_cpp/classes/editor_plugin.hpp>
#include <godot_cpp/classes/thread.hpp>

class DartProgressDialog;

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

  // Project creation
  void show_create_project_dialog();
  void confirm_create_project();
  void create_project();

  // Pub get
  void show_pub_get_dialog();
  void confirm_pub_get();

  void hot_reload();  

  void run_work();

  std::vector<WorkStep> _work_steps;

  DartProgressDialog *_progress_dialog;
  godot::Ref<godot::Thread> _plugin_work_thread;
  godot::Button* _reload_button;
};