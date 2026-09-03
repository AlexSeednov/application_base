import 'dart:async';

import 'package:application_base/core/service/platform_service.dart';
import 'package:application_base/presentation/view/empty_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/link.dart';

/// A tap target that on the web is also a real link: the URL shows on hover,
/// the browser context menu offers "Open in new tab" and "Copy link address",
/// Ctrl/Cmd+click and the middle button open the target in a new tab.
///
/// The link is either a page of the app (an absolute in-app path) or an
/// external URL. An external one gets `target="_blank"`: the browser opens it
/// in a new tab on its own, the way the app opens such links itself.
///
/// A plain click stays with the app and goes to [onClick] — the same push as
/// before: the page gets whatever data the view model already holds, and the
/// tab stack is not rebuilt from the URL. Only a click with a modifier key is
/// handed to the link: the browser opens the new tab itself. Without a
/// `followLink` signal from the app the plugin cancels the in-tab navigation
/// on its own (`url_launcher_web`, `LinkTriggerSignals`), so a plain click
/// never reloads the page.
///
/// Outside the web, and without a [path], it is a plain [EmptyButton].
final class RouteLink extends StatelessWidget {
  ///
  const RouteLink({
    required this.path,
    required this.onClick,
    required this.child,
    this.focusBorderRadius,
    super.key,
  });

  /// Absolute in-app path of the page (`/catalog/product/1`, query included)
  /// or an external URL (`https://…`); `null` — no link, tap only.
  final String? path;

  /// `null` — the target is disabled: neither tap nor link.
  final VoidCallback? onClick;

  ///
  final Widget child;

  /// Rounding of the focus ring, see [EmptyButton.focusBorderRadius].
  final BorderRadius? focusBorderRadius;

  ///
  @override
  Widget build(BuildContext context) {
    if (!isWeb || onClick == null || path == null) return _button(onClick);

    // Parsed, not `Uri(path:)`: a path with a query would otherwise get its
    // `?` percent-encoded and the router would not match it.
    final Uri uri = Uri.parse(path!);

    return Link(
      uri: uri,
      target: uri.hasScheme ? LinkTarget.blank : LinkTarget.defaultTarget,
      builder: (_, followLink) => _button(() => _onTap(followLink)),
    );
  }

  ///
  Widget _button(VoidCallback? onTap) => EmptyButton(
    onClick: onTap,
    focusBorderRadius: focusBorderRadius,
    child: child,
  );

  /// A click with a modifier key goes to the browser (new tab or window),
  /// everything else — to the app.
  void _onTap(FollowLink? followLink) {
    if (followLink != null && _isModifierPressed) {
      unawaited(followLink());
      return;
    }

    onClick!();
  }

  /// The same modifiers the plugin hands the click to the browser on.
  static bool get _isModifierPressed {
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;

    return keyboard.isControlPressed ||
        keyboard.isMetaPressed ||
        keyboard.isShiftPressed ||
        keyboard.isAltPressed;
  }
}
