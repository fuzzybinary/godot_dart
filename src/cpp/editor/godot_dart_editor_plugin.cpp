#include "godot_dart_editor_plugin.h"

#include <sstream>

#include <godot_cpp/classes/button.hpp>
#include <godot_cpp/classes/confirmation_dialog.hpp>
#include <godot_cpp/classes/dir_access.hpp>
#include <godot_cpp/classes/editor_interface.hpp>
#include <godot_cpp/classes/editor_paths.hpp>
#include <godot_cpp/classes/engine.hpp>
#include <godot_cpp/classes/file_access.hpp>
#include <godot_cpp/classes/http_client.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/popup.hpp>
#include <godot_cpp/classes/theme.hpp>
#include <godot_cpp/classes/thread.hpp>
#include <godot_cpp/classes/zip_reader.hpp>
#include <godot_cpp/core/class_db.hpp>

#include "../dart_helpers.h"
#include "../godot_dart_runtime_plugin.h"

#include "dart_command_runner.h"
#include "dart_progress_dialog.h"
#include "dart_templates.h"
#include "dart_version_constants.h"

using namespace godot;

GodotDartEditorPlugin::GodotDartEditorPlugin() : _reload_button(nullptr), _command_runner(nullptr) {
  _progress_dialog = memnew(DartProgressDialog);
  add_child(_progress_dialog);
}

GodotDartEditorPlugin::~GodotDartEditorPlugin() {
}

void GodotDartEditorPlugin::_bind_methods() {
  ClassDB::bind_method(godot::D_METHOD("download_dart"), &GodotDartEditorPlugin::download_dart);
  ClassDB::bind_method(godot::D_METHOD("create_project"), &GodotDartEditorPlugin::create_project);
  ClassDB::bind_method(godot::D_METHOD("run_work"), &GodotDartEditorPlugin::run_work);
  ClassDB::bind_method(godot::D_METHOD("dart_hot_reload"), &GodotDartEditorPlugin::hot_reload);
}

void GodotDartEditorPlugin::_enter_tree() {
  GodotDartRuntimePlugin *runtime_plugin = GodotDartRuntimePlugin::get_instance();
  if (!runtime_plugin) {
    GD_PRINT_ERROR("godot_dart was loaded but didn't initialize!")
    return;
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

  initialize_dart_sdk();
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

  dialog->connect(StringName("confirmed"), Callable(this, StringName("create_project")));

  add_child(dialog);

  dialog->popup_centered();
}

bool GodotDartEditorPlugin::initialize_dart_sdk() {
  StringName sn_editor_paths("EditorPaths");
  Engine *engine = Engine::get_singleton();
  if (!engine->is_editor_hint()) {
    return false;
  }

  EditorPaths *editor_paths = get_editor_interface()->get_editor_paths();
  String dart_user_path = editor_paths->get_data_dir().path_join("dart");

  // Check if we have the correct dart version
  Ref<DirAccess> dir = DirAccess::open(dart_user_path);
  if (!dir.is_valid() || !dir->dir_exists(DART_VERSION)) {
    show_download_dart_dialog();
  } else {
    create_dart_command_runner();    
    push_build_work();

    _plugin_work_thread.instantiate();
    _plugin_work_thread->start(Callable(this, "run_work"));
  }
}

void GodotDartEditorPlugin::show_download_dart_dialog() {
  ConfirmationDialog *dialog = memnew(ConfirmationDialog);
  dialog->set_text(String("The Godot Dart extension has been loaded in the project, but the required Dart SDK "
                          "(v" DART_VERSION ") was not found.\nWould you like to download it?"));
  dialog->set_ok_button_text("Yes");
  dialog->set_cancel_button_text("No");
  dialog->set_title("Godot Dart");

  dialog->connect(StringName("confirmed"), Callable(this, StringName("download_dart")));

  add_child(dialog);

  dialog->popup_centered();
}

void GodotDartEditorPlugin::download_dart() {
  String titleString("Downloading Dart v" DART_VERSION);
  
  _work_steps.push_back({titleString, [&]() {
                           Ref<HTTPClient> http = memnew(HTTPClient);
                           String host_url("https://storage.googleapis.com");
                           String request_path("/dart-archive/channels/stable/release/" DART_VERSION
                                               "/sdk/dartsdk-windows-x64-release.zip");
                           http->connect_to_host(host_url);

                           HTTPClient::Status status = http->get_status();
                           while (status == HTTPClient::STATUS_CONNECTING || status == HTTPClient::STATUS_RESOLVING) {
                             http->poll();
                             _sleep(250);
                             status = http->get_status();
                           }

                           if (status != HTTPClient::STATUS_CONNECTED) {
                             return false;
                           }

                           PackedStringArray headers(
                               {String("user-Agent: GodotDart/1.0 (Godot)"), String("Accept: */*")});

                           Error err = http->request(HTTPClient::METHOD_GET, request_path, headers);
                           if (err != Error::OK) {
                             return false;
                           }

                           status = http->get_status();
                           while (status == HTTPClient::STATUS_REQUESTING) {
                             http->poll();
                             _sleep(250);
                             status = http->get_status();
                           }

                           if (status != HTTPClient::STATUS_BODY && status != HTTPClient::STATUS_CONNECTED) {
                             return false;
                           }
                           if (http->get_response_code() != 200) {
                             return false;
                           }

                           // Open up the result file
                           EditorPaths *editor_paths = get_editor_interface()->get_editor_paths();
                           String dart_user_path = editor_paths->get_data_dir().path_join("dart");

                           DirAccess::make_dir_recursive_absolute(dart_user_path);
                           String download_file = dart_user_path.path_join("dartsdk_" DART_VERSION ".zip");
                           Ref<FileAccess> file = FileAccess::open(download_file, FileAccess::ModeFlags::WRITE);

                           int body_length = http->get_response_body_length();

                           int total_size = 0;
                           while (http->get_status() == HTTPClient::STATUS_BODY) {
                             http->poll();
                             PackedByteArray body = http->read_response_body_chunk();
                             if (body.size() == 0) {
                               _sleep(250);
                               continue;
                             }
                             file->store_buffer(body);
                             total_size += body.size();

                             float percent_complete = 0.0f;
                             if (body_length == 0) {
                               percent_complete = total_size;
                             } else {
                               percent_complete = float(total_size) / body_length * 100.0f;
                             }
                             Callable(_progress_dialog, "set_progress").call_deferred(percent_complete);
                           }

                           file->flush();
                           file->close();

                           return true;
                         }});

  _work_steps.push_back({String("Unzipping Dart SDK"), [&] {
                           Ref<ZIPReader> zip_reader = memnew(ZIPReader);
                           EditorPaths *editor_paths = get_editor_interface()->get_editor_paths();
                           String dart_user_path = editor_paths->get_data_dir().path_join("dart");

                           DirAccess::make_dir_recursive_absolute(dart_user_path);
                           Ref<DirAccess> root_dir = DirAccess::open(dart_user_path);
                           String download_file = dart_user_path.path_join("dartsdk_" DART_VERSION ".zip");
                           zip_reader->open(download_file);

                           // TODO: If `dart-sdk` already exists, delete it

                           PackedStringArray files = zip_reader->get_files();
                           for (int i = 0; i < files.size(); ++i) {
                             String file_path = files[i];
                             if (file_path.ends_with("/")) {
                               root_dir->make_dir_recursive(file_path);
                               continue;
                             }

                             String full_file_path = dart_user_path.path_join(file_path);
                             root_dir->make_dir_recursive(full_file_path.get_base_dir());
                             Ref<FileAccess> dest_file = FileAccess::open(full_file_path, FileAccess::ModeFlags::WRITE);
                             PackedByteArray buffer = zip_reader->read_file(file_path);
                             dest_file->store_buffer(buffer);

                             float percent_complete = float(i) / files.size() * 100.0f;
                             Callable(_progress_dialog, "set_progress").call_deferred(percent_complete);
                           }

                           // Move `dart-sdk` to version directory
                           root_dir->rename(String("dart-sdk"), String(DART_VERSION));

                           // Be nice and delete the zip
                           root_dir->remove(download_file);

                           create_dart_command_runner();
                           push_build_work();

                           return true;
                         }});

  _plugin_work_thread.instantiate();
  _plugin_work_thread->start(Callable(this, "run_work"));
}

void GodotDartEditorPlugin::create_dart_command_runner() {
  EditorPaths *editor_paths = get_editor_interface()->get_editor_paths();
  String dart_sdk_path = editor_paths->get_data_dir().path_join("dart/" DART_VERSION);

  GodotDartRuntimePlugin *rtplugin = GodotDartRuntimePlugin::get_instance();
  String root_dir_str(rtplugin->get_root_dart_dir().c_str());

  _command_runner = new godot_dart::DartCommandRunner(dart_sdk_path, root_dir_str);
}

void GodotDartEditorPlugin::push_build_work() {
  assert(_command_runner);

 /* _work_steps.push_back({String("Running dart pub get"), [&] { return _command_runner->pub_get() == 0; }});
  _work_steps.push_back(
      {String("Running dart build_runner build"), [&] { return _command_runner->dart_build_runner() == 0; }});
  _work_steps.push_back({String("Running Dart compile"), [&] { return _command_runner->build_dill() == 0; }});
  _work_steps.push_back({String("Initializing Godot Dart"), [&]() {
                           GodotDartRuntimePlugin *rtplugin = GodotDartRuntimePlugin::get_instance();
                           rtplugin->initialize_dart_bindings();

                           return true;
                         }});*/
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

                           push_build_work();

                           return true;
                         }});

  /*_work_steps.push_back({String("Running dart pub get"), [&]() { return run_pub_get(); }});

  _work_steps.push_back({String("Running dart run build_runner build"), [&]() { return run_build_runner(); }});

  _work_steps.push_back({String("Reinitializing Godot Dart"), [&]() {
                           GodotDartRuntimePlugin *rtplugin = GodotDartRuntimePlugin::get_instance();
                           rtplugin->initialize_dart_bindings();

                           return true;
                         }});*/

  _plugin_work_thread.instantiate();
  _plugin_work_thread->start(Callable(this, "run_work"));
}

void GodotDartEditorPlugin::run_work() {
  Callable(_progress_dialog, "popup_centered").call_deferred();

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

void GodotDartEditorPlugin::hot_reload() {
  GodotDartBindings::instance()->reload_code();
}