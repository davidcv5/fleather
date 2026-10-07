import 'package:fake_async/fake_async.dart';
import 'package:fleather/fleather.dart';
import 'package:fleather/src/widgets/history.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('replacement ending in insert ignores deleted input length', () {
    final delta = Delta()
      ..delete(75)
      ..insert('short')
      ..retain(1)
      ..insert('!');
    expect(HistoryStack.selectionFromDelta(delta),
        const TextSelection.collapsed(offset: 7));
  });

  test('canonical replacement ending in delete selects end of inserted text',
      () {
    final delta = Delta()
      ..retain(3)
      ..delete(75)
      ..insert('short');
    expect(delta.last.isDelete, isTrue);
    expect(HistoryStack.selectionFromDelta(delta),
        const TextSelection.collapsed(offset: 8));
  });

  test('pure deletion collapses at the deletion position', () {
    final delta = Delta()
      ..retain(3)
      ..delete(75);
    expect(HistoryStack.selectionFromDelta(delta),
        const TextSelection.collapsed(offset: 3));
  });

  test('format selection covers retained output without counting deleted text',
      () {
    final delta = Delta()
      ..retain(3)
      ..delete(75)
      ..retain(5, {'b': true});
    expect(HistoryStack.selectionFromDelta(delta),
        const TextSelection(baseOffset: 3, extentOffset: 8));
    expect(
      HistoryStack.selectionFromDelta(Delta()
        ..retain(3)
        ..retain(5, {'b': true})),
      const TextSelection(baseOffset: 3, extentOffset: 8),
    );
  });

  final replacements = <(String, String)>[
    (
      'A long original paragraph with many more characters than its replacement has.',
      'A single edit can be undone.'
    ),
    ('same same same same same', 'same'),
    ('🙂 café repeated 🙂 café repeated', '🙂 café'),
    ('first long line\nsecond long line\nthird long line', 'short\nline'),
  ];
  for (var i = 0; i < replacements.length; i++) {
    test('shorter replacement undo/redo preserves document and selection $i',
        () {
      fakeAsync((async) {
        final (original, replacement) = replacements[i];
        final initial = Delta()..insert('$original\n');
        final expected = Delta()..insert('$replacement\n');
        final controller = FleatherController(
          document: ParchmentDocument.fromDelta(initial),
        );
        try {
          controller.replaceText(0, original.length, replacement,
              selection: TextSelection.collapsed(offset: replacement.length));
          async.elapse(throttleDuration);
          expect(controller.document.toDelta(), expected);
          for (var cycle = 0; cycle < 2; cycle++) {
            controller.undo();
            expect(controller.document.toDelta(), initial);
            expect(controller.selection.isValid, isTrue);
            expect(
                controller.selection.end, lessThan(controller.document.length));
            controller.redo();
            expect(controller.document.toDelta(), expected);
            expect(controller.selection.isValid, isTrue);
            expect(
                controller.selection.end, lessThan(controller.document.length));
          }
        } finally {
          controller.dispose();
        }
      });
    });
  }
}
