// Additional functions that need to be added to the generated code for GDString
// (usually constructors or static functions as they cannot be added in
// Extension classes)

/// Create GDString from String
String gdStringFromString() {
  return '''
  GDString.fromString(String string) {
    final native = string.toNativeUtf8();

    final f = gde.interface.ref.string_new_with_utf8_chars
      .asFunction<void Function(GDExtensionStringPtr, Pointer<Char>)>();
    f(opaque.cast(), native.cast());

    malloc.free(native);
  }
''';
}
