import 'dart:ui_web' as ui_web;

import 'package:web/web.dart' as web;

/// Makes an in-app route a browser URL, including the URL strategy and base
/// path. The link plugin must treat it as a URL even if Flutter delivers the
/// activation after the browser has already cancelled the original click.
Uri browserLinkUri(Uri uri) {
  if (uri.hasScheme) return uri;

  final String path =
      ui_web.urlStrategy?.prepareExternalUrl(uri.toString()) ?? uri.toString();

  return Uri.parse(web.document.baseURI).resolve(path);
}
