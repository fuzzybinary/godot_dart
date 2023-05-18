# GodotDart

An attempt to be able to use Dart as a scripting language for Godot.

Because I like Dart.

And I want to use it in Godot.

# Current State

Currently, Dart can be initialized as a language usable as a GDExtension, but
not as a scripting language. This means you can create Dart classes and Nodes
and add them to you scene tree, and they will execute both in editor and in
game.

Here's a list of planned features and work still to be done ( ✅ - Seems to be
working, 🟨 - Partially working, ❌ - Not working)

| Feature | Support | Note |
| ------- | :-----: | ---- |
| Dart as a Godot Extension Language | 🟨 |  |
| Ref counted object support | ❌ | |
| Dart Debugging Extension | ✅ | Attach to `http://127.0.0.1:5858` |
| Dart Available as a Scripting Language | ❌ |
| Hot Reload | ❌ | |
| Simplified Binding using build_runner | ❌ |  | 
| Dart native Variants | ❌ | Needed for performance reasons |
| Memory efficiency / Leak prevention | ❌ | |


Some notes about the current state:
* The binding is likely leaking both Dart objects and native allocations. I
  intend on making a pass through to make sure all of that is cleaned up at some
  point and correctly utilize native finalizers.
* Right now Godot will crash on exit because the binding isn't cleaning up after
  itself and it tried to free Dart objects after Dart has aready been shut down. 

# Using

```
I have only tested this on Windows. I know for certain it will only work on 'float_64' builds of Godot.
```

## Things you will need

* A clone of this repo.
* Dart (2.19 Current Stable, not tested with 3.0)
* Godot 4.0.2 or a custom build compatible with 4.0.2
* A build of the [Dart Shared
  Library](https://github.com/fuzzybinary/dart_shared_libray). Windows x64 .dlls
  for Dart 2.19 are provided in `src/dart_dll/bin/win64`.
* A way to build `src/cpp`. A Visual Studio solution is provided if you have
  Visual Studio. If not, use your favorite tool to build the provided files.

## Current Setup

To use the extension, you need to:

* Copy both your `dart_dll` dynamic library and the `godot_dart` dynamic library
  to your project directory.
* Copy `simple/example.gdextension` to your project directory (note this is only
  configured for `windows.64` builds and will need to be modified for any other
  OS).
* Create a `src` directory in your project directory to hold your Dart code.
  This should be a proper Dart package, complete with a `pubspec.yaml` file. Add
  a `main.dart` to this directory.
* Run the Binding Generator
```bash
# From tools/binding_generator
dart ./bin/binding_generator.dart
```
* Add a reference to the `godot_dart` package that is defined in `src/dart`. You
  will need to use a path dependency for this for now.
* Add a `main` function to your `main.dart`. This is where you will register
  your Godot classes

You should now be able to write Dart code for Godot! But, there are some
requirements for any Godot accessible Dart class. Here's the Simple example
class in `simple/src/simple.dart`

```dart
class Simple extends Sprite2D {
  // It's best to statically create a TypeInfo for your class:
  static late TypeInfo sTypeInfo = TypeInfo(
    StringName.fromString('Simple'),
    parentClass: StringName.fromString('Sprite2D'),
  );
  // a vTable getter is required for classes that will be used from extensions.
  // If you are not adding any virtual functions, just return the base class's vTable.
  // If the class is only used from scripts, this is likely not necessary.
  static Map<String, Pointer<GodotVirtualFunction>> get vTable =>
      Sprite2D.vTable;

  // An override of [typeInfo] is required. This is how
  // the bindings understand the what types it's looking at.
  @override
  TypeInfo get typeInfo => sTypeInfo;

  double _timePassed = 0.0;

  // Constructor is required and MUST call [postInitialize] for all classes usable
  // from an extension.
  Simple() : super() {
    postInitialize();
  }
  // Classes that are Scripts must have a named constructor

  // All virtual functions from Godot should be available, and start
  // with a v instead of an underscore.
  @override
  void vProcess(double delta) {
    _timePassed += delta;

    final x = 10.0 + (10.0 * sin(_timePassed * 2.0));
    final y = 10.0 + (10.0 * cos(_timePassed * 2.0));
    final newPosition = Vector2.fromXY(x, y);
    print('vProcess - $x, $y, ${newPosition.x}, ${newPosition.y}');
    setPosition(newPosition);
  }

  // The simplest way to bind your class it to create a static function to
  // bind it to Godot. The name doesn't matter
  static void bind() {
    gde.dartBindings.bindClass(Simple, Simple.typeInfo);  
  }
}
```

Classes need to be registered to Godot in `main.dart`:

```dart
void main() {
  Simple.bind();
}
```

I know this is a very complicated setup. I'll be looking to simplify it in the
future once more features are working.

# More Info

This utilizes my custom built Dart shared library for embedding Dart, the source
for which is available
[here](https://github.com/fuzzybinary/dart_shared_libray). I've included the
win64 prebuilt binaries in this repo for simplicity.
