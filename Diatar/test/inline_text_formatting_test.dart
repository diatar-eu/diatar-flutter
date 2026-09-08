import 'package:diatar_common/diatar_common.dart';
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

  test('inserts special characters as one logical editor position', () {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia('ab');
    controller.value = TextEditingValue(
      text: 'ab',
      selection: TextSelection.collapsed(offset: 1),
    );

    controller.insertSpecialCharacter(
      InlineTextSpecialCharacter.nonBreakingHyphen,
    );

    expect(controller.text, 'a\u2011b');
    expect(controller.selection, const TextSelection.collapsed(offset: 2));
    expect(controller.encodedText, r'a\_b');
    controller.dispose();
  });

  test('copies a selected DIA range with its formatting and commands', () {
    final InlineTextDocument document = InlineTextDocument.decode(
      r'a\Bbold\b\ \-\_\.\GAm;z',
    );

    expect(
      document.copyRange(1, document.visibleText.length - 1).encode(),
      r'\Bbold\b\ \-\_\.\GAm;',
    );
  });

  test(
    'round-trips formatting, special characters, and DIA commands in HTML',
    () {
      final InlineTextDocument document = InlineTextDocument.decode(
        r'\Bbold\b \Iitalic\i\ \-\_\.\GAm;',
      );

      expect(
        InlineTextClipboard.fromHtml(
          InlineTextClipboard.toHtml(document),
        ).encode(),
        document.encode(),
      );
    },
  );

  test('reads office HTML formatting and non-breaking characters', () {
    expect(
      InlineTextClipboard.fromHtml(
        '<p><strong>Bold</strong> <em>italic</em>&nbsp;<u>under</u><br>next</p>',
      ).encode(),
      '${r'\BBold\b \Iitalic\i\ \Uunder\u'}\nnext\n',
    );
  });

  test('ignores source indentation between Word HTML blocks', () {
    expect(
      InlineTextClipboard.fromHtml(
        '<p><strong>First</strong></p>\r\n  <p>Second</p>',
      ).encode(),
      '${r'\BFirst\b'}\nSecond\n',
    );
  });

  test('keeps Word paragraphs and line breaks as separate lines', () {
    expect(
      InlineTextClipboard.fromHtml(
        '<p class=MsoNormal>first<o:p></o:p></p>'
        '<p class=MsoNormal>second<br>\nthird<o:p></o:p></p>',
      ).visibleText,
      'first\nsecond\nthird\n',
    );
  });

  test('does not accept a platform paste while rich paste is in progress', () {
    final InlineTextEditingController controller =
        InlineTextEditingController.fromDia('before');
    controller.beginRichClipboardPaste();
    controller.value = const TextEditingValue(
      text: 'beplainfore',
      selection: TextSelection.collapsed(offset: 7),
    );

    expect(controller.text, 'before');
    controller.cancelRichClipboardPaste();
    controller.dispose();
  });

  test('round-trips formatting and special characters in RTF', () {
    final InlineTextDocument document = InlineTextDocument.decode(
      r'\Bbold\b \Iitalic\i\ \-\_\.á',
    );

    expect(
      InlineTextClipboard.fromRtf(InlineTextClipboard.toRtf(document)).encode(),
      document.encode(),
    );
  });
}
