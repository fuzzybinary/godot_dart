#pragma once

#include <thread>

#include <godot_cpp/classes/editor_plugin.hpp>
#include <godot_cpp/classes/thread.hpp>

class DartProgressDialog;

class GodotDartEditorPlugin : public godot::EditorPlugin {
  GDCLASS(GodotDartEditorPlugin, EditorPlugin)

public:
  GodotDartEditorPlugin();
  ~GodotDartEditorPlugin();

  virtual void _enter_tree() override;
  virtual void _exit_tree() override;

  bool run_pub_get();

protected:
  static void _bind_methods();

private:
  void show_create_project_dialog();
  void confirm_create_project();
  
  void create_project();

  DartProgressDialog *_progress_dialog;
  godot::Ref<godot::Thread> _project_create_thread;
};