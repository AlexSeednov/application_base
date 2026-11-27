import 'dart:async';

import 'package:application_base/presentation/view/pull_to_refresh.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

///
void main() {
  for (final reverse in [false, true]) {
    testWidgets(
      'a short list refreshes at its leading edge (reverse: $reverse)',
      (tester) async {
        const contentKey = ValueKey('content');
        const indicatorKey = ValueKey('indicator');
        final pending = Completer<void>();
        final shift = ValueNotifier<double>(0);
        final controller = IndicatorController();
        addTearDown(shift.dispose);
        addTearDown(controller.dispose);
        int armed = 0;
        int refreshed = 0;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: PullToRefresh(
                onRefresh: () {
                  refreshed++;
                  return pending.future;
                },
                onArmed: () => armed++,
                pullDistance: 48,
                edgeOffset: 12,
                edgeOffsetShift: shift,
                indicatorPadding: 0,
                displacement: 8,
                translateContent: true,
                forceScrolling: true,
                reverse: reverse,
                controller: controller,
                indicatorBuilder: (_, _) =>
                    const SizedBox.square(key: indicatorKey, dimension: 24),
                child: const SizedBox(key: contentKey, height: 80),
              ),
            ),
          ),
        );

        final initialTop = tester.getTopLeft(find.byKey(contentKey)).dy;
        final direction = reverse ? -1.0 : 1.0;
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(contentKey)),
        );
        await gesture.moveBy(Offset(0, direction * 120));
        await gesture.moveBy(Offset(0, direction * 40));
        await tester.pump();
        expect(armed, 1);
        expect(refreshed, 0);
        expect(
          controller.side,
          reverse ? IndicatorSide.bottom : IndicatorSide.top,
        );
        final translatedTop = tester.getTopLeft(find.byKey(contentKey)).dy;
        expect((translatedTop - initialTop) * direction, greaterThan(0));

        final firstIndicatorTop = tester
            .getTopLeft(find.byKey(indicatorKey))
            .dy;
        shift.value = 20;
        await tester.pump();
        expect(
          tester.getTopLeft(find.byKey(indicatorKey)).dy - firstIndicatorTop,
          direction * 20,
        );

        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(refreshed, 1);
        expect(controller.isLoading, isTrue);

        pending.complete();
        await tester.pumpAndSettle();
        expect(controller.isIdle, isTrue);
        expect(tester.getTopLeft(find.byKey(contentKey)).dy, initialTop);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
