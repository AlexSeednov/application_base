/// Injectable facade over the static `UrlLauncher`.
///
/// Depending on this contract instead of the static `UrlLauncher` lets a
/// project register a recording fake in tests and assert launch intents without
/// hitting a platform channel. The default `UrlLauncherRouter` implementation
/// ships in `url_launcher_router.dart` and is registered by the package's
/// injectable module — a project takes the contract from getIt or its
/// constructor and must not bind it a second time.
///
/// Every method returns `true` on success and `false` on failure, mirroring
/// `UrlLauncher`.
abstract interface class UrlLauncherPro {
  /// Opens [url] in an external application.
  Future<bool> open(String url);

  /// Opens the email client prefilled with [to], [title] and [body].
  Future<bool> sendEmail({
    required String to,
    required String title,
    required String body,
  });

  /// Opens the phone dialer for [number].
  Future<bool> call(String number);

  /// Opens the messaging app with [text] prefilled.
  Future<bool> sendSms(String text);
}
