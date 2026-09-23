import 'dart:async';

import 'package:application_base/presentation/navigation/navigation_service.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// When the screens live in a nested router — a shell route with a stack of
/// its own — the root holds one page for all of them: the shell. A pop aimed
/// at the root does nothing or takes the whole shell off and leaves an empty
/// window, and the root names the shell as its current route whatever screen
/// shows inside it. The helpers go through the top-most router instead. The
/// suite pins that down, together with the two states a nested stack must
/// never reach: empty, or cleared on the way to a name it does not hold.
void main() {
  ///
  const String homeName = 'Home';
  ///
  const String shellName = 'Shell';
  ///
  const String nestedName = 'Nested';
  ///
  const String detailName = 'Detail';

  ///
  const PageRouteInfo<void> shellRoute = PageRouteInfo<void>(shellName);
  ///
  const PageRouteInfo<void> detailRoute = PageRouteInfo<void>(detailName);

  /// A root page with a shell over it: the shell's stack opens on `nested`
  /// and can take `detail` on top. Built on the package's [navigatorKey],
  /// the one the helpers read.
  RootStackRouter buildRouter() => RootStackRouter.build(
    navigatorKey: navigatorKey,
    routes: [
      AutoRoute(
        initial: true,
        page: PageInfo(homeName, builder: (_) => const Text('home')),
      ),
      AutoRoute(
        page: PageInfo(shellName, builder: (_) => const AutoRouter()),
        children: [
          AutoRoute(
            initial: true,
            page: PageInfo(nestedName, builder: (_) => const Text('nested')),
          ),
          AutoRoute(
            page: PageInfo(detailName, builder: (_) => const Text('detail')),
          ),
        ],
      ),
    ],
  );

  ///
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp.router(routerConfig: buildRouter().config()),
    );
    await tester.pumpAndSettle();
  }

  /// The push is not awaited: its future settles only once the pushed screen
  /// is popped again.
  Future<void> open(
    WidgetTester tester,
    PageRouteInfo<void> route,
    String text,
  ) async {
    unawaited(pushScreen(route: route));
    await tester.pumpAndSettle();
    expect(find.text(text), findsOneWidget);
  }

  ///
  Future<void> openShell(WidgetTester tester) =>
      open(tester, shellRoute, 'nested');

  ///
  Future<void> openDetail(WidgetTester tester) =>
      open(tester, detailRoute, 'detail');

  testWidgets('currentRouteName names the screen on view, not the shell', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(currentRouteName, homeName);

    await openShell(tester);
    expect(currentRouteName, nestedName);

    await openDetail(tester);
    expect(currentRouteName, detailName);
  });

  testWidgets('popScreen pops the screen of the nested stack', (tester) async {
    await pumpApp(tester);
    await openShell(tester);
    await openDetail(tester);

    await popScreen();
    await tester.pumpAndSettle();

    expect(find.text('detail'), findsNothing);
    expect(find.text('nested'), findsOneWidget);
  });

  testWidgets('popScreen on the last page of the nested stack pops the shell', (
    tester,
  ) async {
    await pumpApp(tester);
    await openShell(tester);

    await popScreen();
    await tester.pumpAndSettle();

    expect(find.text('nested'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('popScreenForced pops the nested screen and keeps the shell', (
    tester,
  ) async {
    await pumpApp(tester);
    await openShell(tester);
    await openDetail(tester);

    popScreenForced();
    await tester.pumpAndSettle();

    expect(find.text('detail'), findsNothing);
    expect(find.text('nested'), findsOneWidget);
  });

  testWidgets(
    'popScreenForced on the last page of the nested stack pops the shell, '
    'not the page',
    (tester) async {
      await pumpApp(tester);
      await openShell(tester);

      popScreenForced();
      await tester.pumpAndSettle();

      expect(find.text('nested'), findsNothing);
      expect(find.text('home'), findsOneWidget);
    },
  );

  testWidgets('popUntilScreenWithName finds the name in the nested stack', (
    tester,
  ) async {
    await pumpApp(tester);
    await openShell(tester);
    await openDetail(tester);

    popUntilScreenWithName(routeName: nestedName);
    await tester.pumpAndSettle();

    expect(find.text('detail'), findsNothing);
    expect(find.text('nested'), findsOneWidget);
  });

  testWidgets('popUntilScreenWithName reaches a name on the root', (
    tester,
  ) async {
    await pumpApp(tester);
    await openShell(tester);
    await openDetail(tester);

    popUntilScreenWithName(routeName: homeName);
    await tester.pumpAndSettle();

    expect(find.text('detail'), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('popUntilScreenWithName with an unknown name pops nothing', (
    tester,
  ) async {
    await pumpApp(tester);
    await openShell(tester);
    await openDetail(tester);

    popUntilScreenWithName(routeName: 'Nowhere');
    await tester.pumpAndSettle();

    expect(find.text('detail'), findsOneWidget);
  });

  testWidgets(
    'popUntilScreenWithName closes a dialog on the root over the nested stack',
    (tester) async {
      await pumpApp(tester);
      await openShell(tester);
      await openDetail(tester);

      unawaited(
        showDialog<void>(
          context: tester.element(find.text('detail')),
          builder: (_) => const Text('dialog'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('dialog'), findsOneWidget);

      popUntilScreenWithName(routeName: nestedName);
      await tester.pumpAndSettle();

      expect(find.text('dialog'), findsNothing);
      expect(find.text('detail'), findsNothing);
      expect(find.text('nested'), findsOneWidget);
    },
  );
}
