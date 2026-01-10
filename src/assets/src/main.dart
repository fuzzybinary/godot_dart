import 'godot_dart_scripts.g.dart';

void main() {
  refreshScripts();
}

// This function will be called after a hot reload to ensure that
// new scripts are added to Godot Dart's type resolver.
@pragma('vm:entry-point')
void refreshScripts() {
  populateScriptResolver();
}
