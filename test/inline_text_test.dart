import 'package:application_base/presentation/view/inline_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

///
void main() {
  ///
  const style = TextStyle(fontSize: 10, color: Colors.black);

  ///
  const firstLabel = 'first document';

  ///
  const secondLabel = 'show help';

  ///
  const address = 'https://example.test/guide';

  ///
  Color? background(WidgetTester tester, String fragment) =>
      tester.widget<Text>(find.text(fragment)).style?.backgroundColor;

  ///
  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }

  testWidgets('Tab and Shift+Tab traverse whole controls and Enter opens one', (
    tester,
  ) async {
    final List<String> pressed = [];
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 110,
            child: InlineText(
              builder: (span) => Text.rich(span, style: style),
              parts: [
                const InlineTextPart.text('Read '),
                InlineTextPart.link(
                  firstLabel,
                  url: 'https://example.test/document',
                  style: style,
                  onClick: () => pressed.add(firstLabel),
                ),
                const InlineTextPart.text(' or '),
                InlineTextPart.action(
                  secondLabel,
                  style: style,
                  onClick: () => pressed.add(secondLabel),
                ),
                const InlineTextPart.text(' at '),
                InlineTextPart.address(
                  address,
                  url: address,
                  style: style,
                  onClick: () => pressed.add(address),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(
      tester.getTopLeft(find.text('document')).dy,
      greaterThan(tester.getTopLeft(find.text('first')).dy),
    );
    for (final label in [firstLabel, secondLabel, address]) {
      expect(find.bySemanticsLabel(label), findsOneWidget);
    }
    expect(find.bySemanticsLabel('document'), findsNothing);
    expect(find.bySemanticsLabel('help'), findsNothing);
    expect(find.bySemanticsLabel('guide'), findsNothing);
    expect(
      tester
          .getSemantics(find.bySemanticsLabel(firstLabel))
          .flagsCollection
          .isLink,
      isTrue,
    );
    expect(
      tester
          .getSemantics(find.bySemanticsLabel(secondLabel))
          .flagsCollection
          .isButton,
      isTrue,
    );
    semantics.dispose();

    await press(tester, LogicalKeyboardKey.tab);
    final Color focusColor = Theme.of(
      tester.element(find.text('first')),
    ).colorScheme.inverseSurface;
    expect(background(tester, 'first'), focusColor);
    expect(background(tester, 'document'), focusColor);
    expect(background(tester, 'show'), isNull);
    await press(tester, LogicalKeyboardKey.enter);

    await press(tester, LogicalKeyboardKey.tab);
    expect(background(tester, 'document'), isNull);
    expect(background(tester, 'show'), focusColor);
    expect(background(tester, 'help'), focusColor);
    await press(tester, LogicalKeyboardKey.enter);

    await press(tester, LogicalKeyboardKey.tab);
    expect(background(tester, 'help'), isNull);
    expect(background(tester, 'https://'), focusColor);
    expect(background(tester, 'guide'), focusColor);
    await press(tester, LogicalKeyboardKey.enter);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await press(tester, LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(background(tester, 'guide'), isNull);
    expect(background(tester, 'help'), focusColor);
    await press(tester, LogicalKeyboardKey.enter);
    expect(pressed, [firstLabel, secondLabel, address, secondLabel]);

    await tester.tap(find.text('document'));
    await tester.pump();
    expect(pressed.last, firstLabel);
  });
}
