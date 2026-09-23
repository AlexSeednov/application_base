import 'package:application_base/core/service/logger_service.dart';
import 'package:application_base/data/remote/utility/location_navigation.dart'
    if (dart.library.js_interop) 'package:application_base/data/remote/utility/location_navigation_web.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// Static helpers over `url_launcher`; every launch returns **true** on
/// success.
abstract final class UrlLauncher {
  /// Opens [link] with [mode], falling back to the in-app browser view.
  /// Return **true** on success; never throws.
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

      /// The requested mode may be unsupported for this link or platform.
      if (mode != LaunchMode.inAppBrowserView) {
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

  /// Open a link in the **current** browser tab. Web-oriented: made for the
  /// links whose navigation is handed over to the OS — custom application
  /// schemes and `intent://` — so the page (and the application state) stays
  /// in place. On non-web platforms behaves as a plain default launch.
  /// Return **true** on success.
  ///
  /// Deliberately skips the `canLaunch` check: the web implementation of
  /// url_launcher reports `false` for any non-standard scheme, while such
  /// links are exactly what this method exists for.
  ///
  /// The current tab instead of a new one on purpose: `_blank` is subject to
  /// popup blockers (especially iOS Safari), leaves a dead empty tab behind
  /// and steals the focus, breaking any "page stayed visible" fallback logic
  /// of the caller.
  static Future<bool> launchLinkInSameTab(String? link) async {
    if (link == null || link.isEmpty) return false;

    try {
      return await launchUrlString(link, webOnlyWindowName: '_self');
    } catch (error) {
      logError(error: 'Error on launching the link $link in same tab: $error');
    }
    return false;
  }

  /// Navigate the **current** browser tab to [link] by assigning it to
  /// `window.location` directly, bypassing `window.open`.
  ///
  /// [launchLinkInSameTab] requests the same behavior through url_launcher,
  /// whose web implementation always calls `window.open` with the `noopener`
  /// window feature. Spec-wise `_self` still means "this tab", but browsers
  /// with custom popup handling (Arc and alike) treat a feature-bearing
  /// `window.open` as a popup request and detach the page into a separate
  /// window — fatal for redirect flows (e.g. payment confirmation) that must
  /// return into the tab they left. A direct location assignment cannot
  /// create a browsing context by construction, in any browser.
  ///
  /// Prefer this method for web redirect flows leaving for another `https`
  /// page; [launchLinkInSameTab] stays for links handed over to the OS
  /// (custom application schemes, `intent://`).
  ///
  /// On non-web platforms behaves as a plain default launch.
  /// Return **true** on success.
  static Future<bool> launchLinkViaLocation(String? link) async {
    if (link == null || link.isEmpty) return false;

    try {
      return await navigateViaLocation(link);
    } catch (error) {
      logError(error: 'Error on launching the link $link via location: $error');
    }
    return false;
  }

  /// Try to open email application with prepared email.
  /// Return **true** on success; never throws.
  ///
  /// Skips the `canLaunch` check: on Android 11+ it answers `false` for
  /// `mailto:` unless the app declares the scheme in `<queries>`, while the
  /// launch itself works either way.
  static Future<bool> sendEmail({
    required String to,
    required String title,
    required String body,
  }) async {
    final uri = Uri(
      scheme: 'mailto',
      path: to,
      query: encodeQueryParameters(<String, String>{
        'subject': title,
        'body': body,
      }),
    );

    try {
      if (await launchUrl(uri)) return true;

      logError(error: 'Error on sending an email to $to');
    } catch (error) {
      logError(error: 'Error on sending an email to $to: $error');
    }
    return false;
  }

  /// Try to make a call via phone application.
  /// Return **true** on success
  static Future<bool> makeCall(String number) => launchLink('tel:$number');

  /// Try to send an sms via message application.
  /// Return **true** on success
  ///
  /// [text] is percent-encoded: a raw `&`, `#` or `%` would cut the body short.
  static Future<bool> sendSms(String text) =>
      launchLink('sms:?body=${Uri.encodeComponent(text)}');

  /// Percent-encodes a `mailto:` query: `Uri.queryParameters` would encode a
  /// space as `+`, which mail clients show literally.
  static String? encodeQueryParameters(Map<String, String> params) => params
      .entries
      .map(
        (e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
      )
      .join('&');
}
