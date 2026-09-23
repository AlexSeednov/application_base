import 'package:web/web.dart';

/// Web branch of `UrlLauncher.downloadLink`: click the link as an anchor with
/// the `download` attribute, the way a user would.
///
/// The empty attribute value lets the browser take the file name from the
/// link itself. The attribute is honored for same-origin links only, and a
/// link to another origin is simply opened — hence the new tab: the page with
/// the application stays in place either way.
bool downloadViaAnchor(String link) {
  HTMLAnchorElement()
    ..href = link
    ..download = ''
    ..target = '_blank'
    ..click();
  return true;
}
