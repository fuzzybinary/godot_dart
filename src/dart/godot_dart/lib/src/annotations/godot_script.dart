import 'package:meta/meta.dart';

import '../gen/engine_classes.dart';

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

@immutable
class SignalArgument {
  final String name;
  final Type type;

  const SignalArgument(this.name, this.type);
}

/// Annotate a Godot Signal
///
/// Signals must be a variable of one of the `SignalX` types, such as [Signal0], [Signal1], etc.
/// The name of the signal is taken from `name` parameter of the Signal.
@immutable
class GodotSignal {
  const GodotSignal();
}

/// Annotate a field that should be visible to the Godot property inspector
@immutable
class GodotProperty {
  final String? name;

  // TODO: Property Hints
  const GodotProperty({this.name});
}

@immutable
class GodotRpc {
  final MultiplayerAPIRPCMode mode;
  final bool callLocal;
  final MultiplayerPeerTransferMode transferMode;
  final int transferChannel;

  const GodotRpc({
    this.mode = MultiplayerAPIRPCMode.rpcModeAuthority,
    this.callLocal = false,
    this.transferMode = MultiplayerPeerTransferMode.reliable,
    this.transferChannel = 0,
  });
}
