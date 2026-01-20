import 'package:application_base/core/service/logger_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

///
abstract final class UrlLauncher {
  /// Check and try to open a link.
  /// Return **true** on success
  static Future<bool> launchLink(
    String? link, {
    LaunchMode mode = LaunchMode.externalApplication,
  }) async {
    if (link == null || link.isEmpty) return false;

    try {
      if (!await canLaunchUrlString(link)) {
        logError(error: 'Can not launch the link $link');
        return false;
      }

      if (await launchUrlString(link, mode: mode)) return true;

      /// Maybe a problem with selected launch mode
      if (mode != LaunchMode.inAppBrowserView) {
        /// Try to open in app browser
        logInfo(info: 'Error on launching the link $link via $mode');
        if (await launchUrlString(link, mode: LaunchMode.inAppBrowserView)) {
          return true;
        }
      }

      logError(error: 'Error on launching the link $link');
    } catch (error) {
      logError(error: 'Error on launching the link $link: $error');
    }
    return false;
  }

  /// Try to open email application with prepeared email.
  /// Return **true** on success
  static Future<bool> sendEmail({
    required String to,
    required String title,
    required String body,
  }) async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: to,
      query: encodeQueryParameters(<String, String>{
        'subject': title,
        'body': body,
      }),
    );
    return launchUrl(emailLaunchUri);
  }

  /// Try to make a call via phone application.
  /// Return **true** on success
  static Future<bool> makeCall(String number) => launchLink('tel:$number!');

  /// Try to send an sms via message application.
  /// Return **true** on success
  static Future<bool> sendSms(String text) => launchLink('sms:?body=$text');

  ///
  static String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map(
          (MapEntry<String, String> e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }
}
