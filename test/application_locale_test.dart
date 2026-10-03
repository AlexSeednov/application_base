import 'package:application_base/presentation/utility/application_locale.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

/// Formatters follow the language the interface is drawn in, not the one the
/// device speaks: an application without English formats in its own language
/// on an English phone, follows the system to another language it supports,
/// and keeps a language chosen in the application whatever the system does.
void main() {
  /// No English: the device language of the tests is not among them.
  const List<Locale> supportedLocales = [Locale('ru'), Locale('de')];

  /// A bare [WidgetsApp]: only its locale is under test. [locale] — the
  /// language chosen in the application, `null` to follow the system.
  Widget application({Locale? locale}) => WidgetsApp(
    color: const Color(0xFF000000),
    supportedLocales: supportedLocales,
    locale: locale,
    builder: (_, _) => const ApplicationLocale(child: SizedBox.shrink()),
  );

  /// Sets the system languages until the end of the test.
  void systemLocales(WidgetTester tester, List<Locale> locales) {
    tester.platformDispatcher.localesTestValue = locales;
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
  }

  // A global: every test starts and ends with it unset.
  setUp(() => Intl.defaultLocale = null);

  tearDown(() => Intl.defaultLocale = null);

  testWidgets('an unsupported device language falls back to the first one', (
    tester,
  ) async {
    systemLocales(tester, const [Locale('en', 'US')]);

    await tester.pumpWidget(application());

    expect(Intl.defaultLocale, 'ru');
    expect(NumberFormat.decimalPattern().format(1.5), '1,5');
  });

  testWidgets('a change of the system languages reaches the formatters', (
    tester,
  ) async {
    systemLocales(tester, const [Locale('en', 'US')]);

    await tester.pumpWidget(application());

    systemLocales(tester, const [Locale('de', 'DE')]);
    await tester.pump();

    expect(Intl.defaultLocale, 'de');
  });

  testWidgets('a language chosen in the application wins over the system', (
    tester,
  ) async {
    systemLocales(tester, const [Locale('ru', 'RU')]);

    await tester.pumpWidget(application(locale: const Locale('de')));

    expect(Intl.defaultLocale, 'de');
  });

  /// The case the resolution callback got wrong: the system languages change
  /// without changing the system's choice, nothing rebuilds, and the callback
  /// had already handed `intl` the system language.
  testWidgets('the chosen language outlasts a change of the system languages', (
    tester,
  ) async {
    systemLocales(tester, const [Locale('ru', 'RU')]);

    await tester.pumpWidget(application(locale: const Locale('de')));

    systemLocales(tester, const [Locale('ru', 'RU'), Locale('en', 'US')]);
    await tester.pump();

    expect(Intl.defaultLocale, 'de');
  });

  testWidgets('switching the chosen language reaches the formatters', (
    tester,
  ) async {
    systemLocales(tester, const [Locale('en', 'US')]);

    await tester.pumpWidget(application(locale: const Locale('de')));
    await tester.pumpWidget(application(locale: const Locale('ru')));

    expect(Intl.defaultLocale, 'ru');
  });

  testWidgets('dropping the chosen language returns to the system one', (
    tester,
  ) async {
    systemLocales(tester, const [Locale('ru', 'RU')]);

    await tester.pumpWidget(application(locale: const Locale('de')));
    await tester.pumpWidget(application());

    expect(Intl.defaultLocale, 'ru');
  });
}
