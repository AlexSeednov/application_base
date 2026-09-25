import 'package:application_base/presentation/service/browser_context_menu_service.dart';
import 'package:application_base/presentation/view/context_menu_region.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Outside the web the region only adds the right-button call of the menu:
/// the browser flag the web branch toggles is not reachable from a VM test.
void main() {
  ///
  Widget harness({required VoidCallback? onMenu}) => Directionality(
    textDirection: TextDirection.ltr,
    child: Center(
      child: ContextMenuRegion(
        onMenu: onMenu,
        child: const SizedBox.square(dimension: 100),
      ),
    ),
  );

  testWidgets('a right click opens the menu', (tester) async {
    int menuCount = 0;
    await tester.pumpWidget(harness(onMenu: () => menuCount++));

    await tester.tap(
      find.byType(ContextMenuRegion),
      buttons: kSecondaryMouseButton,
      kind: PointerDeviceKind.mouse,
    );

    expect(menuCount, 1);
  });

  testWidgets('without a menu the region adds nothing', (tester) async {
    await tester.pumpWidget(harness(onMenu: null));

    expect(
      find.descendant(
        of: find.byType(ContextMenuRegion),
        matching: find.byType(MouseRegion),
      ),
      findsNothing,
    );
  });

  test('hold passes the result of the action through', () async {
    final int result = await BrowserContextMenuService.hold(() async => 42);

    expect(result, 42);
  });
}
