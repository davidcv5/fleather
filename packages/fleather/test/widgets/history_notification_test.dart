import 'package:fake_async/fake_async.dart';
import 'package:fleather/fleather.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late FleatherController controller;
  late List<(bool, bool)> notifications;

  setUp(() {
    controller = FleatherController(
      document: ParchmentDocument.fromJson([
        {'insert': 'hello\n'}
      ]),
    );
    notifications = [];
    controller.addListener(() {
      notifications.add((controller.canUndo, controller.canRedo));
    });
  });

  tearDown(() => controller.dispose());

  test('formatting notifies when undo becomes available after the throttle',
      () {
    fakeAsync((async) {
      final original = controller.document.toDelta();
      controller.formatText(0, 5, ParchmentAttribute.bold);
      final formatted = controller.document.toDelta();
      expect(notifications, [(false, false)]);
      async.elapse(throttleDuration - const Duration(milliseconds: 1));
      expect(notifications, [(false, false)]);
      async.elapse(const Duration(milliseconds: 1));
      expect(notifications, [(false, false), (true, false)]);
      controller.undo();
      expect(controller.document.toDelta(), original);
      controller.redo();
      expect(controller.document.toDelta(), formatted);
    });
  });

  test('empty history push does not add a notification', () {
    fakeAsync((async) {
      // Toggling a style without a selection does not change the document.
      controller.formatText(0, 0, ParchmentAttribute.bold);
      notifications.clear();
      async.elapse(throttleDuration);
      expect(notifications, isEmpty);
      expect(controller.canUndo, isFalse);
    });
  });

  test('further grouped edits preserve timing without redundant notifications',
      () {
    fakeAsync((async) {
      controller.formatText(0, 5, ParchmentAttribute.bold);
      async.elapse(throttleDuration);
      final first = controller.document.toDelta();
      controller.formatText(0, 5, ParchmentAttribute.italic);
      async.elapse(const Duration(milliseconds: 100));
      controller.formatText(0, 5, ParchmentAttribute.underline);
      notifications.clear();
      async.elapse(throttleDuration);
      expect(notifications, isEmpty);
      controller.undo();
      expect(controller.document.toDelta(), first);
    });
  });

  test(
      'new edit notifies when redo is invalidated while undo remains available',
      () {
    fakeAsync((async) {
      controller.formatText(0, 5, ParchmentAttribute.bold);
      async.elapse(throttleDuration);
      controller.formatText(0, 5, ParchmentAttribute.italic);
      async.elapse(throttleDuration);
      controller.undo();
      expect(controller.canUndo, isTrue);
      expect(controller.canRedo, isTrue);
      controller.formatText(0, 5, ParchmentAttribute.underline);
      notifications.clear();
      async.elapse(throttleDuration);
      expect(notifications, [(true, false)]);
    });
  });

  test('clear resets history and new edits notify after the same throttle', () {
    fakeAsync((async) {
      controller.formatText(0, 5, ParchmentAttribute.bold);
      // Clear cancels the pending push from the original history.
      controller.clear();
      notifications.clear();
      async.elapse(throttleDuration);
      expect(notifications, isEmpty);
      expect(controller.canUndo, isFalse);
      controller.replaceText(0, 0, 'new',
          selection: const TextSelection.collapsed(offset: 3));
      notifications.clear();
      async.elapse(throttleDuration);
      expect(notifications, [(true, false)]);
      controller.undo();
      expect(controller.document.toPlainText(), '\n');
    });
  });
}
