# GodotDart

An attempt to be able to use Dart as a scripting language for Godot.

Because I like Dart.

And I want to use it in Godot.

# Current State

> [!WARNING]  
> The current `master` branch of this extension is unstable after a massive rewrite of `Variant` that is ongoing.

> [!NOTE]  
> This extension is compatible with Godot 4.2+


Here's a list of planned features and work still to be done ( ✅ - Seems to be
working, 🟨 - Partially working, ❌ - Not working)

| Feature | Support | Note |
| ------- | :-----: | ---- |
| Dart as a Godot Extension Language | 🟨 |  |
| Dart Debugging Extension | ✅ | Attach to `http://127.0.0.1:5858` |
| Dart Available as a Scripting Language | 🟨 | Very early implementation |
| Hot Reload | ❌ | |
| Simplified Binding using build_runner | 🟨 | Early implementation | 
| Dart native Variants | ❌ | Needed for performance reasons |
| Memory efficiency / Leak prevention | ❌ | |


Some notes about the current state:
* The binding is likely leaking both Dart objects and native allocations. I
  intend on making a pass through to make sure all of that is cleaned up at some
  point and correctly utilizes native finalizers.

# Using

> [!NOTE]  
> This extension is compatible with Godot 4.2+ x64 and has been tested for Linux and Windows


## Things you will need

* A clone of this repo.
* Dart 3.0 stable
* Godot 4.2.x - Note above the pending pull request.
* A build of the [Dart Shared
  Library](https://github.com/fuzzybinary/dart_shared_libray). Windows x64 .dlls
  for Dart 3 are provided in `src/dart_dll/bin/win64`.
* CMake 3.21+

## Current Setup

To use the extension, you need to:

* Copy both your `dart_dll` dynamic library and the `godot_dart` dynamic library
  to your project directory.
* Copy `example/2d_tutorial/example.gdextension` to your project directory (note
  this is only configured for `windows.64` builds and will need to be modified
  for any other OS).
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

You should now be able to write Dart code for Godot! 

Note there are two ways to use Dart with Godot: as an extension language and as
a Script language. Both are only partially implemented

### Dart classes as Extensions

There are requirements for almost any Godot accessible Dart class. Here's a Simple
example class

```dart
class Simple extends Sprite2D {
  // Create a static `sTypeInfo`. This is required for various Dart methods
  // implemented in C++ to gather information about your type.
  static late TypeInfo sTypeInfo = TypeInfo(
    Simple,
    StringName.fromString('Simple'),
    parentClass: StringName.fromString('Sprite2D'),
    // a vTable getter is required for classes that will be used from extensions.
    // If you are not adding any virtual functions, just return the base class's vTable.
    // If the class is only used from scripts, this is likely not necessary.
    vTable: Sprite2D.sTypeInfo.vTable;
  );
  // An override of [typeInfo] is required. This is how
  // the bindings understand the what types it's looking at.
  @override
  TypeInfo get typeInfo => sTypeInfo;

  double _timePassed = 0.0;

  // Parameterless constructor is required and must call super()
  Simple() : super();
  
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
    gde.dartBindings.bindClass(Simple);  
  }
}
```

Dart classes used as an Extension will appear as creatable in the "Create New
Node" interface, but aren't editable or attachable to existing nodes. At the
moment, you will need to restart the editor for your new classes to appear.

These classes need to be registered to Godot in `main.dart`:

```dart
void main() {
  Simple.bind();
}
```

### Dart classes as Scripts

Scripts require a little bit more setup, but can then be attached to exiting
nodes, just like any other GDScript.  You should be able to create a Dart script
by using the "Attach Script" command in the editor. This will create the
necessary boilerplate for a Dart Script.

While not required, the easiest way to create a scripts is to use `build_runner`
and the `godot_dart_builder` package. After creating your script, run `build_runner`
and the necessary boilerplate will be generated.


```dart
// Include the <file>.g.dart with the generated code
part 'simple_script.g.dart';

// Generate the boilerplate for this object to be an accessible Godot script
@GodotScript()
class SimpleScript extends Sprite2D  {
  // Return the type info that was generated...
  static TypeInfo get sTypeInfo => _$SimpleScriptTypeInfo();
  // And provide an instance method to get the type info
  @override
  TypeInfo get typeInfo => SimpleScript.sTypeInfo;
  
  // Required constructor
  SimpleScript() : super();

  // Second required contructor. Classes that are Scripts must have a named constructor 
  // called `withNonNullOwner`.
  SimpleScript.withNonNullOwner(Pointer<Void> owner)
      : super.withNonNullOwner(owner);

  // You can export fields as properties
  @GodotProperty()
  int speed = 400

  // Any method that needs to be seen by a signal needs to be exported
  @GodotExport()
  void onSignal() {

  }

  // Overridden virtuals are added automatically via build_runner
  @override
  void vReady() {}

  @override
  void vProcess(double delta) {}
}
```

`build_runner` will also generate a registration file that must be imported into your
`main.dart`, and its script resolver will need to be attached:

```dart
import 'godot_dart_scripts.g.dart';

void main() {
  // ... other bindings

  attachScriptResolver();
}
```

# More Info

This utilizes my custom built Dart shared library for embedding Dart, the source
for which is available [here](https://github.com/fuzzybinary/dart_shared_libray). 
I've included the win64 prebuilt binaries in this repo for simplicity.
