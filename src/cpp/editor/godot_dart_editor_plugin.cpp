#include "godot_dart_editor_plugin.h"

#include <sstream>

#include <godot_cpp/classes/button.hpp>
#include <godot_cpp/classes/confirmation_dialog.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/editor_interface.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/popup.hpp>
#include <godot_cpp/classes/thread.hpp>
#include <godot_cpp/classes/theme.hpp>
#include <godot_cpp/core/class_db.hpp>

#include "../dart_helpers.h"
#include "../godot_dart_runtime_plugin.h"

#include "dart_progress_dialog.h"
#include "dart_templates.h"

using namespace godot;

GodotDartEditorPlugin::GodotDartEditorPlugin() : _reload_button(nullptr) {
  _progress_dialog = memnew(DartProgressDialog);
  add_child(_progress_dialog);
}

GodotDartEditorPlugin::~GodotDartEditorPlugin() {
}

void GodotDartEditorPlugin::_bind_methods() {
  ClassDB::bind_method(godot::D_METHOD("confirm_create_project"), &GodotDartEditorPlugin::confirm_create_project);
  ClassDB::bind_method(godot::D_METHOD("confirm_pub_get"), &GodotDartEditorPlugin::confirm_pub_get);
  ClassDB::bind_method(godot::D_METHOD("run_work"), &GodotDartEditorPlugin::run_work);
  ClassDB::bind_method(godot::D_METHOD("dart_hot_reload"), &GodotDartEditorPlugin::hot_reload);
}

void GodotDartEditorPlugin::_enter_tree() {
  GodotDartRuntimePlugin *runtime_plugin = GodotDartRuntimePlugin::get_instance();
  if (!runtime_plugin) {
    GD_PRINT_ERROR("godot_dart was loaded but didn't initialize!")
    return;
  }

  if (!runtime_plugin->has_dart_module()) {
    show_create_project_dialog();
  } else if (!runtime_plugin->has_package_config()) {
    show_pub_get_dialog();
  }

  _reload_button = memnew(Button);
  _reload_button->set_flat(false);
  auto icon =
      EditorInterface::get_singleton()->get_editor_theme()->get_icon(StringName("Reload"), StringName("EditorIcons"));
  _reload_button->set_button_icon(icon);
  _reload_button->set_focus_mode(Control::FOCUS_NONE);
  _reload_button->set_theme_type_variation(StringName("RunBarButton"));
  _reload_button->set_tooltip_text(String("Perform a Dart Hot Reload"));

  
  _reload_button->connect(StringName("pressed"), Callable(this, StringName("dart_hot_reload")));
  add_control_to_container(EditorPlugin::CONTAINER_TOOLBAR, _reload_button);
  auto parent = _reload_button->get_parent();
  int num_buttons = parent->get_child_count();
  // Move over next to run buttons
  _reload_button->get_parent()->move_child(_reload_button, num_buttons - 2);
}

void GodotDartEditorPlugin::_exit_tree() {

}

void GodotDartEditorPlugin::show_create_project_dialog() {
  ConfirmationDialog *dialog = memnew(ConfirmationDialog);
  dialog->set_text(String("The Godot Dart extension has been loaded in the project, but no Dart project was "
                          "found.\nWould you like to create a Dart project?"));
  dialog->set_ok_button_text("Yes");
  dialog->set_cancel_button_text("No");
  dialog->set_title("Godot Dart");

  dialog->connect(StringName("confirmed"), Callable(this, StringName("confirm_create_project")));

  add_child(dialog);

  dialog->popup_centered();
}

void create_project_file(const String &root_dir, const char *file_name, const char *file_contents) {
  String pubspec_path = root_dir + String(file_name);
  auto pubspec_file = FileAccess::open(pubspec_path, FileAccess::WRITE);
  if (pubspec_file.is_null()) {
    GD_PRINT_ERROR("Could not create source file.");
    return;
  }

  pubspec_file->store_string(String(file_contents));
  pubspec_file->flush();
  pubspec_file->close();
}

int32_t execute_command(const std::string &command) {
  auto os = OS::get_singleton();
  Array output;

  // IFDEF Windows
  PackedStringArray args;
  args.append("/C");
  args.append(command.c_str());
  return os->execute("CMD.exe", args, output);
  // ENDIF Windows
}

void GodotDartEditorPlugin::create_project() {

  Callable(_progress_dialog, "set_text").call_deferred(String("Running dart pub get"));
  Callable(_progress_dialog, "set_progress").call_deferred(25.0f);
  if (!run_pub_get()) {
    Callable(_progress_dialog, "hide").call_deferred();
    return;
  }

  // Not sure why this is required, but it seems to be.

  Callable(_progress_dialog, "set_text").call_deferred();
  Callable(_progress_dialog, "set_progress").call_deferred(50.0f);

  Callable(_progress_dialog, "set_text").call_deferred(String("Reinitializing Godot Dart"));
  Callable(_progress_dialog, "set_progress").call_deferred(75.0f);
}

void GodotDartEditorPlugin::confirm_create_project() {
  _progress_dialog->set_text(String("Creating Dart Files"));
  _progress_dialog->popup_centered();

  _work_steps.push_back({String("Creating Dart Files"), [&]() {
                           GodotDartRuntimePlugin *rtplugin = GodotDartRuntimePlugin::get_instance();
                           String root_dir_str(rtplugin->get_root_dart_dir().c_str());

                           auto err = DirAccess::make_dir_absolute(root_dir_str);
                           if (err != OK && err != ERR_ALREADY_EXISTS) {
                             GD_PRINT_ERROR("Error creating root Dart directory.");
                             return false;
                           }

                           create_project_file(root_dir_str, "/pubspec.yaml", pubspec_template_fmt);
                           create_project_file(root_dir_str, "/main.dart", main_template);
                           create_project_file(root_dir_str, "/.gitignore", git_ignore_template);
                           return true;
                         }});

  _work_steps.push_back({String("Running dart pub get"), [&]() { return run_pub_get(); }});

  _work_steps.push_back({String("Running dart run build_runner build"), [&]() { return run_build_runner(); }});

  _work_steps.push_back({String("Reinitializing Godot Dart"), [&]() {
                           GodotDartRuntimePlugin *rtplugin = GodotDartRuntimePlugin::get_instance();
                           rtplugin->initialize_dart_bindings();

                           return true;
                         }});

  _plugin_work_thread.instantiate();
  _plugin_work_thread->start(Callable(this, "run_work"));
}

void GodotDartEditorPlugin::show_pub_get_dialog() {
  ConfirmationDialog *dialog = memnew(ConfirmationDialog);
  dialog->set_text(String("Could not find .dart_tool/package_config.json.\nWould you like to run pub get?"));
  dialog->set_ok_button_text("Yes");
  dialog->set_cancel_button_text("No");
  dialog->set_title("Godot Dart");

  dialog->connect(StringName("confirmed"), Callable(this, StringName("confirm_pub_get")));

  add_child(dialog);

  dialog->popup_centered();
}

void GodotDartEditorPlugin::confirm_pub_get() {
  _progress_dialog->set_text(String("Running dart pub get"));
  _progress_dialog->popup_centered();

  _work_steps.push_back({String("Running dart pub get"), [&]() { return run_pub_get(); }});

  _work_steps.push_back({String("Running dart run build_runner build"), [&]() { return run_build_runner(); }});

  _work_steps.push_back({String("Reinitializing Godot Dart"), [&]() {
                           GodotDartRuntimePlugin *rtplugin = GodotDartRuntimePlugin::get_instance();
                           rtplugin->initialize_dart_bindings();

                           return true;
                         }});

  _plugin_work_thread.instantiate();
  _plugin_work_thread->start(Callable(this, "run_work"));
}

void GodotDartEditorPlugin::run_work() {
  size_t total_steps = _work_steps.size();
  for (size_t i = 0; i < total_steps; ++i) {
    const auto &step = _work_steps[i];

    float percent_complete = (i / (float)total_steps) * 100.0f;
    Callable(_progress_dialog, "set_progress").call_deferred(percent_complete);

    Callable(_progress_dialog, "set_text").call_deferred(step.description);
    if (!step.step()) {
      break;
    }
  }

  Callable(_progress_dialog, "hide").call_deferred();

  _work_steps.clear();
}

bool GodotDartEditorPlugin::run_pub_get() {
  GodotDartRuntimePlugin *rtplugin = GodotDartRuntimePlugin::get_instance();

  std::stringstream dart_pub_get_stream;
  dart_pub_get_stream << "cd \"" << rtplugin->get_root_dart_dir() << "\" && dart pub get";
  int32_t error_code = execute_command(dart_pub_get_stream.str());

  if (error_code != 0) {
    GD_PRINT_ERROR("Error running pub get.");
    return false;
  }

  // Not sure why this is needed, but we need to sleep for a bit after running pub get.
  std::this_thread::sleep_for(std::chrono::milliseconds(500));

  return true;
}

void GodotDartEditorPlugin::hot_reload() {
  GodotDartBindings::instance()->reload_code();
}

bool GodotDartEditorPlugin::run_build_runner() {
  GodotDartRuntimePlugin *rtplugin = GodotDartRuntimePlugin::get_instance();

  std::stringstream dart_build_stream;
  dart_build_stream << "cd \"" << rtplugin->get_root_dart_dir() << "\" && dart run build_runner build";
  int32_t build_result = execute_command(dart_build_stream.str());
  if (build_result != 0) {
    GD_PRINT_ERROR("Error running dart build.");
    return false;
  }

  return true;
}
