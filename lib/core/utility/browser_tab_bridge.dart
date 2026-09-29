/// Non-web branch of `BrowserTab`: outside a browser there is no page to
/// reload and no second tab to share a marker with, so every call does
/// nothing and there is never a marker to read.
void reloadTab() {}

///
String? readTabMarker(String key) => null;

///
void writeTabMarker(String key, String value) {}

///
void watchTabMarker(String key, void Function() onChange) {}
