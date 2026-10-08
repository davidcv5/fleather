import 'package:fake_async/fake_async.dart';
import 'package:fleather/fleather.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final pauseBetween in [true, false]) {
    test(
        'consecutive history across growing lines and formatting: pause $pauseBetween',
        () {
      fakeAsync((clock) {
        final controller = FleatherController(
          document: ParchmentDocument.fromJson([
            {'insert': 'Original longer paragraph before replacement.\n'}
          ]),
        );
        final states = [controller.document.toDelta()];
        void capture() {
          clock.elapse(throttleDuration);
          states.add(controller.document.toDelta());
        }

        for (final text in [
          'First long line.',
          'First long line.\nSecond line.',
          'First long line.\nSecond line.\nThird line.',
        ]) {
          controller.replaceText(0, controller.document.length - 1, text,
              selection: TextSelection.collapsed(offset: text.length));
          capture();
        }
        controller.updateSelection(TextSelection(
            baseOffset: 0, extentOffset: controller.document.length - 1));
        for (final attribute in <ParchmentAttribute>[
          ParchmentAttribute.bold,
          ParchmentAttribute.ul,
          ParchmentAttribute.ol,
          ParchmentAttribute.h1,
        ]) {
          controller.formatSelection(attribute);
          capture();
        }
        for (var repeat = 0; repeat < 4; repeat++) {
          for (var i = states.length - 2; i >= 0; i--) {
            controller.undo();
            expect(controller.document.toDelta(), states[i]);
            expect(controller.selection.isValid, isTrue);
            expect(controller.selection.end,
                lessThanOrEqualTo(controller.document.length - 1));
            if (pauseBetween) clock.elapse(throttleDuration);
          }
          expect(controller.canUndo, isFalse);
          for (var i = 1; i < states.length; i++) {
            controller.redo();
            expect(controller.document.toDelta(), states[i]);
            expect(controller.selection.isValid, isTrue);
            expect(controller.selection.end,
                lessThanOrEqualTo(controller.document.length - 1));
            if (pauseBetween) clock.elapse(throttleDuration);
          }
          expect(controller.canRedo, isFalse);
        }
        controller.dispose();
      });
    });
  }

  test(
      'history preserves empty lines and final line attributes during growth and deletion',
      () {
    fakeAsync((clock) {
      final controller = FleatherController();
      final states = [controller.document.toDelta()];
      for (final text in [
        '',
        '\n',
        '\n\n',
        '😀 café\n',
        '😀 café\nNext\n\n',
        ''
      ]) {
        controller.replaceText(0, controller.document.length - 1, text,
            selection: TextSelection.collapsed(offset: text.length));
        controller.formatSelection(ParchmentAttribute.h2);
        clock.elapse(throttleDuration);
        final state = controller.document.toDelta();
        if (state != states.last) states.add(state);
      }
      for (var i = states.length - 2; i >= 0; i--) {
        controller.undo();
        expect(controller.document.toDelta(), states[i]);
      }
      for (var i = 1; i < states.length; i++) {
        controller.redo();
        expect(controller.document.toDelta(), states[i]);
      }
      controller.dispose();
    });
  });
}
