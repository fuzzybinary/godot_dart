#include "dart_resource_format.h"

#include <godot_cpp/classes/resource_loader.hpp>
#include <godot_cpp/classes/file_access.hpp>

#include "dart_script_language.h"
#include "dart_script.h"

using namespace godot;

// ResourceFormatLoader

DartResourceFormatLoader::DartResourceFormatLoader() {

}

void DartResourceFormatLoader::_bind_methods() {
}

bool DartResourceFormatLoader::_handles_type(const godot::StringName &type) const {
  return type == StringName("Script") || type == StringName("DartScript");
}

godot::PackedStringArray DartResourceFormatLoader::_get_recognized_extensions() const {
  PackedStringArray array;
  array.push_back("dart");
  return array;
}

bool DartResourceFormatLoader::_recognize_path(const godot::String &path, const godot::StringName &type) const {
  return path.ends_with(".dart");
}

godot::String DartResourceFormatLoader::_get_resource_type(const godot::String &path) const {
  String extension = path.get_extension();

  return extension == String(".dart") ? String("DartScript") : String();
}

godot::String DartResourceFormatLoader::_get_resource_script_class(const godot::String &path) const {
  return String("DartScript");
}

bool DartResourceFormatLoader::_exists(const godot::String &path) const {
  return FileAccess::file_exists(path);
}

godot::Variant DartResourceFormatLoader::_load(const godot::String &path, const godot::String &original_path,
                                               bool use_sub_threads, int32_t cache_mode) const {
  DartScriptLanguage *language = DartScriptLanguage::instance();
  Ref<DartScript> script = language->get_cached_script(path);
  if (script.is_null()) {
    script = Ref<DartScript>(language->_create_script());
    if (script.is_null()) {
      return Variant();
    }

    language->push_cached_script(path, script);
    script->load_from_disk(original_path);
  } else if (cache_mode == ResourceLoader::CACHE_MODE_IGNORE) {
    script->load_from_disk(original_path);
  }
  script->set_path(original_path);

  return Variant(script.ptr());
}

// ResourceFormatSaver

void DartResourceFormatSaver::_bind_methods() {
}


godot::Error DartResourceFormatSaver::_save(const godot::Ref<godot::Resource> &resource, const godot::String &path,
                                            uint32_t flags) {
  Ref<DartScript> script = Object::cast_to<DartScript>(resource.ptr());
  if (script.is_null()) {
    return ERR_BUG;
  }

  Ref<FileAccess> file = FileAccess::open(path, FileAccess::ModeFlags::WRITE);
  if (file.is_null()) {
    return ERR_BUG;
  }

  String source = script->get_source_code();
  file->store_string(source);
  if (file->get_error() != OK && file->get_error() != ERR_FILE_EOF) {
    return ERR_CANT_CREATE;
  }

  file->flush();
  file->close();

  return OK;
}

bool DartResourceFormatSaver::_recognize(const godot::Ref<godot::Resource> &resource) const {
  DartScript* script = Object::cast_to<DartScript>(resource.ptr());
  return script != nullptr;
}

bool DartResourceFormatSaver::_recognize_path(const godot::Ref<godot::Resource> &resource,
                                              const godot::String &path) const {
  return path.ends_with(".dart");
}

godot::PackedStringArray DartResourceFormatSaver::_get_recognized_extensions(
    const godot::Ref<godot::Resource> &resource) const {
  PackedStringArray array;
  array.push_back("dart");
  return array;
}
