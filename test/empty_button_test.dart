import 'package:application_base/presentation/view/empty_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The focus ring marks the button for a keyboard user, and only the button:
/// a text field inside it keeps the focus while the user types, and a
/// hardware key switches the highlight mode to keyboard — a ring drawn for
/// the subtree would show up as a stray border around the field.
void main() {
  ///
  Widget harness({required Widget child}) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: EmptyButton(onClick: () {}, child: child),
      ),
    ),
  );

  /// Whether the button draws its ring right now.
  bool isRingShown(WidgetTester tester) {
    final DecoratedBox box = tester.widget<DecoratedBox>(
      find
          .descendant(
            of: find.byType(EmptyButton),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );

    return (box.decoration as BoxDecoration).border != null;
  }

  testWidgets('keyboard focus on the button shows the ring', (tester) async {
    await tester.pumpWidget(
      harness(child: const SizedBox.square(dimension: 40)),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(isRingShown(tester), isTrue);
  });

  testWidgets('typing into a field inside the button shows no ring', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(child: const SizedBox(width: 200, child: TextField())),
    );

    await tester.showKeyboard(find.byType(TextField));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.pump();

    expect(
      FocusManager.instance.highlightMode,
      FocusHighlightMode.traditional,
    );
    expect(isRingShown(tester), isFalse);
  });
}
