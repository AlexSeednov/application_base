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
abstract final class ApplicationLocale {
  /// The locale the application runs in, by Flutter's own algorithm
  /// ([basicLocaleListResolution]), made the default locale of `intl`.
  ///
  /// Pass it to `MaterialApp.localeListResolutionCallback` as is. The
  /// application calls it on start-up and again whenever the system languages
  /// change, before any widget below it builds, so a formatter never needs a
  /// locale argument. Hand over the tear-off, not a closure: the application
  /// compares callbacks by identity on every rebuild.
  static Locale resolve(
    List<Locale>? preferredLocales,
    Iterable<Locale> supportedLocales,
  ) {
    final Locale locale = basicLocaleListResolution(
      preferredLocales,
      supportedLocales,
    );
    final String localeName = Intl.canonicalizedLocale(locale.toString());

    if (Intl.defaultLocale != localeName) {
      Intl.defaultLocale = localeName;
      logInfo(
        info: 'Application locale: $localeName (system: $preferredLocales)',
      );
    }

    return locale;
  }
}
