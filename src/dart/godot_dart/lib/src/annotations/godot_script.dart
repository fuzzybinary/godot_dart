import 'package:meta/meta.dart';

/// An annotation that specifies that this class should be used as a Godot
/// script.
@immutable
class GodotScript {
  /// Whether this class is a Godot Global class instead of a script. See
  /// https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_global_classes.html
  /// for more information about Godot global classes
  final bool isGlobal;

  const GodotScript({this.isGlobal = false});
}

/// Export this method to Godot
@immutable
class GodotExport {
  // The name to export, if different
  final String? name;

  const GodotExport({this.name});
}

/// Annotate a Godot Signal
@immutable
class GodotSignal {
  final String signalName;

  const GodotSignal(this.signalName);
}

/// Annotate a field that should be visible to the Godot property inspector
@immutable
class GodotProperty {
  final String? name;

  // TODO: Property Hints
  const GodotProperty({this.name});
}
