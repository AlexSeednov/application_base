import 'dart:async';

import 'package:application_base/core/utility/browser_activity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Lets an editable field resume input after the browser regains focus.
///
/// Place it around the application's navigator. It acts when the document
/// regains focus and the original field is still eligible for input.
final class WebTextFocusRestorer extends StatefulWidget {
  ///
  const WebTextFocusRestorer({
    required this.child,
    this.hasBrowserFocus = _hasBrowserFocus,
    this.activityChanges,
    super.key,
  });

  ///
  final Widget child;

  ///
  @visibleForTesting
  final ValueGetter<bool> hasBrowserFocus;

  ///
  @visibleForTesting
  final Stream<void>? activityChanges;

  ///
  static bool _hasBrowserFocus() => BrowserActivity.hasFocus;

  ///
  @override
  State<WebTextFocusRestorer> createState() => _WebTextFocusRestorerState();
}

///
final class _WebTextFocusRestorerState extends State<WebTextFocusRestorer> {
  ///
  final FocusManager _focusManager = FocusManager.instance;

  ///
  StreamSubscription<void>? _activitySubscription;

  ///
  late bool _browserHadFocus;

  ///
  FocusNode? _lastActiveFocus;

  ///
  @override
  void initState() {
    super.initState();
    if (!kIsWeb && widget.activityChanges == null) return;

    _browserHadFocus = widget.hasBrowserFocus();
    _rememberFocus();
    _focusManager.addListener(_rememberFocus);
    _activitySubscription = (widget.activityChanges ?? BrowserActivity.changes)
        .listen(_onBrowserActivity);
  }

  ///
  @override
  void dispose() {
    if (_activitySubscription != null) {
      _focusManager.removeListener(_rememberFocus);
    }
    unawaited(_activitySubscription?.cancel());
    super.dispose();
  }

  /// Flutter can unfocus the field before the browser dispatches `blur`.
  void _rememberFocus() {
    if (_browserHadFocus && widget.hasBrowserFocus()) {
      _lastActiveFocus = _focusManager.primaryFocus;
    }
  }

  ///
  void _onBrowserActivity(void _) {
    final bool browserHasFocus = widget.hasBrowserFocus();
    if (_browserHadFocus == browserHasFocus) return;
    _browserHadFocus = browserHasFocus;
    if (!browserHasFocus) return;

    final FocusNode? previousFocus = _lastActiveFocus;
    _rememberFocus();
    if (previousFocus == null || previousFocus.hasFocus) return;
    if (previousFocus.parent == null || !previousFocus.canRequestFocus) return;

    // Respect any control that received focus in the meantime.
    final FocusNode? currentFocus = _focusManager.primaryFocus;
    if (currentFocus != previousFocus.enclosingScope &&
        currentFocus != _focusManager.rootScope) {
      return;
    }

    final BuildContext? fieldContext = previousFocus.context;
    if (fieldContext == null || !fieldContext.mounted) return;
    if (ModalRoute.isCurrentOf(fieldContext) == false) return;

    final field = fieldContext.findAncestorStateOfType<EditableTextState>();
    if (field == null ||
        field.widget.focusNode != previousFocus ||
        field.widget.readOnly) {
      return;
    }

    // Reopen the keyboard connection with the current selection.
    field.requestKeyboard();
  }

  ///
  @override
  Widget build(BuildContext context) => widget.child;
}
