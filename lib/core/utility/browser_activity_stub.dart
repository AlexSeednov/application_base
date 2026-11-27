/// Outside the web, application activity is handled by the native lifecycle.
abstract final class BrowserActivity {
  /// No browser visibility restrictions apply.
  static bool get isVisible => true;

  /// No browser focus restrictions apply.
  static bool get hasFocus => true;

  /// Native applications never receive browser events.
  static Stream<void> get changes => const Stream.empty();
}
