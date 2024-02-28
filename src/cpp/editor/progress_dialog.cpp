#include "progress_dialog.h"

#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/label.hpp>
#include <godot_cpp/classes/panel.hpp>
#include <godot_cpp/classes/progress_bar.hpp>
#include <godot_cpp/classes/v_box_container.hpp>

using namespace godot;

ProgressDialog::ProgressDialog() : vbox(nullptr), label(nullptr), progress_bar(nullptr) {
  set_wrap_controls(true);
  set_transient(true);
  set_exclusive(true);
  set_keep_title_visible(true);
  set_visible(false);
  set_flag(Window::FLAG_BORDERLESS, true);

  vbox = memnew(VBoxContainer);
  vbox->add_spacer(true);
  add_child(vbox, INTERNAL_MODE_FRONT);

  label = memnew(Label);
  vbox->add_child(label, false, INTERNAL_MODE_FRONT);

  progress_bar = memnew(ProgressBar);
  vbox->add_spacer(true);
  vbox->add_child(progress_bar, false, INTERNAL_MODE_FRONT);

  set_title("Godot Dart Progress");
  child_controls_changed();
}

ProgressDialog::~ProgressDialog() {
}

void ProgressDialog::_bind_methods() {
  ClassDB::bind_method(godot::D_METHOD("set_text"), &ProgressDialog::set_text);
  ClassDB::bind_method(godot::D_METHOD("set_progress"), &ProgressDialog::set_progress);
}

void ProgressDialog::set_text(const godot::String &text) {
  label->set_text(text);
  child_controls_changed();
}

void ProgressDialog::set_progress(float percent) {
  progress_bar->set_value_no_signal(percent);
  child_controls_changed();
}
