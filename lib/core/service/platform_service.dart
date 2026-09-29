import 'dart:io' show Platform;

import 'package:application_base/core/utility/touch_input.dart'
    if (dart.library.js_interop) 'package:application_base/core/utility/touch_input_web.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kDebugMode, kIsWeb;

/// `isTouchInput` belongs with the other platform questions, and re-exporting
/// it here spares every caller the conditional clause the bridge needs.
export 'package:application_base/core/utility/touch_input.dart'
    if (dart.library.js_interop) 'package:application_base/core/utility/touch_input_web.dart';

// `Platform` throws on the web, so every getter below rules the web out
// before touching it.

///
enum AvailablePlatform {
  ///
  android,

  ///
  iOS,

  ///
  macOS,

  ///
  windows,

  ///
  linux,

  ///
  fuchsia,

  ///
  web,
}

// Optimize(Alex): add list of supported platforms based on AvailablePlatform?

///
bool get isDebug => kDebugMode;

///
bool get isAndroid => !isWeb && Platform.isAndroid;

///
bool get isIOS => !isWeb && Platform.isIOS;

///
bool get isMacOS => !isWeb && Platform.isMacOS;

///
bool get isWindows => !isWeb && Platform.isWindows;

///
bool get isLinux => !isWeb && Platform.isLinux;

///
bool get isFuchsia => !isWeb && Platform.isFuchsia;

///
bool get isWeb => kIsWeb;

///
bool get isMobileBased => !isWeb && (isAndroid || isIOS || isFuchsia);

///
bool get isDesktopBased => !isWeb && (isMacOS || isWindows || isLinux);

///
bool get isWebBased => isWeb;

/// A phone or a tablet, as an application or in a browser.
///
/// A question about the device, not about the window: a tablet in landscape
/// may well get a desktop layout, and a narrow browser window on a computer a
/// mobile one. Safari on iPadOS reports itself as macOS, so there a tablet is
/// told from a desktop Mac by touch input alone — [isTouchInput] explains
/// what a wrong guess means.
bool get isHandheld {
  if (!isWeb) return isMobileBased;

  return switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.android => true,
    TargetPlatform.macOS => isTouchInput,
    _ => false,
  };
}

///
String get currentPlatformString {
  if (isWeb) return 'web';
  return Platform.operatingSystem;
}

/// `null` when the host is none of the known platforms.
///
/// Deliberately nullable instead of defaulting to a plausible value: a wrong
/// platform is harder to notice than a missing one, and the caller is the only
/// one that knows what an unknown host should mean for it.
AvailablePlatform? get currentPlatform {
  if (isWeb) return AvailablePlatform.web;
  if (isAndroid) return AvailablePlatform.android;
  if (isIOS) return AvailablePlatform.iOS;
  if (isMacOS) return AvailablePlatform.macOS;
  if (isWindows) return AvailablePlatform.windows;
  if (isLinux) return AvailablePlatform.linux;
  if (isFuchsia) return AvailablePlatform.fuchsia;
  return null;
}
