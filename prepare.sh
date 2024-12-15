#!/usr/bin/env bash
# This script runs setup boilerplate on all the projects
# in the repo, just to make onboarding easier. There should
# not be an issue running this multiple times.

[[ $(type -P "dart") ]] || { echo "Could not find dart in your path. It's needed."; exit 1; }

dart ./tools/fetch_dart/bin/fetch_dart.dart

pushd src/dart/godot_dart
dart pub get
dart run ffigen
popd

pushd src/dart/godot_dart_build
dart pub get
popd

pushd tools/binding_generator
dart ./bin/binding_generator.dart
popd

pushd example/2d_tutorial/src
dart pub get
dart run build_runner build
popd

pushd example/networking-demo/src
dart pub get
dart run build_runner build
popd
