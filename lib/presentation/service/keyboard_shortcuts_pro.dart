import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Page scrolling keys on top of Flutter's own map: on the web Flutter maps
/// the arrows, PageUp/PageDown and Space itself, but not Home/End and
/// Shift+Space.
///
/// The maps go into `MaterialApp.shortcuts` / `actions` and extend the
/// defaults: there they sit above the text-editing shortcuts, so a focused
/// text field handles its keys first. The actions replace the framework's own
/// [ScrollAction] as well — see [ScrollActionPro] for what a held key does
/// without it.
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
    ScrollIntent: ScrollActionPro(),
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

/// Scrolls on [ScrollIntent] — the arrows, PageUp/PageDown and the space bar
/// — in place of the framework's own [ScrollAction].
///
/// The framework aims every press at the offset the page happens to hold at
/// that moment and animates there over 100ms with an eased curve. A held key
/// repeats every 30–60ms, so each repeat cancels the previous animation
/// somewhere in its slow opening and starts a new one from there: the page
/// crawls at a fraction of a step per press. Here a repeat adds its step to
/// the target the previous press aimed at and the animation is driven at the
/// pace the key repeats, so holding a key scrolls a full step per repeat, the
/// way a browser page does. A single press is left as it was.
final class ScrollActionPro extends ScrollAction {
  ///
  @override
  void invoke(ScrollIntent intent, [BuildContext? context]) {
    final ScrollableState? scrollable = _scrollableFor(intent, context);
    if (scrollable == null) return;

    final ScrollPosition position = scrollable.position;
    if (!_HeldScroll.isReady(position)) return;

    /// The physics of a locked list refuse the offset, and the page below it
    /// must not take the key instead.
    final ScrollPhysics? physics = scrollable.resolvedPhysics;
    if (physics != null && !physics.shouldAcceptUserOffset(position)) return;

    final double increment = ScrollAction.getDirectionalIncrement(
      scrollable,
      intent,
    );
    if (increment == 0) return;

    _HeldScroll.step(position, increment);
  }

  /// The scrollable the key moves, looked up as the framework does it, except
  /// that the axis of the intent is asked for by name: the nearest scrollable
  /// of the other axis would otherwise answer and refuse the step, leaving a
  /// page with a carousel in focus unscrollable.
  ScrollableState? _scrollableFor(ScrollIntent intent, BuildContext? context) {
    if (context == null) return null;

    final ScrollableState? scrollable = Scrollable.maybeOf(
      context,
      axis: axisDirectionToAxis(intent.direction),
    );
    if (scrollable != null) return scrollable;

    final ScrollController? controller = PrimaryScrollController.maybeOf(
      context,
    );
    if (controller == null || controller.positions.length != 1) return null;

    final BuildContext? notification =
        controller.position.context.notificationContext;

    return notification == null ? null : Scrollable.maybeOf(notification);
  }
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

  ///
  @override
  bool isEnabled(KeyboardScrollIntent intent, [BuildContext? context]) =>
      _positionOf(context) != null;

  ///
  @override
  void invoke(KeyboardScrollIntent intent, [BuildContext? context]) {
    final ScrollPosition? position = _positionOf(context);
    if (position == null) return;

    /// A page step is held down as often as any other, so it goes through the
    /// same aim; the ends of the page are a fixed target and need none.
    if (intent.kind == KeyboardScrollKind.pageUp) {
      _HeldScroll.step(position, -position.viewportDimension * _pageFraction);
      return;
    }

    final double target = intent.kind == KeyboardScrollKind.toStart
        ? position.minScrollExtent
        : position.maxScrollExtent;

    _HeldScroll.settle(position, target);
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
  static ScrollPosition? _readyPosition(ScrollPosition position) =>
      _HeldScroll.isReady(position) ? position : null;
}

/// The aim of a held key.
///
/// A repeat adds its step to the target the previous press aimed at rather
/// than to the offset the page has crawled to by then, and the animation runs
/// at the pace of the repeats instead of a fixed 100ms: the page then moves a
/// whole step per press and stops with the key rather than coasting on.
abstract final class _HeldScroll {
  /// Where each position is aiming. An [Expando] rather than a field: a page
  /// that has left the tree must not be held alive by the aim of a key
  /// pressed on it.
  static final Expando<double> _targets = Expando<double>('held scroll');

  /// Longest gap between two steps that still reads as one held key. An OS
  /// repeats a key several times a second; anything slower is a new press.
  static const Duration _holdWindow = Duration(milliseconds: 400);

  /// Animation of a single press — as the built-in action.
  static const Duration _singleStep = Duration(milliseconds: 100);

  /// Bounds of the animation of a held step: a frame at the fast end, and the
  /// duration of a single press at the slow one.
  static const Duration _minStep = Duration(milliseconds: 16);

  ///
  static const Duration _maxStep = _singleStep;

  /// How far ahead of the page the aim may run, in viewports. A safety valve:
  /// however many repeats arrive while the application is busy, the page
  /// cannot end up owing seconds of scrolling after the key is up.
  static const double _maxBacklog = 3;

  /// When the previous step was asked for.
  static DateTime _lastStep = DateTime.fromMillisecondsSinceEpoch(0);

  /// Whether the position has been laid out: any other has neither an offset
  /// nor dimensions.
  static bool isReady(ScrollPosition position) =>
      position.hasPixels &&
      position.hasContentDimensions &&
      position.hasViewportDimension;

  /// One step of a held or single key press.
  static void step(ScrollPosition position, double increment) {
    final DateTime now = DateTime.now();
    final Duration sinceLast = now.difference(_lastStep);
    _lastStep = now;

    final double? aim = _targets[position];

    /// A repeat arrives while the previous step is still running: the page
    /// moving on its own is what tells a held key from a new press.
    final bool isHeld =
        aim != null &&
        sinceLast < _holdWindow &&
        position.isScrollingNotifier.value;

    final double backlog = position.viewportDimension * _maxBacklog;
    final double target = ((isHeld ? aim : position.pixels) + increment).clamp(
      math.max(position.minScrollExtent, position.pixels - backlog),
      math.min(position.maxScrollExtent, position.pixels + backlog),
    );
    _targets[position] = target;
    if (target == position.pixels) return;

    unawaited(
      position.moveTo(
        target,
        duration: isHeld ? _heldStep(sinceLast) : _singleStep,
        curve: isHeld ? Curves.linear : Curves.easeInOut,
      ),
    );
  }

  /// A move to a fixed target — the ends of the page. Held down it repeats
  /// against a target that no longer changes, so the animation is left to run
  /// instead of being restarted into a standstill.
  static void settle(ScrollPosition position, double target) {
    _lastStep = DateTime.now();
    if (_targets[position] == target && position.isScrollingNotifier.value) {
      return;
    }

    _targets[position] = target;
    if (target == position.pixels) return;

    unawaited(
      position.moveTo(target, duration: _singleStep, curve: Curves.easeInOut),
    );
  }

  /// The step is animated over the interval the key repeats at, so the
  /// movement is continuous and ends with the key.
  static Duration _heldStep(Duration interval) => Duration(
    milliseconds: interval.inMilliseconds.clamp(
      _minStep.inMilliseconds,
      _maxStep.inMilliseconds,
    ),
  );
}
