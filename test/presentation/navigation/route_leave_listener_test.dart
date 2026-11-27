import 'dart:async';

import 'package:application_base/presentation/navigation/route_leave_listener.dart';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A page can leave the active route hierarchy without being disposed.
void main() {
  ///
  Future<({_TestRouter router, TabsRouter tabsRouter})> pump(
    WidgetTester tester, {
    required VoidCallback onLeave,
  }) async {
    final router = _TestRouter(onLeave: onLeave);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router.config()));
    await tester.pumpAndSettle();

    final TabsRouter tabsRouter = router.innerRouterOf<TabsRouter>(
      _TestRouter.shellName,
    )!;

    return (router: router, tabsRouter: tabsRouter);
  }

  ///
  testWidgets('switching tabs reports each time the active page leaves', (
    tester,
  ) async {
    int leaveCount = 0;
    final (:router, :tabsRouter) = await pump(
      tester,
      onLeave: () => leaveCount++,
    );
    expect(find.text('form'), findsOneWidget);

    tabsRouter.setActiveIndex(1);
    await tester.pumpAndSettle();
    expect(leaveCount, 1);

    tabsRouter.setActiveIndex(0);
    await tester.pumpAndSettle();
    expect(leaveCount, 1);

    tabsRouter.setActiveIndex(1);
    await tester.pumpAndSettle();
    expect(leaveCount, 2);
  });

  ///
  testWidgets(
    'pushing a page in the same tab reports the previous page leaving',
    (tester) async {
      int leaveCount = 0;
      final (:router, :tabsRouter) = await pump(
        tester,
        onLeave: () => leaveCount++,
      );

      await router.navigatePath('/a/nested');
      await tester.pumpAndSettle();
      expect(find.text('nested'), findsOneWidget);
      expect(leaveCount, 1);

      await router.maybePopTop();
      await tester.pumpAndSettle();
      expect(find.text('form'), findsOneWidget);
      expect(leaveCount, 1);
    },
  );

  ///
  testWidgets('a dialog leaves the underlying route active', (tester) async {
    int leaveCount = 0;
    await pump(tester, onLeave: () => leaveCount++);

    unawaited(
      showDialog<void>(
        context: tester.element(find.text('form')),
        builder: (_) => const Text('dialog'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('dialog'), findsOneWidget);
    expect(leaveCount, 0);
  });
}

///
final class _TestRouter extends RootStackRouter {
  ///
  _TestRouter({required this.onLeave});

  ///
  final VoidCallback onLeave;

  ///
  static const String shellName = 'Shell';

  ///
  @override
  List<AutoRoute> get routes => [
    AutoRoute(
      path: '/',
      initial: true,
      page: PageInfo(
        shellName,
        builder: (_) => const AutoTabsRouter(
          routes: [PageRouteInfo<void>('SectionA'), PageRouteInfo<void>('B')],
        ),
      ),
      children: [
        AutoRoute(
          path: 'a',
          initial: true,
          page: const PageInfo.emptyShell('SectionA'),
          children: [
            AutoRoute(
              path: '',
              initial: true,
              page: PageInfo(
                'Form',
                builder: (_) => RouteLeaveListener(
                  onLeave: onLeave,
                  child: const Text('form'),
                ),
              ),
            ),
            AutoRoute(
              path: 'nested',
              page: PageInfo('Nested', builder: (_) => const Text('nested')),
            ),
          ],
        ),
        AutoRoute(
          path: 'b',
          page: PageInfo('B', builder: (_) => const Text('b')),
        ),
      ],
    ),
  ];
}
