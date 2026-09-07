import 'package:diatar_app/src/utils/inline_text_formatting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('removes empty and repeated inline style markers', () {
    expect(normalizeInlineTextFormattingMarkers(r'a\B\b\B\bsd\b\B\b'), 'asd');
  });

  test('preserves the rendered style while consolidating markers', () {
    expect(
      normalizeInlineTextFormattingMarkers(r'\Bbold\B\I italic\i\b'),
      r'\Bbold\I italic\b\i',
    );
  });

  test('does not alter other inline commands', () {
    expect(
      normalizeInlineTextFormattingMarkers(r'\Bword\b\GAm;'),
      r'\Bword\b\GAm;',
    );
  });

  test('decodes every supported DIA command into logical editor text', () {
    final InlineTextDocument document = InlineTextDocument.decode(
      r'\Bbold\b\ \-\_\.\\\KkGu4;\GAm;\?Gminor;',
    );

    expect(
      document.visibleText,
      'bold\u00A0\u00AD\u2011\n\\'
      '$inlineCommandPlaceholder'
      '$inlineCommandPlaceholder'
      '$inlineCommandPlaceholder',
    );
    expect(document.encode(), r'\Bbold\b\ \-\_\.\\\KkGu4;\GAm;\?Gminor;');
  });

  test('round-trips every paired DIA style', () {
    expect(
      InlineTextDocument.decode(
        r'\Bbold\b\Uunder\u\Iitalic\i\Sstrike\s\(tied\)',
      ).encode(),
      r'\Bbold\b\Uunder\u\Iitalic\i\Sstrike\s\(tied\)',
    );
  });

  test('preserves variable commands as indivisible logical elements', () {
    final InlineTextDocument document = InlineTextDocument.decode(
      r'ab\KkGu4;cd\GAm;\?Gminor;',
    );

    expect(
      document.visibleText,
      'ab'
      '$inlineCommandPlaceholder'
      'cd'
      '$inlineCommandPlaceholder'
      '$inlineCommandPlaceholder',
    );
    document.replaceVisibleRange(1, 1, 'X', styles: const <InlineTextStyle>{});

    expect(document.encode(), r'aXb\KkGu4;cd\GAm;\?Gminor;');
  });

  test('does not add style transitions around embedded commands', () {
    expect(
      InlineTextDocument.decode(r'\Bword\GAm;more\b').encode(),
      r'\Bword\GAm;more\b',
    );
  });

  test('serializes selected and pending styles without raw markup offsets', () {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia('hello');
    controller.value = TextEditingValue(
      text: 'hello',
      selection: TextSelection(baseOffset: 1, extentOffset: 4),
    );

    controller.toggleStyle(InlineTextStyle.bold);
    expect(controller.text, 'hello');
    expect(controller.encodedText, r'h\Bell\bo');

    controller.value = TextEditingValue(
      text: 'hello',
      selection: TextSelection.collapsed(offset: 5),
    );
    controller.toggleStyle(InlineTextStyle.italic);
    controller.value = TextEditingValue(
      text: 'hello!',
      selection: TextSelection.collapsed(offset: 6),
    );

    expect(controller.text, 'hello!');
    expect(controller.encodedText, r'h\Bell\bo\I!\i');
    controller.dispose();
  });

  test('uses one visible controller character for an embedded command', () {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia(r'a\KkGu4;b');

    expect(
      controller.text,
      'a$inlineCommandPlaceholder'
      'b',
    );
    controller.value = TextEditingValue(
      text: 'aXb',
      selection: TextSelection.collapsed(offset: 2),
    );

    expect(controller.encodedText, 'aXb');
    controller.dispose();
  });

  test('escapes typed backslashes instead of creating DIA commands', () {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia('');
    controller.value = TextEditingValue(
      text: '\\B',
      selection: TextSelection.collapsed(offset: 2),
    );

    expect(controller.text, '\\B');
    expect(controller.encodedText, r'\\B');
    controller.dispose();
  });
}
