import 'package:fleather/fleather.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  late FleatherController controller;
  late FocusNode focusNode;

  setUp(() {
    controller = FleatherController();
    focusNode = FocusNode();
  });

  Future<void> pumpEditor(WidgetTester tester,
      {bool autocorrect = true, bool dark = false}) async {
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
      home: FleatherField(
        controller: controller,
        focusNode: focusNode,
        autocorrect: autocorrect,
        keyboardAppearance: Brightness.light,
      ),
    ));
    await tester.pumpAndSettle();
  }

  List<MethodCall> updates(WidgetTester tester) => tester.testTextInput.log
      .where((call) => call.method == 'TextInput.updateConfig')
      .toList();

  testWidgets('unchanged dependency and theme rebuilds do not update config',
      (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.byType(RawEditor));
    await tester.pumpAndSettle();
    final state = tester.state<RawEditorState>(find.byType(RawEditor));
    expect(state.hasConnection, isTrue);
    tester.testTextInput.log.clear();

    await pumpEditor(tester, dark: true);
    // Also exercise the dependency hook directly without changing its inputs.
    state.didChangeDependencies();
    await tester.pumpAndSettle();
    expect(updates(tester), isEmpty);
    expect(state.hasConnection, isTrue);
  });

  testWidgets('changed autocorrect is forwarded once', (tester) async {
    await pumpEditor(tester);
    await tester.tap(find.byType(RawEditor));
    await tester.pumpAndSettle();
    tester.testTextInput.log.clear();

    await pumpEditor(tester, autocorrect: false);
    expect(updates(tester), hasLength(1));
    expect(updates(tester).single.arguments['autocorrect'], isFalse);
    await pumpEditor(tester, autocorrect: false, dark: true);
    expect(updates(tester), hasLength(1));
    await pumpEditor(tester);
    expect(updates(tester), hasLength(2));
    expect(updates(tester).last.arguments['autocorrect'], isTrue);
  });

  for (final platformClosed in [false, true]) {
    testWidgets(
        'reconnect uses current config after platformClosed=$platformClosed',
        (tester) async {
      await pumpEditor(tester);
      await tester.tap(find.byType(RawEditor));
      await tester.pumpAndSettle();
      final state = tester.state<RawEditorState>(find.byType(RawEditor));
      if (platformClosed) {
        state.connectionClosed();
      } else {
        state.closeConnectionIfNeeded();
      }
      expect(state.hasConnection, isFalse);
      tester.testTextInput.log.clear();

      await pumpEditor(tester, autocorrect: false);
      expect(updates(tester), isEmpty);
      state.openConnectionIfNeeded();
      await tester.pumpAndSettle();
      final attachments = tester.testTextInput.log
          .where((call) => call.method == 'TextInput.setClient');
      expect(attachments, hasLength(1));
      expect(attachments.single.arguments[1]['autocorrect'], isFalse);
      state.updateConnectionConfig();
      expect(updates(tester), isEmpty);
    });
  }
}
