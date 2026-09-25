import 'dart:async';

import 'package:application_base/core/service/logger_service.dart';
import 'package:application_base/core/service/platform_service.dart';
import 'package:flutter/services.dart';

/// Suppression of the browser's own context menu.
///
/// It cannot be turned off per element: the engine calls `preventDefault` on
/// the `contextmenu` event of the root node of the whole application, and
/// there is nothing to switch but one shared flag. Precision comes from
/// timing instead — a region raises the flag while the cursor is over it and
/// lowers it on the way out. That is in time: the call reaches the engine
/// synchronously, the listener is in place within the same tick as the hover
/// event, and only the answer is asynchronous.
///
/// The flag has several owners — the region under the cursor and an open
/// menu the cursor has already left the region for — hence the counter: only
/// the last owner may give the browser its menu back.
abstract final class BrowserContextMenuService {
  // MARK: Data

  /// How many owners require the suppression right now.
  static int _suppressionCount = 0;

  // MARK: Base functions

  /// Suppresses the browser menu until the paired [release].
  static void suppress() {
    if (!isWeb) return;

    _suppressionCount++;
    if (_suppressionCount > 1) return;

    unawaited(BrowserContextMenu.disableContextMenu());
  }

  /// Gives the browser its menu back if nobody requires the suppression
  /// anymore.
  static void release() {
    if (!isWeb) return;

    /// An extra release means a suppression lost somewhere: the counter has
    /// drifted from the number of owners, and the browser menu risks staying
    /// off across the whole application
    if (_suppressionCount == 0) {
      logError(error: 'Browser context menu: unbalanced release');

      return;
    }

    _suppressionCount--;
    if (_suppressionCount > 0) return;

    unawaited(BrowserContextMenu.enableContextMenu());
  }

  /// Holds the suppression while [action] runs — for a menu already open:
  /// under it the cursor leaves the region, and the region releases its own
  /// suppression.
  static Future<T> hold<T>(Future<T> Function() action) async {
    suppress();

    try {
      return await action();
    } finally {
      release();
    }
  }
}
