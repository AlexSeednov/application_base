import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Page scrolling keys on top of Flutter's own map: on the web Flutter maps
/// the arrows, PageUp/PageDown and Space itself, but not Home/End and
/// Shift+Space.
///
/// The maps go into `MaterialApp.shortcuts` / `actions` and extend the
/// defaults: there they sit above the text-editing shortcuts, so a focused
/// text field handles its keys first.
abstract final class KeyboardShortcutsPro {
  ///
  static Map<ShortcutActivator, Intent> get shortcuts => {
    ...WidgetsApp.defaultShortcuts,
    const SingleActivator(LogicalKeyboardKey.home): const KeyboardScrollIntent(
      KeyboardScrollKind.toStart,
    ),
    const SingleActivator(LogicalKeyboardKey.end): const KeyboardScrollIntent(
      KeyboardScrollKind.toEnd,
    ),
    const SingleActivator(LogicalKeyboardKey.home, control: true):
        const KeyboardScrollIntent(KeyboardScrollKind.toStart),
    const SingleActivator(LogicalKeyboardKey.end, control: true):
        const KeyboardScrollIntent(KeyboardScrollKind.toEnd),
    const SingleActivator(LogicalKeyboardKey.space, shift: true):
        const KeyboardScrollIntent(KeyboardScrollKind.pageUp),
  };

  ///
  static Map<Type, Action<Intent>> get actions => {
    ...WidgetsApp.defaultActions,
    KeyboardScrollIntent: KeyboardScrollAction(),
  };
}

/// Kind of a keyboard-driven scroll.
enum KeyboardScrollKind {
  /// To the start of the page.
  toStart,

  /// To the end of the page.
  toEnd,

  /// One page up.
  pageUp,
}

/// Intent to scroll the page with the keyboard.
final class KeyboardScrollIntent extends Intent {
  ///
  const KeyboardScrollIntent(this.kind);

  ///
  final KeyboardScrollKind kind;
}

/// Scrolls on [KeyboardScrollIntent]. The scrollable is looked up the way the
/// built-in [ScrollAction] does it: around the focused widget, and without one
/// — the route's [PrimaryScrollController] with exactly one position.
///
/// Inside a text field the keys stay with the field: Home/End move the caret
/// and Shift+Space is a plain space typed with Shift held. The web
/// text-editing shortcuts do not intercept these combinations, so the check
/// lives here.
final class KeyboardScrollAction extends ContextAction<KeyboardScrollIntent> {
  /// Share of the viewport per key press — as the built-in page step.
  static const double _pageFraction = 0.8;

  /// Animation duration — as the built-in action.
  static const Duration _duration = Duration(milliseconds: 100);

  ///
  @override
  bool isEnabled(KeyboardScrollIntent intent, [BuildContext? context]) =>
      _positionOf(context) != null;

  ///
  @override
  void invoke(KeyboardScrollIntent intent, [BuildContext? context]) {
    final ScrollPosition? position = _positionOf(context);
    if (position == null) return;

    final double target = switch (intent.kind) {
      KeyboardScrollKind.toStart => position.minScrollExtent,
      KeyboardScrollKind.toEnd => position.maxScrollExtent,
      KeyboardScrollKind.pageUp =>
        (position.pixels - position.viewportDimension * _pageFraction).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
    };
    if (target == position.pixels) return;

    unawaited(
      position.animateTo(target, duration: _duration, curve: Curves.easeInOut),
    );
  }

  /// The position the key moves; `null` — nothing to move.
  ScrollPosition? _positionOf(BuildContext? context) {
    if (context == null) return null;
    if (context.findAncestorStateOfType<EditableTextState>() != null) {
      return null;
    }

    final ScrollableState? scrollable = Scrollable.maybeOf(
      context,
      axis: Axis.vertical,
    );
    if (scrollable != null) return _readyPosition(scrollable.position);

    final ScrollController? controller = PrimaryScrollController.maybeOf(
      context,
    );
    if (controller == null || controller.positions.length != 1) return null;

    return _readyPosition(controller.position);
  }

  /// A position that has been laid out: any other has neither an offset nor
  /// dimensions.
  static ScrollPosition? _readyPosition(ScrollPosition position) {
    final bool isReady =
        position.hasPixels &&
        position.hasContentDimensions &&
        position.hasViewportDimension;

    return isReady ? position : null;
  }
}
