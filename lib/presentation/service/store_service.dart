import 'package:application_base/core/mixin/logging_mixin.dart';
import 'package:application_base/core/service/platform_service.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:injectable/injectable.dart';

/// Opens the store page of the application.
///
/// One place for every reason to send the user there — rating the app, taking
/// an update the backend now demands — because it is one and the same page.
///
// Future(Alex): the in-app rating sheet is deliberately left out. The system
// shows it at its own discretion and does nothing at all once the user has
// rated the application or the platform quota is spent — while
// `isAvailable()` keeps answering true, so an application cannot tell a shown
// sheet from a swallowed one. A tap on an explicit "rate us" control has to
// land somewhere every time, and only the store listing does. It comes back
// the day the flow is driven by the app itself (after N sessions, say) rather
// than by a button.
@lazySingleton
final class StoreService with LoggingMixin {
  ///
  @visibleForTesting
  StoreService();

  ///
  @override
  String get logName => 'Store Service';

  /// Identifier of the application in the App Store, set once on start-up.
  String? _appStoreId;

  /// Platforms the plugin can open a store listing on.
  ///
  /// Everywhere else there is no store to send anyone to, so the application
  /// hides the control instead of offering one that leads nowhere.
  bool get isAvailable => isAndroid || isIOS || isMacOS;

  /// Platforms that cannot find the listing without [_appStoreId].
  bool get _isAppStoreIdRequired => isIOS || isMacOS;

  /// Store identity of the application, handed over once on start-up.
  ///
  /// The identifier belongs to the application rather than to a single tap,
  /// so it is set here instead of travelling with every [openListing].
  set appStoreId(String? value) => _appStoreId = value;

  /// Open the store page of the application.
  Future<void> openListing() async {
    if (!isAvailable) return;

    if (_isAppStoreIdRequired && (_appStoreId?.isEmpty ?? true)) {
      logNamedError(error: 'no App Store id set, nothing to open');
      return;
    }

    try {
      await InAppReview.instance.openStoreListing(appStoreId: _appStoreId);

      logNamedInfo(info: 'store listing opened');
    } catch (e) {
      logNamedError(error: 'store listing opening exception: $e');
    }
  }
}
