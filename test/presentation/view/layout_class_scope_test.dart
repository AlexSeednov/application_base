import 'package:application_base/presentation/view/layout_class_scope.dart';
import 'package:application_base/presentation/view/layout_switcher.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// An application can use more than two layout classes with two screen bodies.
enum _WindowClass { compact, medium, expanded }

///
void main() {
  testWidgets('layout dependents rebuild only when the class changes', (
    tester,
  ) async {
    final width = ValueNotifier<double>(390);
    addTearDown(width.dispose);
    int layoutReads = 0;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ValueListenableBuilder<double>(
          valueListenable: width,
          builder: (_, value, child) => LayoutClassScope(
            layoutClass: switch (value) {
              >= 1000 => _WindowClass.expanded,
              >= 600 => _WindowClass.medium,
              _ => _WindowClass.compact,
            },
            child: child!,
          ),
          child: LayoutSwitcher(
            isWide: (context) {
              layoutReads++;
              return LayoutClassScope.maybeOf<_WindowClass>(context) !=
                  _WindowClass.compact;
            },
            compact: (_) => const Text('compact'),
            wide: (_) => const Text('wide'),
          ),
        ),
      ),
    );

    expect(find.text('compact'), findsOneWidget);
    expect(layoutReads, 1);

    width.value = 500;
    await tester.pump();
    expect(layoutReads, 1);

    width.value = 600;
    await tester.pump();
    expect(find.text('wide'), findsOneWidget);
    expect(layoutReads, 2);

    width.value = 1000;
    await tester.pump();
    expect(find.text('wide'), findsOneWidget);
    expect(layoutReads, 3);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
