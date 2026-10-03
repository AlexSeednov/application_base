import 'package:application_base/core/service/logger_service.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// The language of the interface, and the one `intl` formats dates and numbers
/// in.
///
/// Left alone, `DateFormat` and `NumberFormat` take the device's locale, not
/// the one the application resolved: on an English phone a Russian-only
/// application renders its text in Russian while months, weekdays and decimal
/// separators come out in English. Pinning the locale in every formatter call
/// hides that and has to be undone for each language added.
///
/// Wraps the application in `MaterialApp.builder`. The locale is read from the
/// application's [Localizations], so it follows whatever chose the language —
/// the system, `MaterialApp.locale`, a resolution callback — and switches
/// together with the text, once the new translations have loaded. A
/// formatter below never needs a locale argument.
///
/// Not a resolution callback: Flutter calls one for the system languages and
/// for `MaterialApp.locale` alike, so it cannot tell a language chosen in the
/// application from the system's, and does not call it at all when
/// `MaterialApp.locale` is dropped.
final class ApplicationLocale extends StatefulWidget {
  ///
  const ApplicationLocale({required this.child, super.key});

  ///
  final Widget child;

  ///
  @override
  State<ApplicationLocale> createState() => _ApplicationLocaleState();
}

///
final class _ApplicationLocaleState extends State<ApplicationLocale> {
  /// Runs on the first build and on every switch of [Localizations], before
  /// the widgets below rebuild in the new language.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final String localeName = Intl.canonicalizedLocale(
      Localizations.localeOf(context).toString(),
    );
    if (Intl.defaultLocale == localeName) return;

    Intl.defaultLocale = localeName;
    logInfo(
      info:
          'Application locale: $localeName '
          '(system: ${WidgetsBinding.instance.platformDispatcher.locales})',
    );
  }

  ///
  @override
  Widget build(BuildContext context) => widget.child;
}
