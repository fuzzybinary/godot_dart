# GodotDart

An attempt to be able to use Dart as a scripting language for Godot.

Because I like Dart.

And I want to use it in Godot.

# Current State

> [!NOTE]  
> This extension is compatible with Godot 4.2+. Global Classes require Godot 4.3


Here's a list of planned features and work still to be done ( ✅ - Seems to be
working, 🟨 - Partially working, ❌ - Not working)

| Feature | Support | Note |
| ------- | :-----: | ---- |
| Dart as a Godot Extension Language | 🟨 |  |
| Dart Debugging (VS Code) | ⚠ | See [Debugging](#debugging) |
| Dart Available as a Scripting Language | 🟨 | Mostly usable in personal testing |
| Hot Reload | ✅ | Hot Reload button now included. |
| Simplified Binding using build_runner | 🟨 | Early implementation | 
| Dart native Variants | ❌ | Needed for performance reasons, Vector2 and Vector3 are done |
| Memory efficiency / Leak prevention | ✅ | All RefCounted objects appear to be working correclty. |
| Godot Editor inspector integration | ❌ | |
| Godot Editor -> Dart LSP Integration | ❌ | |
| Augmentation Support | ❌| |

# Setup

You can now download a usable extension zip from out [Github Actions](https://github.com/fuzzybinary/godot_dart/actions).

Unzip this into a Godot project, then run `dart pub get` in the `./src` directory before relaunching Godot.

You should now be able to create Dart scripts from Godot.

Note, I recommend editing your code in another IDE (I use VSCode) and have `build_runner` watching your code to regenerate the
required files on save.  When you return to Godot, clicking `Reload` for the modified files will also trigger a Dart hot-reload,
and all of your properties will be available in the Godot editor.

# Setup From source

See [CONTRIBUTING.md](CONTRIBUTING.md)

# Using

Note there are two ways to use Dart with Godot: as an extension language and as
a Script language. Both are only partially implemented.

## Dart classes as Scripts

Scripts can then be attached to exiting nodes, just like any other GDScript.
You should be able to create a Dart script by using the "Attach Script" command
in the editor. This will create the necessary boilerplate for a Dart script.

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

  // Overridden virtuals are added automatically via build_runner
  @override
  void vReady() {}

  @override
  void vProcess(double delta) {}

  // You can also export methods for RPC
  @GodotRpc(mode: MultiplayerAPIRPCMode.rpcModeAnyPeer, callLocal: true)
  void rpcMesssage(String message) {}

  // Any method that needs to be seen by a signal needs to be exported
  @GodotExport()
  void onSignal() {
    // To call an RPC as an RPC you use the $rpc variable
    $rpc.rpcMessage('message');
  }
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

### Signals

You can add signals to your script with the `GodotSignal` property. This takes the signal name and a list 
of arguments for the signal:

```dart
@GodotScript()
class Hud extends CanvasLayer {
  //...

  
  @GodotSignal('start_game')
  late final Signal _startGame = Signal.fromObjectSignal(this, 'start_game');
}
```

You can then emit signals with `Signal.emit`.

Classes from Godot support type safe signal subscription for each or their signals.  For example, if you
want to subscribe to the `animation_added` signal on `AnimationLibrary`, you can do so like so:

```dart
@GodotScript()
class MyClass extends Node {
  @override
  void vReady() {
    final animationLibrary = getNodeT<AnimationLibrary>('AnimationLibrary');
    animationLibrary.animationAdded.connect(this, _animationAdded);
  }

  void _animationAdded(String name) {
    // ...
  }
}
```

These signal connections are automatically cleaned up if the target supplied to `connect` is removed.


## Dart classes as Extensions

Here's a Simple example class that can be used as an extension.

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

Early versions of Godot Dart required using `.cast<T>` to perform downcasting. This is no longer
necessary. Dart's built in `is` and `as` operators should now work to perform downcasting. `cast<T>` 
has also been removed and replaced with `.as<T>`, which is an implementation of `as?` or `dynamic_cast`.

### Virtual functions

Godot prefixes virtual functions with `_`, which obviously Dart doesn't like. I wanted to have
these just remove the `_`, but this creates some conflicts with methods that have the same names.

So instead, Godot Dart prefixes all virtual methods with `v`.

### Indirectly Calling Godot Functions

The Dart API uses `lowerPascalCase` instead of `snake_case` in GDScript/C++. In general, the Dart Godot API 
strives to be as idiomatic as is reasonably possible.

However, Godot still thinks of these methods as being named in `snake_case`, so if you are calling them by their name
when using `call`, `callDeferred`, `connect`, or `callGroup`, you need to use `snake_case` for the method name.

Basically, if you defined the method, use `lowerPascalCase`. If Godot defined the method, use `snake_case`. And if Godot defined
the method and its virtual, use `_snake_case` instead of `vPascalCase` currently used in Dart.

### Lack of Properties

While Dart supports properties, I have specifically not converted Godot fields to Dart properties, and instead leave them
with `getX` and `setX` methods.

This is to avoid [this issue](https://docs.godotengine.org/en/stable/tutorials/scripting/c_sharp/c_sharp_basics.html#common-pitfalls),
which is common with this type of embedding. For example: 

```dart
// The `x` property on the vector is set, but the `position` is not changed because the position 
// setter is never called, therefore the change is never broadcast back to Godot
position.x += 5
```

The common workaround for this is to do this:

```dart
final pos = position;
pos.x = 5;
position = pos;
```

But in my opinion, this defeats the purpose of wrapping properties. Properties
should mimic public member variables, and, when they can't, use methods instead.

# Debugging

Because of a change in the Dart SDK, you currently need to run the Dart Dev Service (DDS) in order to debug your game or Dart code in the Godot editor. To do so, with your game running, run the following in a terminal:

```
dart development-service --vm-service-uri=http://127.0.0.1:5858
```

I'm looking into ways to improve this experience in the long term.

# Performance

I have not measured the performance of this extension, partially because I know there is a lot of space for improvement in the
embedding library itself, as well as in how the built in types are currently built.

Once I've performed an optimization pass on the library, I'll look into measuring its performance.

# Memory

See [Memory](docs/memory.md)

# More Info

This utilizes my custom built Dart shared library for embedding Dart, the source
for which is available [here](https://github.com/fuzzybinary/dart_shared_libray). 
I've included the win64 prebuilt binaries in this repo for simplicity.
