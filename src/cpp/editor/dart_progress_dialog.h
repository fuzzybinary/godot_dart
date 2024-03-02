#pragma once

#include <godot_cpp/classes/window.hpp>

namespace godot {
  class Label;
  class ProgressBar;
  class VBoxContainer;
}

class DartProgressDialog : public godot::Window {
  GDCLASS(DartProgressDialog, godot::Window);

public:
  DartProgressDialog();
  ~DartProgressDialog();
  
  void set_text(const godot::String &text);
  void set_progress(float percent);  

protected:
  static void _bind_methods();

private:
  godot::VBoxContainer *vbox;
  godot::Label *label;
  godot::ProgressBar *progress_bar;
};