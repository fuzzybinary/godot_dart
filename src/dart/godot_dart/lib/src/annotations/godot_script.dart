import 'package:meta/meta.dart';

/// An annotation that specifies that this class should be used as a Godot
/// script.
@immutable
class GodotScript {
  const GodotScript();
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
