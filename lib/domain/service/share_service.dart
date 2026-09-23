import 'package:application_base/core/service/logger_service.dart';
import 'package:application_base/core/service/platform_service.dart';
import 'package:share_plus/share_plus.dart';

/// Wrapper over the platform share sheet.
abstract final class ShareService {
  // Optimize(Alex): expose the other `ShareParams` options.
  /// Never throws; returns whether the share sheet was actually presented.
  ///
  /// `false` means sharing is unavailable and the caller applies its own
  /// fallback (e.g. copies the link to the clipboard). Dismissing the sheet is
  /// not a failure. On the web the `mailto:` fallback is off — opening a mail
  /// client is not sharing — and unavailability is an expected browser state,
  /// so it is not logged; elsewhere a failure is abnormal and logged.
  static Future<bool> share({required String text}) async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, mailToFallbackEnabled: false),
      );
      return true;
    } catch (e) {
      if (!isWeb) logError(error: 'Share error: $e');
      return false;
    }
  }
}
