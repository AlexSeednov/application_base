import 'dart:async';

import 'package:application_base/presentation/view/modal_sheet_overdrag.dart';
import 'package:application_base/presentation/view/sheet_overdrag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A swipe down from the top of a list in a sheet moves the sheet instead of
/// overscrolling the list: a modal sheet through its route transition, a
/// sheet of another kind through its own offset in pixels.
///
/// Easy to break in three ways: a list that sets its own physics never sees
/// the configuration's, a list wrapped twice takes the sheet's share twice,
/// and the platforms differ at the edge — iOS bounces, Android clamps.
void main() {
  ///
  const double screenHeight = 800;

  ///
  const double sheetHeight = 600;

  /// The top of a fully open sheet.
  const double sheetTop = screenHeight - sheetHeight;

  ///
  const double rowHeight = 50;

  /// The drag slop: this much of a gesture goes to recognizing it and moves
  /// nothing.
  const double slop = kDragSlopDefault + 1;

  ///
  const Key sheetKey = ValueKey('sheet');

  ///
  const platforms = TargetPlatformVariant({
    TargetPlatform.iOS,
    TargetPlatform.android,
  });

  ///
  void setScreen(WidgetTester tester) {
    tester.view
      ..physicalSize = const Size(400, screenHeight)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  /// A list far taller than the sheet. [physics] builds the list's own
  /// physics; without it the list takes those of the configuration.
  Widget list(
    ScrollController controller, {
    ScrollPhysics Function(BuildContext context)? physics,
  }) => Builder(
    builder: (context) => ListView(
      controller: controller,
      physics: physics?.call(context),
      children: [
        for (var i = 0; i < 40; i++)
          SizedBox(height: rowHeight, child: Text('row $i')),
      ],
    ),
  );

  /// The top edge of the sheet on screen.
  double topOf(WidgetTester tester) =>
      tester.getTopLeft(find.byKey(sheetKey)).dy;

  /// Opens a modal sheet with a header and a list. Returns the list's
  /// controller and whether the sheet has closed.
  Future<(ScrollController, ValueGetter<bool>)> openModal(
    WidgetTester tester, {
    ScrollPhysics Function(BuildContext context)? physics,
  }) async {
    setScreen(tester);
    final controller = ScrollController();
    addTearDown(controller.dispose);

    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(navigatorKey: navigatorKey, home: const Scaffold()),
    );

    var closed = false;
    unawaited(
      ModalSheetOverdrag.show<void>(
        context: navigatorKey.currentContext!,
        isScrollControlled: true,
        builder: (_) => SizedBox(
          key: sheetKey,
          height: sheetHeight,
          child: Column(
            children: [
              // Not scrollable: the sheet's own drag moves it by this.
              const SizedBox(height: rowHeight, child: Text('header')),
              Expanded(child: list(controller, physics: physics)),
            ],
          ),
        ),
      ).whenComplete(() => closed = true),
    );
    await tester.pumpAndSettle();
    return (controller, () => closed);
  }

  group('A modal sheet with a list of platform physics', () {
    ///
    testWidgets(
      'at the top the sheet follows the finger, and the list stays put',
      (tester) async {
        final (controller, _) = await openModal(tester);

        final gesture = await tester.startGesture(
          tester.getCenter(find.text('row 2')),
        );
        await gesture.moveBy(const Offset(0, slop));
        await gesture.moveBy(const Offset(0, 100));
        await tester.pump();

        expect(controller.offset, 0);
        expect(topOf(tester), closeTo(sheetTop + 100, 5));

        await gesture.up();
      },
      variant: platforms,
    );

    ///
    testWidgets('a sheet let go early goes back', (tester) async {
      final (controller, closed) = await openModal(tester);

      await tester.timedDrag(
        find.text('row 2'),
        const Offset(0, 150),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();

      expect(closed(), isFalse);
      expect(topOf(tester), sheetTop);
      expect(controller.offset, 0);
    }, variant: platforms);

    ///
    testWidgets('a sheet pulled more than halfway down closes', (tester) async {
      final (_, closed) = await openModal(tester);

      await tester.timedDrag(
        find.text('row 2'),
        const Offset(0, 400),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();

      expect(closed(), isTrue);
      expect(find.byKey(sheetKey), findsNothing);
    }, variant: platforms);

    ///
    testWidgets('a quick fling down closes the sheet', (tester) async {
      final (_, closed) = await openModal(tester);

      await tester.fling(find.text('row 2'), const Offset(0, 150), 1500);
      await tester.pumpAndSettle();

      expect(closed(), isTrue);
    }, variant: platforms);

    ///
    testWidgets(
      'a scrolled list reaches its top first, then the sheet moves',
      (tester) async {
        final (controller, _) = await openModal(tester);
        controller.jumpTo(100);
        await tester.pump();

        final gesture = await tester.startGesture(
          tester.getCenter(find.text('row 6')),
        );
        await gesture.moveBy(const Offset(0, slop));
        await gesture.moveBy(const Offset(0, 60));
        await tester.pump();

        // The list has not reached its top: the sheet stays in place.
        expect(controller.offset, closeTo(40, 5));
        expect(topOf(tester), sheetTop);

        await gesture.moveBy(const Offset(0, 90));
        await tester.pump();

        expect(controller.offset, 0);
        expect(topOf(tester), closeTo(sheetTop + 50, 5));

        await gesture.up();
      },
      variant: platforms,
    );

    ///
    testWidgets(
      'a swipe up puts the sheet back first, then scrolls the list',
      (tester) async {
        final (controller, closed) = await openModal(tester);

        final gesture = await tester.startGesture(
          tester.getCenter(find.text('row 2')),
        );
        await gesture.moveBy(const Offset(0, slop));
        await gesture.moveBy(const Offset(0, 100));
        await gesture.moveBy(const Offset(0, -160));
        await tester.pump();

        expect(topOf(tester), sheetTop);
        expect(controller.offset, closeTo(60, 5));

        await gesture.up();
        await tester.pumpAndSettle();

        expect(closed(), isFalse);
        expect(topOf(tester), sheetTop);
      },
      variant: platforms,
    );

    ///
    testWidgets(
      'a drag by the header still puts the sheet back and closes it',
      (tester) async {
        final (_, closed) = await openModal(tester);

        await tester.timedDrag(
          find.text('header'),
          const Offset(0, 150),
          const Duration(seconds: 1),
        );
        await tester.pumpAndSettle();

        expect(closed(), isFalse);
        expect(topOf(tester), sheetTop);

        await tester.timedDrag(
          find.text('header'),
          const Offset(0, 400),
          const Duration(seconds: 1),
        );
        await tester.pumpAndSettle();

        expect(closed(), isTrue);
      },
      variant: platforms,
    );
  });

  group('A modal sheet with a list of its own physics', () {
    ///
    testWidgets(
      'bouncing physics through physicsOf hand the swipe to the sheet',
      (tester) async {
        final (controller, closed) = await openModal(
          tester,
          physics: (context) =>
              SheetOverdrag.physicsOf(context, const BouncingScrollPhysics()),
        );

        final gesture = await tester.startGesture(
          tester.getCenter(find.text('row 2')),
        );
        await gesture.moveBy(const Offset(0, slop));
        await gesture.moveBy(const Offset(0, 100));
        await tester.pump();

        expect(controller.offset, 0);
        expect(topOf(tester), closeTo(sheetTop + 100, 5));

        await gesture.moveBy(const Offset(0, 300));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(closed(), isTrue);
      },
      variant: platforms,
    );

    /// Clamping physics hand the offset on to the configuration's link. It
    /// matters when one move crosses the top: the outer link leaves the list
    /// its part, and the inner one would take that part for the sheet again.
    testWidgets('a list wrapped twice moves the sheet once', (tester) async {
      final (controller, _) = await openModal(
        tester,
        physics: (context) =>
            SheetOverdrag.physicsOf(context, const ClampingScrollPhysics()),
      );
      controller.jumpTo(100);
      await tester.pump();

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('row 6')),
      );
      await gesture.moveBy(const Offset(0, slop));
      await gesture.moveBy(const Offset(0, 150));
      await tester.pump();

      expect(controller.offset, 0);
      expect(topOf(tester), closeTo(sheetTop + 50, 5));

      await gesture.up();
    }, variant: platforms);
  });

  group('A sheet with its own offset in pixels', () {
    /// Shows the sheet with a list.
    Future<(_PixelSheetState, ScrollController)> openSheet(
      WidgetTester tester,
    ) async {
      setScreen(tester);
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: _PixelSheet(
            key: sheetKey,
            child: SizedBox(height: sheetHeight, child: list(controller)),
          ),
        ),
      );
      return (tester.state<_PixelSheetState>(find.byKey(sheetKey)), controller);
    }

    ///
    testWidgets('at the top the sheet follows the finger and is let go', (
      tester,
    ) async {
      final (sheet, controller) = await openSheet(tester);

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('row 2')),
      );
      await gesture.moveBy(const Offset(0, slop));
      await gesture.moveBy(const Offset(0, 100));
      await tester.pump();

      expect(controller.offset, 0);
      expect(sheet.dragOffset, closeTo(100, 5));

      await gesture.up();
      await tester.pump();

      expect(sheet.releasedVelocity, isNotNull);
    }, variant: platforms);

    ///
    testWidgets(
      'a scrolled list reaches its top first, then the sheet moves',
      (tester) async {
        final (sheet, controller) = await openSheet(tester);
        controller.jumpTo(100);
        await tester.pump();

        final gesture = await tester.startGesture(
          tester.getCenter(find.text('row 6')),
        );
        await gesture.moveBy(const Offset(0, slop));
        await gesture.moveBy(const Offset(0, 150));
        await tester.pump();

        expect(controller.offset, 0);
        expect(sheet.dragOffset, closeTo(50, 5));

        await gesture.up();
      },
      variant: platforms,
    );

    ///
    testWidgets('a swipe short of the top leaves the sheet alone', (
      tester,
    ) async {
      final (sheet, controller) = await openSheet(tester);
      controller.jumpTo(300);
      await tester.pump();

      await tester.timedDrag(
        find.text('row 8'),
        const Offset(0, 100),
        const Duration(seconds: 1),
      );
      await tester.pumpAndSettle();

      expect(sheet.dragOffset, 0);
      expect(sheet.releasedVelocity, isNull);
    }, variant: platforms);
  });
}

/// A sheet that keeps its offset in pixels itself, as a full-screen player
/// dragged down to minimize does. Like the player, it has a drag of its own:
/// that one competes with the list for the gesture, and without it the list
/// would win at once, with the drag slop going to the sheet too.
final class _PixelSheet extends StatefulWidget {
  ///
  const _PixelSheet({required this.child, super.key});

  ///
  final Widget child;

  ///
  @override
  State<_PixelSheet> createState() => _PixelSheetState();
}

///
final class _PixelSheetState extends State<_PixelSheet>
    implements SheetOverdragTarget {
  ///
  double _offset = 0;

  /// The speed the sheet was let go at; `null` — not let go.
  double? releasedVelocity;

  ///
  @override
  double get dragOffset => _offset;

  ///
  @override
  bool get isDraggable => true;

  ///
  @override
  void dragTo(double offset) => setState(() => _offset = offset);

  ///
  @override
  void release(double velocity) => releasedVelocity = velocity;

  ///
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (details) =>
          dragTo((_offset + details.delta.dy).clamp(0, double.infinity)),
      child: Transform.translate(
        offset: Offset(0, _offset),
        child: SheetOverdrag(target: this, child: widget.child),
      ),
    );
  }
}
