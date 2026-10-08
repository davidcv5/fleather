# Web text input compatibility patch

Base: upstream Fleather `v1.28.0`. This fork carries a narrow compatibility
repair associated with [upstream issue #460](https://github.com/fleather-editor/fleather/issues/460).

Web input uses full `TextEditingValue` updates so accessibility input that lacks
usable `beforeinput` deltas can edit the document. The existing fast diff and
controller apply changes, preserving formatting and history, protecting the
mandatory terminal newline, and allowing selection in read-only editors.
Native platforms retain the upstream delta input path. Input connections cache
the configuration sent on attachment and forward configuration updates only
when settings change. This avoids redundant web input reconfiguration during
dependency/theme rebuilds; both close paths clear the cache, and reconnects
attach with current settings. End scrolling targets
the final valid caret offset instead of the position beyond the document.

The controller also notifies listeners when the existing throttled history push
changes undo/redo availability. Immediate edit notifications occur before that
push, so history controls otherwise remain stale until an unrelated rebuild.
Both initial and cleared controllers use the same guarded notification path;
history deltas and the existing grouping interval remain unchanged.

History selection restoration counts retained and inserted output positions,
excluding deleted input lengths. This keeps undo/redo selections valid for
shorter replacements, including canonical deltas that end in deletion, while
preserving formatting ranges.

Undo and redo flush any pending edit snapshot before traversing history and
cancel its timer. The throttle callback is reset so later edits can still be
recorded. Ordinary editing retains the existing 500 ms grouping interval;
traversal starts from the current document, and a new pending edit invalidates
an old redo branch.

History diffs anchor the mandatory final newline and diff its attributes
separately. Generic text diffs can match that newline to an interior newline
while replaying incrementally typed lines, then insert past Parchment's valid
document boundary. The correction preserves the existing compact delta history,
grouping, and final-line headings/list styles.

## Validation

From `packages/fleather`, using a compatible Flutter SDK:

```sh
flutter pub get
flutter test test/widgets/editor_full_value_input_test.dart test/widgets/editor_input_client_mixin_deltas_test.dart test/widgets/editor_input_client_mixin_test.dart test/widgets/editor_input_configuration_test.dart test/widgets/history_notification_test.dart test/widgets/history_selection_test.dart test/widgets/history_pending_edit_test.dart
flutter test --platform chrome test/widgets/editor_full_value_input_test.dart test/widgets/editor_input_configuration_test.dart test/widgets/history_notification_test.dart test/widgets/history_selection_test.dart test/widgets/history_pending_edit_test.dart
flutter analyze --no-pub lib/src/widgets/history.dart lib/src/widgets/controller.dart lib/src/widgets/editor.dart lib/src/widgets/editor_input_client_mixin.dart test/widgets/editor_full_value_input_test.dart test/widgets/editor_input_configuration_test.dart test/widgets/history_notification_test.dart test/widgets/history_selection_test.dart test/widgets/history_pending_edit_test.dart
flutter test test/widgets/history_terminal_newline_test.dart test/widgets/history_terminal_newline_matrix_test.dart
flutter test --platform chrome test/widgets/history_terminal_newline_test.dart test/widgets/history_terminal_newline_matrix_test.dart
```

The focused regressions cover full-value insertion/replacement/deletion,
composition updates, terminal-newline preservation, invalid and reversed
selections, read-only behavior, repeated text, formatting/history, native delta
input and End scrolling in empty and populated documents. Browser widget tests
exercise the input protocol; real browser accessibility and native keyboard
interaction remain application-level acceptance checks.

## Maintenance and removal

Keep this patch limited to the input repair and its regressions. When upstream
ships a compatible fix, run these regressions against that release and repeat
application-level browser accessibility and native editing checks. Then switch
consumers to the verified upstream release and remove the fork dependency.
Issue closure alone is not evidence that the affected interaction is repaired.
