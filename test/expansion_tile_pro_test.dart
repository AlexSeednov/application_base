import 'package:application_base/presentation/view/expansion_tile_pro.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The hover highlight of a row covers the whole row, bleeds past its edges
/// and fades as soon as the cursor leaves; a tap on the row toggles the body.
///
/// The highlight is easy to break: grown out of a pressed state, it hugs the
/// text, lingers after the cursor is gone and leaves the vertical padding of
/// the row uncovered.
void main() {
  ///
  const String title = 'What will I get out of the course?';

  ///
  const String answer = 'A better idea of yourself and your emotions';

  ///
  const Color highlightColor = Color(0x141B1B24);

  /// Not the default, so the tests also prove the caller's bleed is applied.
  const double bleed = 16;

  ///
  const double width = 400;

  ///
  Future<void> pumpTile(
    WidgetTester tester, {
    required ValueNotifier<bool> isExpandedNotifier,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: width,
              child: ValueListenableBuilder<bool>(
                valueListenable: isExpandedNotifier,
                builder: (context, isExpanded, _) => ExpansionTilePro(
                  title: title,
                  titleStyle: const TextStyle(fontSize: 16),
                  icon: const SizedBox.square(dimension: 24),
                  isExpanded: isExpanded,
                  onToggle: () =>
                      isExpandedNotifier.value = !isExpandedNotifier.value,
                  highlightColor: highlightColor,
                  borderRadius: BorderRadius.circular(12),
                  duration: const Duration(milliseconds: 150),
                  highlightBleed: bleed,
                  child: const Text(answer),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Returns the gesture, so a test can move the cursor away again.
  Future<TestGesture> hoverTile(WidgetTester tester) async {
    final TestGesture gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    // Added outside the row, so the move onto it is a real enter.
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);

    await gesture.moveTo(tester.getCenter(find.text(title)));
    await tester.pumpAndSettle();

    return gesture;
  }

  /// The fill the highlight animates towards, not the one on screen mid-way.
  Color? highlightOf(WidgetTester tester) {
    final AnimatedContainer container = tester.widget<AnimatedContainer>(
      find.byType(AnimatedContainer),
    );

    return (container.decoration! as BoxDecoration).color;
  }

  testWidgets('the highlight outgrows the row and covers its height', (
    tester,
  ) async {
    final notifier = ValueNotifier<bool>(false);
    addTearDown(notifier.dispose);

    await pumpTile(tester, isExpandedNotifier: notifier);
    await hoverTile(tester);

    final Size highlight = tester.getSize(find.byType(AnimatedContainer));
    final Size header = tester.getSize(find.byType(Row));

    expect(highlight.width, width + bleed * 2);
    expect(highlight.height, header.height + ExpansionTilePro.headerOffset * 2);
  });

  testWidgets('the highlight follows the cursor in and out', (tester) async {
    final notifier = ValueNotifier<bool>(false);
    addTearDown(notifier.dispose);

    await pumpTile(tester, isExpandedNotifier: notifier);
    expect(highlightOf(tester), Colors.transparent);

    final TestGesture gesture = await hoverTile(tester);
    expect(highlightOf(tester), highlightColor);

    await gesture.moveTo(Offset.zero);
    await tester.pumpAndSettle();
    expect(highlightOf(tester), Colors.transparent);
  });

  testWidgets('a tap on the row expands and collapses the body', (
    tester,
  ) async {
    final notifier = ValueNotifier<bool>(false);
    addTearDown(notifier.dispose);

    await pumpTile(tester, isExpandedNotifier: notifier);

    /// The body stays in the tree while collapsed: whether it shows is told
    /// by the height it takes, not by the size of its text.
    expect(tester.getSize(find.byType(AnimatedCrossFade)).height, 0);

    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
    expect(notifier.value, isTrue);
    expect(
      tester.getSize(find.byType(AnimatedCrossFade)).height,
      greaterThan(tester.getSize(find.text(answer)).height),
    );

    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
    expect(notifier.value, isFalse);
    expect(tester.getSize(find.byType(AnimatedCrossFade)).height, 0);
  });
}
