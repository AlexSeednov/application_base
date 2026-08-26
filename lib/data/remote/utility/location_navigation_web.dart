import 'package:web/web.dart';

/// Web branch of `UrlLauncher.launchLinkViaLocation`: hand the link straight
/// to the browser location. A direct assignment cannot create a browsing
/// context, so the page is guaranteed to stay in the current tab — unlike
/// `window.open`, which some browsers detach into a popup window
Future<bool> navigateViaLocation(String link) async {
  window.location.assign(link);
  return true;
}
