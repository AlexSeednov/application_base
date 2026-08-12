import 'package:application_base/core/service/logger_service.dart';
import 'package:application_base/core/service/platform_service.dart';
import 'package:share_plus/share_plus.dart';

/// Wrapper over the platform share sheet.
abstract final class ShareService {
  // Optimize(Alex): добавить другие параметры
  /// Never throws; returns whether the share sheet was actually presented.
  /// `false` means sharing is unavailable and the caller should apply its own
  /// fallback (e.g. copy the link to the clipboard). Dismissing the sheet is
  /// not a failure. On web the `mailto:` fallback is disabled (opening a mail
  /// client is not sharing) and unavailability is an expected state of the
  /// browser, so it is not logged; everywhere else a failure is abnormal and
  /// gets logged here.
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
