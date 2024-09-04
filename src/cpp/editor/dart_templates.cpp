#include <string>

const char *main_template = "import 'package:godot_dart/godot_dart.dart';\n"
                            "\n"
                            "import 'godot_dart_scripts.g.dart';\n"
                            "\n"
                            "void main() {\n"
                            "  attachScriptResolver();\n"
                            "}\n"
                            "\n";

// FIXME: Either use pub.dev or ship the dart code in the extension
const char *pubspec_template_fmt = "name: my_godot_dart\n"
                                   "description: A godot_dart project\n"
                                   "version: 1.0.0\n"
                                   "publish_to: none\n"
                                   "environment:\n"
                                   "  sdk: '>=3.0.0 <4.0.0'\n"
                                   "\n"
                                   "dependencies:\n"
                                   "  ffi : ^2.0.1\n"
                                   "  godot_dart:\n"
                                   "      path: ../../../src/dart/godot_dart\n"
                                   "  collection : ^1.17.2\n"
                                   "\n"
                                   "dev_dependencies:\n"
                                   "  lints: ^2.0.0\n"
                                   "  build_runner: ^2.3.3\n"
                                   "  godot_dart_build:\n"
                                   "      path: ../../../src/dart/godot_dart_build\n"
                                   "\n";

const char *git_ignore_template = "# Files and directories created by pub\n"
                                  ".dart_tool/\n"
                                  ".packages\n"
                                  "\n"
                                  "# Don't check in generated files\n"
                                  "*.g.dart\n"
                                  "\n";


const char *dart_script = "import 'dart:ffi';\n"
                          "\n"
                          "import 'package:godot_dart/godot_dart.dart';\n"
                          "\n"
                          "part '__FILE_NAME__.g.dart';\n"
                          "\n"
                          "@GodotScript()\n"
                          "class __CLASS_NAME__ extends __BASE_CLASS__ {\n"
                          "  static TypeInfo get sTypeInfo => _$__CLASS_NAME__TypeInfo();\n"
                          "  @override\n"
                          "  TypeInfo get typeInfo => sTypeInfo;\n"
                          "\n"
                          "  __CLASS_NAME__() : super();\n"
                          "\n"
                          "  __CLASS_NAME__.withNonNullOwner(Pointer<Void> owner)\n"
                          "    :super.withNonNullOwner(owner);\n"
                          "\n"
                          "  @override\n"
                          "  void vReady() {\n"
                          "    \n"
                          "  }\n"
                          "\n"
                          "  @override\n"
                          "  void vProcess(double delta) {\n"
                          "\n"
                          "  }\n"
                          "}\n"
                          "\n";