import 'package:application_base/core/service/logger_service.dart';
import 'package:application_base/core/service/platform_service.dart';
import 'package:application_base/core/utility/browser_tab_bridge.dart'
    if (dart.library.js_interop) 'package:application_base/core/utility/browser_tab_bridge_web.dart';

/// The browser tab a web build runs in: reloading it, and a marker it shares
/// with the other tabs of the same site.
///
/// Outside the web there is neither. [isAvailable] is `false`, [readMarker]
/// answers `null`, and the rest does nothing — so code on top of it compiles
/// and runs on every platform without a check of its own.
abstract final class BrowserTab {
  ///
  static bool get isAvailable => isWeb;

  /// A full reload, as with the browser button.
  ///
  /// The only way to rebuild what the running application cannot swap in
  /// place: screens built for a session another tab has replaced, or data
  /// that failed to load while the network was down.
  static void reload() {
    logInfo(info: 'Browser tab reload');
    reloadTab();
  }

  /// The marker lives in `localStorage`, not next to the application's own
  /// storage: unlike IndexedDB, a change to it is announced by the browser to
  /// every other tab of the site.
  ///
  /// `null` — no marker: it was never written, the site data was cleared, or
  /// the browser forbids the site to store data (logged).
  static String? readMarker(String key) => readTabMarker(key);

  /// The other tabs hear the write, this one does not.
  static void writeMarker(String key, String value) =>
      writeTabMarker(key, value);

  /// [onChange] fires when another tab changes the marker or clears the site
  /// storage, and also when this tab becomes visible again: a tab frozen in
  /// the background may miss the storage event, and a check on its return
  /// closes that gap. So the callback is a hint to re-read the marker, not a
  /// promise that it changed.
  ///
  /// Watches for the lifetime of the tab — there is nothing to cancel.
  static void watchMarker(String key, void Function() onChange) =>
      watchTabMarker(key, onChange);
}
