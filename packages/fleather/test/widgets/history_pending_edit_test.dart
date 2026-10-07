import 'package:fake_async/fake_async.dart';
import 'package:fleather/fleather.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FleatherController controller;

  setUp(() {
    controller = FleatherController(
      document: ParchmentDocument.fromJson([
        {'insert': 'A longer first line\nand a longer second line\n'}
      ]),
    );
  });

  tearDown(() => controller.dispose());

  for (final replacement in ['short', 'short\nline']) {
    test(
        'undo flushes pending replacement $replacement and future edits still save',
        () {
      fakeAsync((async) {
        controller.formatText(0, 5, ParchmentAttribute.bold);
        async.elapse(throttleDuration);
        final settled = controller.document.toDelta();
        controller.replaceText(0, controller.document.length - 1, replacement,
            selection: TextSelection.collapsed(offset: replacement.length));
        final replaced = controller.document.toDelta();
        async.elapse(const Duration(milliseconds: 100));
        controller.undo();
        expect(controller.document.toDelta(), settled);
        controller.redo();
        expect(controller.document.toDelta(), replaced);
        controller.undo();
        expect(controller.document.toDelta(), settled);
        async.elapse(throttleDuration);
        // A canceled snapshot must not change the history behind the document.
        expect(controller.document.toDelta(), settled);
        controller.redo();
        expect(controller.document.toDelta(), replaced);

        controller.formatText(0, 2, ParchmentAttribute.italic);
        final next = controller.document.toDelta();
        async.elapse(throttleDuration);
        controller.undo();
        expect(controller.document.toDelta(), replaced);
        controller.redo();
        expect(controller.document.toDelta(), next);
      });
    });
  }

  test('pending formatting is its own undo step when traversed before timeout',
      () {
    fakeAsync((async) {
      controller.formatText(0, 5, ParchmentAttribute.bold);
      async.elapse(throttleDuration);
      final settled = controller.document.toDelta();
      controller.formatText(0, 5, ParchmentAttribute.italic);
      final formatted = controller.document.toDelta();
      controller.undo();
      expect(controller.document.toDelta(), settled);
      controller.redo();
      expect(controller.document.toDelta(), formatted);
      async.elapse(throttleDuration);
      controller.undo();
      expect(controller.document.toDelta(), settled);
    });
  });

  test('redo flushes a pending new edit and invalidates the old redo branch',
      () {
    fakeAsync((async) {
      controller.formatText(0, 5, ParchmentAttribute.bold);
      async.elapse(throttleDuration);
      final settled = controller.document.toDelta();
      controller.formatText(0, 5, ParchmentAttribute.italic);
      async.elapse(throttleDuration);
      controller.undo();
      expect(controller.document.toDelta(), settled);
      expect(controller.canRedo, isTrue);
      controller.replaceText(0, controller.document.length - 1, 'new branch',
          selection: const TextSelection.collapsed(offset: 10));
      final branch = controller.document.toDelta();
      controller.redo();
      expect(controller.document.toDelta(), branch);
      expect(controller.canRedo, isFalse);
      async.elapse(throttleDuration);
      controller.undo();
      expect(controller.document.toDelta(), settled);
      controller.redo();
      expect(controller.document.toDelta(), branch);
    });
  });
}
