#pragma once

#include <godot_cpp/classes/window.hpp>

namespace godot {
  class Label;
  class ProgressBar;
  class VBoxContainer;
}

class ProgressDialog : public godot::Window {
  GDCLASS(ProgressDialog, godot::Window);

public:
  ProgressDialog();
  ~ProgressDialog();
  
  void set_text(const godot::String &text);
  void set_progress(float percent);  

protected:
  static void _bind_methods();

private:
  godot::VBoxContainer *vbox;
  godot::Label *label;
  godot::ProgressBar *progress_bar;
};