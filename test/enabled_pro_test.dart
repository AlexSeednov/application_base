import 'package:application_base/presentation/view/enabled_pro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Disabling a control must not reset what is inside it: a form greyed out
/// while it submits keeps the text the user typed.
void main() {
  ///
  Widget harness({required bool isEnabled}) => MaterialApp(
    home: Scaffold(
      body: EnabledPro(isEnabled: isEnabled, child: const TextField()),
    ),
  );

  testWidgets('toggling keeps the state of the child', (tester) async {
    await tester.pumpWidget(harness(isEnabled: true));
    await tester.enterText(find.byType(TextField), 'typed');

    await tester.pumpWidget(harness(isEnabled: false));
    await tester.pumpWidget(harness(isEnabled: true));

    expect(find.text('typed'), findsOneWidget);
  });

  testWidgets('a disabled child ignores taps', (tester) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: EnabledPro(
          isEnabled: false,
          child: TextButton(onPressed: () => taps++, child: const Text('Go')),
        ),
      ),
    );

    await tester.tap(find.text('Go'), warnIfMissed: false);

    expect(taps, 0);
  });
}
