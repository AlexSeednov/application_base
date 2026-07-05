import 'package:application_base/data/remote/utility/url_launcher.dart';
import 'package:application_base/data/remote/utility/url_launcher_pro.dart';
import 'package:injectable/injectable.dart';

/// [UrlLauncherPro] backed by the static [UrlLauncher].
///
/// Thin adapter: every method delegates to the matching `UrlLauncher` helper.
@LazySingleton(as: UrlLauncherPro)
final class UrlLauncherRouter implements UrlLauncherPro {
  ///
  UrlLauncherRouter();

  ///
  @override
  Future<bool> open(String url) => UrlLauncher.launchLink(url);

  ///
  @override
  Future<bool> sendEmail({
    required String to,
    required String title,
    required String body,
  }) => UrlLauncher.sendEmail(to: to, title: title, body: body);

  ///
  @override
  Future<bool> call(String number) => UrlLauncher.makeCall(number);

  ///
  @override
  Future<bool> sendSms(String text) => UrlLauncher.sendSms(text);
}
