import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:godot_dart_build/builder.dart';
import 'package:test/test.dart';

void main() {
  Future<String> generate(String property) async {
    final readerWriter = TestReaderWriter(rootPackage: 'godot_dart_build');
    await readerWriter.testing.loadIsolateSources();
    String? output;
    await testBuilder(
      godotDartBuilder(BuilderOptions.empty),
      {
        'godot_dart_build|lib/hint_example.dart': '''
import 'package:godot_dart/godot_dart.dart';
part 'hint_example.g.dart';

@GodotScript()
class HintExample extends Node {
  $property
}
''',
      },
      readerWriter: readerWriter,
      outputs: {
        'godot_dart_build|lib/hint_example.godot_dart_builder.g.part':
            decodedMatches(predicate<String>((value) {
          output = value;
          return true;
        })),
      },
    );
    expect(output, isNotNull, reason: 'The builder must emit code.');
    final parsed = parseString(content: output!);
    expect(parsed.errors, isEmpty, reason: 'Generated Dart must be valid.');
    return output!;
  }

  Future<void> expectHints(
      String property, String? hint, String? hintString) async {
    final output = await generate(property);
    if (hint == null) {
      expect(output, isNot(contains('hint:')));
    } else {
      expect(output, contains('hint: PropertyHint.$hint,'));
    }
    final visitor = _HintStringVisitor();
    parseString(content: output).unit.accept(visitor);
    expect(visitor.values, hintString == null ? isEmpty : equals([hintString]));
  }

  test('explicit range and settings are exported', () async {
    await expectHints('''
@GodotProperty(hint: PropertyHint.range, hintString: '0,1000,10')
double speed = 400;
''', 'range', '0,1000,10');
  });

  test('a scalar without hints keeps the PropertyInfo defaults', () async {
    await expectHints('@GodotProperty() double speed = 400;', null, null);
  });

  test('a Node subclass property retains its inferred hints', () async {
    await expectHints(
        '@GodotProperty() Sprite2D? target;', 'nodeType', 'Sprite2D');
  });

  test('a typed list retains its inferred hints', () async {
    // Godot Variant.Type.INT = 2, PropertyHint.NONE = 0.
    await expectHints(
        '@GodotProperty() List<int> values = [];', 'typeString', '2/0:');
  });

  test('an explicit hint overrides the inferred hint', () async {
    await expectHints('''
@GodotProperty(hint: PropertyHint.none, hintString: '')
Sprite2D? target;
''', 'none', '');
  });

  test('hint alone preserves the inferred hint string', () async {
    await expectHints('''
@GodotProperty(hint: PropertyHint.none)
Sprite2D? target;
''', 'none', 'Sprite2D');
  });

  test('hintString alone preserves the inferred hint', () async {
    await expectHints('''
@GodotProperty(hintString: 'Node2D')
Sprite2D? target;
''', 'nodeType', 'Node2D');
  });

  test('annotations on getters also support hints', () async {
    await expectHints('''
double _speed = 400;
@GodotProperty(hint: PropertyHint.range, hintString: '0,1000,10')
double get speed => _speed;
set speed(double value) => _speed = value;
''', 'range', '0,1000,10');
  });

  test('special characters survive generation without interpolation', () async {
    await expectHints(r'''
@GodotProperty(
  hint: PropertyHint.multilineText,
  hintString: 'Quote: \' " Backslash: \\ Dollar: \$value\nNext\tcolumn',
)
String text = '';
''', 'multilineText',
        'Quote: \' " Backslash: \\ Dollar: \$value\nNext\tcolumn');
  });
}

class _HintStringVisitor extends RecursiveAstVisitor<void> {
  final values = <String>[];

  @override
  void visitNamedExpression(NamedExpression node) {
    if (node.name.label.name == 'hintString') {
      // A literal value is required: an interpolated string must fail this test.
      expect(node.expression, isA<SimpleStringLiteral>());
      values.add((node.expression as SimpleStringLiteral).value);
    }
    super.visitNamedExpression(node);
  }
}
