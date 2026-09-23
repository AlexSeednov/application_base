import 'package:application_base/presentation/utility/application_locale.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

/// Formatters follow the language the application resolved, not the one the
/// device speaks: an application without English formats in its own language
/// on an English phone, and follows the system to another language it
/// supports.
void main() {
  /// No English: the device language of the tests is not among them.
  const List<Locale> supportedLocales = [Locale('ru'), Locale('de')];

  /// A bare [WidgetsApp]: only its locale resolution is under test.
  Widget application() => WidgetsApp(
    color: const Color(0xFF000000),
    supportedLocales: supportedLocales,
    localeListResolutionCallback: ApplicationLocale.resolve,
    builder: (_, _) => const SizedBox.shrink(),
  );

  // A global: every test starts and ends with it unset.
  setUp(() => Intl.defaultLocale = null);

  tearDown(() => Intl.defaultLocale = null);

  testWidgets('an unsupported device language falls back to the first one', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(application());

    expect(Intl.defaultLocale, 'ru');
    expect(NumberFormat.decimalPattern().format(1.5), '1,5');
  });

  testWidgets('a change of the system languages reaches the formatters', (
    tester,
  ) async {
    tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);

    await tester.pumpWidget(application());

    tester.platformDispatcher.localesTestValue = const [Locale('de', 'DE')];
    await tester.pump();

    expect(Intl.defaultLocale, 'de');
  });
}
