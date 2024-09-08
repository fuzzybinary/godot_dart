# GodotDart

An attempt to be able to use Dart as a scripting language for Godot.

Because I like Dart.

And I want to use it in Godot.

# Current State

> [!NOTE]  
> This extension is compatible with Godot 4.2+


Here's a list of planned features and work still to be done ( ✅ - Seems to be
working, 🟨 - Partially working, ❌ - Not working)

| Feature | Support | Note |
| ------- | :-----: | ---- |
| Dart as a Godot Extension Language | 🟨 |  |
| Dart Debugging Extension | ✅ | Attach to `http://127.0.0.1:5858` |
| Dart Available as a Scripting Language | 🟨 | Very early implementation |
| Hot Reload | ✅ | Reloading from Godot will reload the Dart module. |
| Simplified Binding using build_runner | 🟨 | Early implementation | 
| Dart native Variants | ❌ | Needed for performance reasons |
| Memory efficiency / Leak prevention | ✅ | All RefCounted objects appear to be working correclty. |
| Godot Editor inspector integration | ❌ | |
| Godot Editor -> Dart LSP Integration | ❌ | |
| Dart Macro Support | ❌| |

# Setup

You can now download a usable extension zip from out [Github Actions](https://github.com/fuzzybinary/dart_shared_library/actions).

Unzip this into a Godot project, then run `dart pub get` in the `./src` directory before relaunching Godot.

You should now be able to create Dart scripts from Godot.

Note, I recommend editing your code in another IDE (I use VSCode) and have `build_runner` watching your code to regenerate the
required files on save.  When you return to Godot, clicking `Reload` for the modified files will also trigger a Dart hot-reload,
and all of your properties will be available in the Godot editor.

# Setup From source

See [CONTRIBUTING.md](CONTRIBUTING.md)

# Using

Note there are two ways to use Dart with Godot: as an extension language and as
a Script language. Both are only partially implemented

## Dart classes as Scripts

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

## Dart classes as Extensions

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

## Deviations from Godot code

### Casting

When you are working with a Godot object, do not use `is` or `as` to perform downcasting. This will
always fail because of how Godot extension works. Instead, use `.cast<T>`, which will return `null`
if the cast fails.

### Virtual functions

Godot prefixes virtual functions with `_`, which obviously Dart doesn't like. I wanted to have
these just remove the `_`, but this creates some conflicts with methods that have the same names.

So instead, Godot Dart prefixes all virtual methods with `v`.

### Indirectly Calling Godot Functions

The Dart API uses `lowerPascalCase` instead of `snake_case` in GDScript/C++. Where possible, fields and getters/setters have been converted to properties. In general, the Dart Godot API strives to be as idiomatic as is reasonably possible.

However, Godot still thinks of these methods as being named in `snake_case`, so if you are calling them by their name (for example)
when using `call`, `callDeferred`, `connect`, or `callGroup`, you need to use `snake_case` for the method name.

Basically, if you defined the method, use `lowerPascalCase`. If Godot defined the method, use `snake_case`. And if Godot defined
the method and its virtual, use `_snake_case` instead of `vPascalCase` currently used in Dart.

# More Info

This utilizes my custom built Dart shared library for embedding Dart, the source
for which is available [here](https://github.com/fuzzybinary/dart_shared_libray). 
I've included the win64 prebuilt binaries in this repo for simplicity.
