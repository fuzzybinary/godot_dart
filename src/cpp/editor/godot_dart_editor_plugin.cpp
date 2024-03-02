#include "godot_dart_editor_plugin.h"

#include <sstream>

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/classes/confirmation_dialog.hpp>
#include <godot_cpp/classes/popup.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/thread.hpp>

#include "../dart_helpers.h"
#include "../godot_dart_runtime_plugin.h"

#include "dart_templates.h"
#include "dart_progress_dialog.h"

using namespace godot;

GodotDartEditorPlugin::GodotDartEditorPlugin() {
  _progress_dialog = memnew(DartProgressDialog);
  add_child(_progress_dialog);
}

GodotDartEditorPlugin::~GodotDartEditorPlugin() {
}

void GodotDartEditorPlugin::_bind_methods() {
  
  ClassDB::bind_method(godot::D_METHOD("confirm_create_project"),
                              &GodotDartEditorPlugin::confirm_create_project);
  ClassDB::bind_method(godot::D_METHOD("create_project"), &GodotDartEditorPlugin::create_project);

}

void GodotDartEditorPlugin::_enter_tree() {
  GodotDartRuntimePlugin *runtime_plugin = GodotDartRuntimePlugin::get_instance();
  if (!runtime_plugin) {
    GD_PRINT_ERROR("godot_dart was loaded bug didn't initialize!")
    return;
  }

  if (!runtime_plugin->has_dart_module()) {
    show_create_project_dialog();
  }
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
  GodotDartRuntimePlugin *rtplugin = GodotDartRuntimePlugin::get_instance();
  String root_dir_str(rtplugin->get_root_dart_dir().c_str());

  auto err = DirAccess::make_dir_absolute(root_dir_str);
  if (err != OK && err != ERR_ALREADY_EXISTS) {
    GD_PRINT_ERROR("Error creating root Dart directory.");
    return;
  }

  create_project_file(root_dir_str, "/pubspec.yaml", pubspec_template_fmt);
  create_project_file(root_dir_str, "/main.dart", main_template);
  create_project_file(root_dir_str, "/.gitignore", git_ignore_template);

  Callable(_progress_dialog, "set_text").call_deferred(String("Running dart pub get"));
  Callable(_progress_dialog, "set_progress").call_deferred(25.0f);
  if (!run_pub_get()) {
    Callable(_progress_dialog, "hide").call_deferred();
    return;
  }

  // Not sure why this is required, but it seems to be.
  std::this_thread::sleep_for(std::chrono::milliseconds(500));

  Callable(_progress_dialog, "set_text").call_deferred(String("Running dart run build_runner build"));
  Callable(_progress_dialog, "set_progress").call_deferred(50.0f);
  
  std::stringstream dart_build_stream;
  dart_build_stream << "cd \"" << rtplugin->get_root_dart_dir() << "\" && dart run build_runner build";
  int32_t build_result = execute_command(dart_build_stream.str());
  if (build_result != 0) {
    GD_PRINT_ERROR("Error running dart build.");
  }

  Callable(_progress_dialog, "set_text").call_deferred(String("Reinitializing Godot Dart"));
  Callable(_progress_dialog, "set_progress").call_deferred(75.0f);

  rtplugin->initialize_dart_bindings();

  Callable(_progress_dialog, "hide").call_deferred();
}

void GodotDartEditorPlugin::confirm_create_project() {
  _progress_dialog->set_text(String("Creating Dart Files"));
  _progress_dialog->popup_centered();
  
  _project_create_thread.instantiate();
  _project_create_thread->start(Callable(this, "create_project"));
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

  return true;
}
