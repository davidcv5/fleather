import 'package:fleather/fleather.dart';
import 'package:fleather/src/widgets/history.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final states = <String, Delta>{
    'empty': Delta()..insert('\n'),
    'one line': Delta()..insert('First long line.\n'),
    'two lines': Delta()..insert('First long line.\nSecond line.\n'),
    'three lines': Delta()
      ..insert('First long line.\nSecond line.\nThird line.\n'),
    'bold heading': Delta()
      ..insert('First long line.', {'b': true})
      ..insert('\n', {'heading': 1}),
    'bulleted line': Delta()
      ..insert('First long line.')
      ..insert('\n', {'block': 'ul'}),
    'numbered line': Delta()
      ..insert('First long line.')
      ..insert('\n', {'block': 'ol'}),
    'bullet then heading': Delta()
      ..insert('First long line.')
      ..insert('\n', {'block': 'ul'})
      ..insert('Second line.')
      ..insert('\n', {'heading': 2}),
    'replacement numbered line': Delta()
      ..insert('completely new ending')
      ..insert('\n', {'block': 'ol'}),
    'empty heading': Delta()..insert('\n', {'heading': 1}),
  };

  for (final before in states.entries) {
    for (final after in states.entries) {
      test('history round-trips ${before.key} to ${after.key}', () {
        final history = HistoryStack(before.value)..push(after.value);
        // push records an edit already applied to the document.
        final document = ParchmentDocument.fromDelta(after.value);
        addTearDown(document.close);

        if (before.value == after.value) {
          expect(history.canUndo, isFalse);
          expect(history.undo(), isNull);
          expect(history.canRedo, isFalse);
          expect(history.redo(), isNull);
          expect(document.toDelta(), after.value);
          return;
        }

        for (var cycle = 0; cycle < 2; cycle++) {
          expect(history.canUndo, isTrue);
          final undo = history.undo();
          expect(undo, isNotNull);
          document.compose(undo!, ChangeSource.history);
          expect(document.toDelta(), before.value);
          expect(history.canUndo, isFalse);

          expect(history.canRedo, isTrue);
          final redo = history.redo();
          expect(redo, isNotNull);
          document.compose(redo!, ChangeSource.history);
          expect(document.toDelta(), after.value);
          expect(history.canRedo, isFalse);
        }
      });
    }
  }
}
