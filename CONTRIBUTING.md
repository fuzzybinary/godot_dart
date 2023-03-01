Contributions are welcome!

But, please, before you do reach out to me on Mastodon
[@fuzzybinary@mastodon.gamedev.place](https://mastodon.gamedev.place/@fuzzybinary).
I'll let you know what I'm currently working on and where I could use some help.

The rest of this document helps me / you understand how to build the extension.

## Getting Started

### Updating the Dart SDK

Currently, the Dart SDK Windows dll included in the repo is Dart 2.19.4. You can
update this by building the
[dart_shared_library](https://github.com/fuzzybinary/dart_shared_library) repo
and copying the dlls to the example directory (`/simple`).

### Updating FFI Bindings

The files in `godot-headers/godot` are from the 4.0 release of Godot. If you
working on a different version of Godot post Godot 4.0, you will need to
generate those files as explained in the Godot documentation.

Once you have the files, you can generate the FFI bindings using Dart's ffigen
tool. From the `/src/dart` directory run:

```bash
dart run ffigen
```

This will regenerate `/dart/lib/src/core/gdextension_ffi_bindings.dart`

### Regenerating Class Files

The `binding_generator` tool held in the `tools` directory generates the rest of
the library's generated source files from
`godot-headers/godot/extension_api.json`. It can be run from the
`tools/binding_generator` directory with:

```bash
dart ./bin/binding_generator.dart
```

For now this generator takes no options, but it potentially will take options in
the future.

## Other Stuff

For code formating, please use `dartfmt` and the provided `.clangformat` files.