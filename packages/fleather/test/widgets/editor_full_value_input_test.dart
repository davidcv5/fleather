import 'package:fleather/fleather.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../testing.dart';
import 'editor_intents_test.dart' show receiveAction;

void main() {
  Future<EditorSandBox> openEditor(WidgetTester tester,
      {String text = 'hello\n', bool readOnly = false}) async {
    final editor = EditorSandBox(
      tester: tester,
      document: ParchmentDocument.fromJson([
        {'insert': text}
      ]),
      readOnly: readOnly,
    );
    await editor.pumpAndTap();
    return editor;
  }

  Future<void> sendValue(WidgetTester tester, String text, int offset) async {
    tester.testTextInput.updateEditingValue(TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    ));
    await tester.pumpAndSettle(throttleDuration);
  }

  testWidgets('only web requests full editing values', (tester) async {
    await openEditor(tester);
    expect(tester.testTextInput.setClientArgs!['enableDeltaModel'], !kIsWeb);
  });

  testWidgets('native ignores full values and continues applying deltas',
      (tester) async {
    final editor = await openEditor(tester);
    final state = tester.state<RawEditorState>(find.byType(RawEditor));
    state.updateEditingValue(const TextEditingValue(
      text: 'ignored\n',
      selection: TextSelection.collapsed(offset: 7),
    ));
    expect(editor.document.toPlainText(), 'hello\n');
    state.updateEditingValueWithDeltas([
      const TextEditingDeltaInsertion(
        oldText: 'hello\n',
        textInserted: '!',
        insertionOffset: 5,
        selection: TextSelection.collapsed(offset: 6),
        composing: TextRange.empty,
      ),
    ]);
    await tester.pumpAndSettle(throttleDuration);
    expect(editor.document.toPlainText(), 'hello!\n');
    expect(editor.selection.extentOffset, 6);
  }, skip: kIsWeb);

  group('web full editing values', () {
    testWidgets('inserts, replaces and deletes text', (tester) async {
      final editor = await openEditor(tester);
      await sendValue(tester, 'hello!\n', 6);
      expect(editor.document.toPlainText(), 'hello!\n');
      expect(editor.selection.extentOffset, 6);
      await sendValue(tester, 'hi!\n', 2);
      expect(editor.document.toPlainText(), 'hi!\n');
      await sendValue(tester, 'hi\n', 2);
      expect(editor.document.toPlainText(), 'hi\n');
    });

    testWidgets('composition-only updates and composing text can commit',
        (tester) async {
      final editor = await openEditor(tester);
      await editor.updateSelection(base: 5, extent: 5);
      tester.testTextInput.updateEditingValue(const TextEditingValue(
        text: 'hello\n',
        selection: TextSelection.collapsed(offset: 5),
        composing: TextRange(start: 0, end: 5),
      ));
      await tester.pumpAndSettle(throttleDuration);
      expect(editor.document.toPlainText(), 'hello\n');
      expect(editor.controller.canUndo, isFalse);
      tester.testTextInput.updateEditingValue(const TextEditingValue(
        text: 'helloé\n',
        selection: TextSelection.collapsed(offset: 6),
        composing: TextRange(start: 5, end: 6),
      ));
      await tester.pumpAndSettle(throttleDuration);
      expect(editor.document.toPlainText(), 'helloé\n');
      await sendValue(tester, 'helloé\n', 6);
      final state = tester.state<RawEditorState>(find.byType(RawEditor));
      expect(state.currentTextEditingValue!.composing, TextRange.empty);
      expect(editor.document.toPlainText(), 'helloé\n');
      expect(editor.selection.extentOffset, 6);
    });

    testWidgets('repeated text replacement preserves formatting and history',
        (tester) async {
      final original = Delta()
        ..insert('same', {'b': true})
        ..insert(' same same\n');
      final editor = EditorSandBox(
        tester: tester,
        document: ParchmentDocument.fromDelta(original),
      );
      await editor.pumpAndTap();
      await editor.updateSelection(base: 5, extent: 9);
      await sendValue(tester, 'same other same\n', 10);
      final edited = Delta()
        ..insert('same', {'b': true})
        ..insert(' other same\n');
      expect(editor.document.toDelta(), edited);
      expect(editor.selection.extentOffset, 10);
      expect(editor.controller.canUndo, isTrue);
      editor.controller.undo();
      await tester.pumpAndSettle(throttleDuration);
      expect(editor.document.toDelta(), original);
      editor.controller.redo();
      await tester.pumpAndSettle(throttleDuration);
      expect(editor.document.toDelta(), edited);
      expect(tester.testTextInput.editingState!['text'], 'same other same\n');
    });

    testWidgets('retains the terminal newline when all text is deleted',
        (tester) async {
      final editor = await openEditor(tester);
      await sendValue(tester, '', 0);
      expect(editor.document.toPlainText(), '\n');
      expect(editor.selection.extentOffset, 0);
      expect(tester.testTextInput.editingState!['text'], '\n');
      await sendValue(tester, 'again\n', 5);
      expect(editor.document.toPlainText(), 'again\n');
    });

    testWidgets('insertion after the terminal newline stays in the document',
        (tester) async {
      final editor = await openEditor(tester);
      await sendValue(tester, 'hello\n!', 7);
      expect(editor.document.toPlainText(), 'hello!\n');
      expect(editor.selection.extentOffset, 6);
      expect(tester.takeException(), isNull);
    });

    testWidgets('selection-only values preserve text and reversed selection',
        (tester) async {
      final editor = await openEditor(tester);
      const value = TextEditingValue(
        text: 'hello\n',
        selection: TextSelection(baseOffset: 4, extentOffset: 1),
      );
      tester.testTextInput.updateEditingValue(value);
      await tester.pumpAndSettle(throttleDuration);
      expect(editor.document.toPlainText(), 'hello\n');
      expect(editor.selection, value.selection);
    });

    testWidgets('invalid selections are rejected and remote state restored',
        (tester) async {
      final editor = await openEditor(tester);
      await editor.updateSelection(base: 2, extent: 2);
      for (final offset in [-1, 20]) {
        tester.state<RawEditorState>(find.byType(RawEditor)).updateEditingValue(
              TextEditingValue(
                text: 'changed\n',
                selection: TextSelection.collapsed(offset: offset),
              ),
            );
        await tester.pumpAndSettle(throttleDuration);
        expect(editor.document.toPlainText(), 'hello\n');
        expect(editor.selection.extentOffset, 2);
        expect(tester.testTextInput.editingState!['text'], 'hello\n');
      }
    });

    testWidgets('read-only accepts selection but rejects text changes',
        (tester) async {
      final editor = await openEditor(tester, readOnly: true);
      await sendValue(tester, 'hello\n', 3);
      expect(editor.selection.extentOffset, 3);
      await sendValue(tester, 'changed\n', 7);
      expect(editor.document.toPlainText(), 'hello\n');
      expect(editor.selection.extentOffset, 3);
      expect(tester.testTextInput.editingState!['text'], 'hello\n');
    });
  }, skip: !kIsWeb);

  for (final text in ['\n', 'hello\n', 'first\nlast\n']) {
    testWidgets('End scroll uses a valid caret offset for ${text.length} chars',
        (tester) async {
      final editor = await openEditor(tester, text: text);
      final selection = editor.selection;
      await receiveAction('scrollToEndOfDocument:');
      await tester.pumpAndSettle(throttleDuration);
      expect(tester.takeException(), isNull);
      expect(editor.selection, selection);
      expect(editor.document.toPlainText(), text);
    });
  }
}
