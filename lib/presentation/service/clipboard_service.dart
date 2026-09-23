import 'dart:async';

import 'package:application_base/core/service/service_locator.dart';
import 'package:application_base/presentation/service/haptic_service.dart';
import 'package:flutter/services.dart';

/// The system clipboard with a haptic cue on every copy: the copied text
/// gives no visual feedback of its own, so the tap has to be felt.
abstract final class ClipboardService {
  ///
  static Future<void> set(String text) async {
    await Clipboard.setData(ClipboardData(text: text));

    unawaited(getIt<HapticService>().lightImpact());
  }

  /// `''` when the clipboard holds no text.
  static Future<String> get() async {
    final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);

    return data?.text ?? '';
  }
}
