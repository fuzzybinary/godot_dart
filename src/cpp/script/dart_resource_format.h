#pragma once

#include <map>

#include "dart_script.h"

#include <godot_cpp/classes/resource_format_loader.hpp>
#include <godot_cpp/classes/resource_format_saver.hpp>

class DartResourceFormatLoader : public godot::ResourceFormatLoader {
  GDCLASS(DartResourceFormatLoader, ResourceFormatLoader)

public:
  DartResourceFormatLoader();

  virtual bool _handles_type(const godot::StringName& type) const override;
  virtual godot::PackedStringArray _get_recognized_extensions() const override;
  virtual bool _recognize_path(const godot::String &path, const godot::StringName &type) const override;
  virtual godot::String _get_resource_type(const godot::String &path) const override;
  virtual godot::String _get_resource_script_class(const godot::String &path) const override;
  virtual bool _exists(const godot::String &path) const override;
  virtual godot::Variant _load(const godot::String &path, const godot::String &original_path, bool use_sub_threads,
                        int32_t cache_mode) const override;

protected:
  static void _bind_methods();

private:
};

class DartResourceFormatSaver : public godot::ResourceFormatSaver {
  GDCLASS(DartResourceFormatSaver, ResourceFormatSaver)

public:
  virtual godot::Error _save(const godot::Ref<godot::Resource> &resource, const godot::String &path, uint32_t flags);
  virtual bool _recognize(const godot::Ref<godot::Resource> &resource) const override;
  virtual bool _recognize_path(const godot::Ref<godot::Resource> &resource, const godot::String &path) const override;
  virtual godot::PackedStringArray _get_recognized_extensions(const godot::Ref<godot::Resource> &resource) const;

protected:
  static void _bind_methods();
};