import 'dart:collection';
import 'dart:io';

// Helper wrapper around IOSink to make printing code easier and provide indentation
class CodeSink {
  final IOSink _sink;

  int _indentLevel = 0;
  final Queue<bool> _blockDidWrite = Queue();

  CodeSink(File f) : _sink = f.openWrite();

  // Start a block. Uses of [p] inside the block will
  // write at an increased indentation level.
  void b(String line, void Function() block, String endBlock,
      {bool newLine = true}) {
    _checkBlockNewline();
    _sink.write(' ' * _indentLevel);
    // Don't write the newline until we know the block is going to write something
    _sink.write(line);
    _indentLevel += 2;
    _blockDidWrite.addLast(false);
    block();
    _blockDidWrite.removeLast();
    _indentLevel -= 2;
    _sink.write(endBlock);
    if (newLine) _sink.writeln();
  }

  // Write, indenting propertly according to the current
  // block level
  void p(String line) {
    _checkBlockNewline();
    _sink.write(' ' * _indentLevel);
    _sink.writeln(line);
  }

  // Write a newline, ignoring indentation level (used for blank lines)
  void nl() {
    _checkBlockNewline();
    _sink.writeln();
  }

  // Write to the sink, ignoring current indentation level
  void write(Object? object) {
    _sink.write(object);
  }

  // Write a newline for the current block if we haven't yet.
  void _checkBlockNewline() {
    if (_blockDidWrite.isNotEmpty && !_blockDidWrite.last) {
      _sink.writeln();
      _blockDidWrite.removeLast();
      _blockDidWrite.addLast(true);
    }
  }

  Future<void> close() async {
    await _sink.flush();
    await _sink.close();
  }
}
