import 'godot_dart_scripts.g.dart';

void main() {
  refreshScripts();
}

@pragma('vm:entry-point')
void refreshScripts() {
  populateScriptResolver();
}
