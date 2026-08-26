import 'package:url_launcher/url_launcher_string.dart';

/// Non-web branch of `UrlLauncher.launchLinkViaLocation`: there is no browser
/// location to assign, so the link goes through a plain default launch —
/// mirroring the non-web behavior of `UrlLauncher.launchLinkInSameTab`
Future<bool> navigateViaLocation(String link) => launchUrlString(link);
