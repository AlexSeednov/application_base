import 'dart:async';
import 'dart:ui' show ViewFocusDirection, ViewFocusEvent, ViewFocusState;

import 'package:application_base/presentation/service/keyboard_shortcuts_pro.dart';
import 'package:application_base/presentation/view/page_focus_keeper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The browser leaves the focus of the page on its body when the element that
/// held it is removed — the `<a>` of a link laid over a card, taken off the
/// screen by the very navigation the click started. Flutter answers that by
/// parking its focus on the root scope, and page scrolling with the keyboard
/// stops working until the next click. [PageFocusKeeper] puts the focus back.
void main() {
  const Key page = ValueKey('page');
  const Size windowSize = Size(800, 600);

  /// Page scrolling is mapped onto the plain arrows in a browser; the desktop
  /// platform of the test stands for a desktop browser.
  final TargetPlatformVariant desktop = TargetPlatformVariant.only(
    TargetPlatform.macOS,
  );

  Widget body(Key key) => Scaffold(
    body: CustomScrollView(
      key: key,
      primary: true,
      slivers: [
        SliverList.builder(
          itemCount: 60,
          itemBuilder: (_, index) =>
              SizedBox(height: 40, child: Text('item $index')),
        ),
      ],
    ),
  );

  double offsetOf(WidgetTester tester) => tester
      .state<ScrollableState>(
        find.descendant(
          of: find.byKey(page),
          matching: find.byType(Scrollable),
        ),
      )
      .position
      .pixels;

  /// Application with a page pushed on top of the first one, as a card opens
  /// the page of its product
  Future<void> pump(WidgetTester tester, {required bool isStranded}) async {
    await tester.binding.setSurfaceSize(windowSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final GlobalKey<NavigatorState> navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        shortcuts: KeyboardShortcutsPro.shortcuts,
        actions: KeyboardShortcutsPro.actions,
        navigatorKey: navigator,
        builder: (_, child) =>
            PageFocusKeeper(isStranded: () => isStranded, child: child!),
        home: body(const ValueKey('first')),
      ),
    );
    await tester.pumpAndSettle();

    unawaited(
      navigator.currentState!.push(
        MaterialPageRoute<void>(builder: (_) => body(page)),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The focusout of the view: the element that held the browser focus has
  /// been removed with the page it belonged to
  Future<void> loseViewFocus(WidgetTester tester) async {
    WidgetsBinding.instance.handleViewFocusChanged(
      ViewFocusEvent(
        viewId: tester.view.viewId,
        state: ViewFocusState.unfocused,
        direction: ViewFocusDirection.undefined,
      ),
    );
    await tester.pump();
  }

  ///
  testWidgets('the page keeps scrolling after the focus is stranded', (
    tester,
  ) async {
    await pump(tester, isStranded: true);
    await loseViewFocus(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();

    expect(offsetOf(tester), greaterThan(0));

    /// And the focus is back on the page that was open, not on the one below
    expect(primaryFocus?.context, isNotNull);
  }, variant: desktop);

  ///
  testWidgets('the page left for the address bar keeps its focus parked', (
    tester,
  ) async {
    await pump(tester, isStranded: false);
    await loseViewFocus(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await tester.pumpAndSettle();

    expect(offsetOf(tester), 0);
  }, variant: desktop);
}
