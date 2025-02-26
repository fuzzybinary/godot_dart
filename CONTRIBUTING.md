Contributions are welcome!

But, please, before you do reach out to me on Mastodon
[@fuzzybinary@mastodon.gamedev.place](https://mastodon.gamedev.place/@fuzzybinary).
I'll let you know what I'm currently working on and where I could use some help.

The rest of this document helps me / you understand how to build the extension.

## Getting Started

Most of the following steps are now performed by the shell script at the root of the repository.
So you can now run:

```bash
./prepare.sh
```

To prepare the repository.

### Updating the Dart SDK

The Dart SDK dynamic libraries must be downloaded before you can work with this repo. There is a Dart
script to do this in `tools/fetch_dart`.

```bash
# From the root of the repo:
dart ./tools/fetch_dart/bin/fetch_dart.dart
```

You can manually update the version of dart by building the
[dart_shared_library](https://github.com/fuzzybinary/dart_shared_library) repo
and adding the `--local` parameter to the script. Note this will only copy the
current platform's dynamic library to the destination.

### Updating FFI Bindings

This repo uses (godot-cpp)[https://github.com/godotengine/godot-cpp/] to make working with GDExtension
easier. This is included as a submodule at `./godot-cpp` and includes both the GDExtension
header as well as the GDExtension API json file. 

To update to more recent versions of `godot-cpp` or GDExtension, checkout a more recent version of `godot-cpp`
and generate the FFI bindings using Dart's ffigen tool. 

From the `/src/dart/godot_dart` directory run:

```bash
dart run ffigen
```

This will regenerate `/dart/lib/src/core/gdextension_ffi_bindings.dart`

### Regenerating Class Files

The `binding_generator` tool held `tools/binding_generator` directory generates the rest of
the library's generated source files from `godot-coo/gdextension/extension_api.json`. 
It can be run from the `tools/binding_generator` directory with:

```bash
dart ./bin/binding_generator.dart
```

For now, this generator takes no options, but it potentially will take options in
the future.

## Building

Building the C++ source uses CMake.  The following is the easiest way to build the required dynamic 
libraries needed to work with Godot Dart.

From `./src/cpp`:

```bash
cmake -DCMAKE_BUILD_TYPE=Release . -B "build"
cmake --build build --config release
```

This will put the dynamic library into `./src/cpp/build/` (under `Release` on Windows).  It will also copy
the required files to `./example/2d_tutorial` for your convenience.

## Other Stuff

For code formating, please use `dartfmt` and the provided `.clangformat` files.