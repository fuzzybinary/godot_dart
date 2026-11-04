## Overview

This package is only for use with [Godot Dart](https://github.com/fuzzybinary/godot_dart)

## Tests

The property hint tests run the builder on Dart scripts and check the generated
metadata, including automatic hints and string escaping. They do not launch Godot
or require the compiled C++ extension.

When testing changes to the local `godot_dart` package, use the path override in
`pubspec_overrides.yaml`. First generate the Dart bindings as described in
[CONTRIBUTING.md](../../../CONTRIBUTING.md). Then, from this directory, run:

```sh
dart pub get
dart test test/property_hints_test.dart
```

To check the editor integration manually, expose a numeric property with
`hint: PropertyHint.range, hintString: '0,1000,10'`, regenerate the script bindings,
and verify that the inspector offers the configured range and step.
