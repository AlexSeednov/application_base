import 'package:application_base/presentation/view/slotted_scroll_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

///
void main() {
  testWidgets('padding stays inside the slots and the footer follows content', (
    tester,
  ) async {
    const header = ValueKey('header');
    const footer = ValueKey('footer');
    const content = ValueKey('content');
    final controller = ScrollController();
    addTearDown(controller.dispose);

    ///
    Widget page(double height) => MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            height: 400,
            child: PrimaryScrollController(
              controller: controller,
              child: SlottedScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                header: const SizedBox(key: header, height: 30),
                footer: const SizedBox(
                  key: footer,
                  height: 40,
                  width: double.infinity,
                ),
                sliver: SliverToBoxAdapter(
                  child: SizedBox(key: content, height: height),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(page(80));
    expect(tester.getRect(find.byKey(header)).width, 300);
    expect(tester.getRect(find.byKey(content)).width, 252);
    expect(
      tester.getRect(find.byKey(footer)),
      const Rect.fromLTWH(0, 360, 300, 40),
    );
    expect(controller.position.maxScrollExtent, 0);

    await tester.pumpWidget(page(500));
    expect(controller.position.maxScrollExtent, 170);
    controller.jumpTo(170);
    await tester.pump();
    expect(
      tester.getRect(find.byKey(content)).bottom,
      tester.getRect(find.byKey(footer)).top,
    );
    expect(tester.getRect(find.byKey(footer)).bottom, 400);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
