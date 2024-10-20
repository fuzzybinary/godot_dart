// Additional functions that need to be added to the generated code for GDString
// (usually constructors or static functions as they cannot be added in
// Extension classes)

import 'code_sink.dart';

/// Create GDString from String
void gdStringFromString(CodeSink o) {
  o.b('GDString.fromString(String string)', () {
    o.p('  : super(_size, _bindings.destructor) {');
    o.p('final native = string.toNativeUtf8();');
    o.p('gde.ffiBindings.gde_string_new_with_utf8_chars(nativePtr.cast(), native.cast());');
    o.nl();

    o.p('malloc.free(native);');
  }, '}');
  o.nl();
}

void gdStringToDartString(CodeSink o) {
  o.b('String toDartString() {', () {
    o.p('return gde.dartBindings.gdStringToString(this);');
  }, '}');
}

void stringNameToDartString(CodeSink o) {
  o.b('String toDartString() {', () {
    o.p('GDString gdStr = GDString.fromStringName(this);');
    o.p('return gde.dartBindings.gdStringToString(gdStr);');
  }, '}');
}
