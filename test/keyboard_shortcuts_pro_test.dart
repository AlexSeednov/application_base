import 'package:application_base/presentation/service/keyboard_shortcuts_pro.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// A browser on macOS scrolls a page with Cmd+arrow — to the ends of the page
/// — and with Option+arrow, by a screen. The same combinations carry other
/// meanings elsewhere, Alt+left/right being the browser's own back/forward, so
/// [KeyboardShortcutsPro] binds them on the Apple platforms alone.
void main() {
  const double windowHeight = 600;
  const Size windowSize = Size(800, windowHeight);
  const int itemCount = 60;
  const double itemHeight = 40;

  /// What the page can scroll, and the screen step of a keyboard scroll.
  const double extent = itemCount * itemHeight - windowHeight;
  const double screen = windowHeight * 0.8;

  ///
  final TargetPlatformVariant apple = TargetPlatformVariant.only(
    TargetPlatform.macOS,
  );

  /// A desktop browser reports the host OS, and there the Apple keys must stay
  /// with the browser.
  final TargetPlatformVariant other = TargetPlatformVariant.only(
    TargetPlatform.windows,
  );

  ///
  Future<void> pump(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(windowSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        shortcuts: KeyboardShortcutsPro.shortcuts,
        actions: KeyboardShortcutsPro.actions,
        home: Scaffold(
          body: ListView.builder(
            primary: true,
            itemCount: itemCount,
            itemBuilder: (_, index) =>
                SizedBox(height: itemHeight, child: Text('item $index')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  ///
  double offsetOf(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels;

  /// One press of [key] with [modifier] held, the way a browser sends it.
  Future<void> press(
    WidgetTester tester,
    LogicalKeyboardKey modifier,
    LogicalKeyboardKey key,
  ) async {
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
  }

  ///
  testWidgets('Cmd+arrow goes to the ends of the page', (tester) async {
    await pump(tester);

    await press(
      tester,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.arrowDown,
    );

    /// The framework's own Apple map moves Cmd+arrow by a single line; the
    /// binding here has to replace it, not to join it.
    expect(offsetOf(tester), extent);

    await press(
      tester,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.arrowUp,
    );

    expect(offsetOf(tester), 0);
  }, variant: apple);

  ///
  testWidgets('Option+arrow moves by a screen', (tester) async {
    await pump(tester);

    await press(
      tester,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.arrowDown,
    );

    expect(offsetOf(tester), closeTo(screen, 1));

    await press(tester, LogicalKeyboardKey.altLeft, LogicalKeyboardKey.arrowUp);

    expect(offsetOf(tester), closeTo(0, 1));
  }, variant: apple);

  ///
  testWidgets('the Apple keys are left to the browser elsewhere', (
    tester,
  ) async {
    await pump(tester);

    await press(
      tester,
      LogicalKeyboardKey.altLeft,
      LogicalKeyboardKey.arrowDown,
    );
    await press(
      tester,
      LogicalKeyboardKey.metaLeft,
      LogicalKeyboardKey.arrowDown,
    );

    expect(offsetOf(tester), 0);
  }, variant: other);
}
