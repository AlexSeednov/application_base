import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Page-scrolling keys on top of Flutter's defaults.
///
/// On the web Flutter maps the arrows, PageUp/PageDown and Space, but not
/// Home/End, Shift+Space or the combinations a macOS browser scrolls a page
/// with. Its Apple map does not help: on the web `defaultShortcuts` returns
/// the web map whatever the host OS, and where the Apple map applies, it
/// moves Cmd+arrow by a line instead of to the ends of the page.
///
/// The maps go into `MaterialApp.shortcuts` / `actions` and extend the
/// defaults. There they sit above the text-editing shortcuts, so a focused
/// text field handles its keys first. The actions also replace the
/// framework's [ScrollAction]; see [ScrollActionPro] for what a held key does
/// without it.
abstract final class KeyboardShortcutsPro {
  ///
  static Map<ShortcutActivator, Intent> get shortcuts => {
    ...WidgetsApp.defaultShortcuts,
    ..._commonShortcuts,
    if (_isApple) ..._appleShortcuts,
  };

  /// The keys that mean the same on every platform.
  static const Map<ShortcutActivator, Intent> _commonShortcuts = {
    SingleActivator(LogicalKeyboardKey.home): KeyboardScrollIntent(
      KeyboardScrollKind.toStart,
    ),
    SingleActivator(LogicalKeyboardKey.end): KeyboardScrollIntent(
      KeyboardScrollKind.toEnd,
    ),
    SingleActivator(LogicalKeyboardKey.home, control: true):
        KeyboardScrollIntent(KeyboardScrollKind.toStart),
    SingleActivator(LogicalKeyboardKey.end, control: true):
        KeyboardScrollIntent(KeyboardScrollKind.toEnd),
    SingleActivator(LogicalKeyboardKey.space, shift: true):
        KeyboardScrollIntent(KeyboardScrollKind.pageUp),
  };

  /// The keys a macOS browser scrolls a page with: Cmd+arrow to the ends,
  /// Option+arrow by a screen. Apple platforms only: elsewhere the same keys
  /// are Alt+arrow, and Alt+left/right is the browser's back/forward.
  ///
  /// No Cmd+left/right: Safari, Chrome and Firefox walk the history with it,
  /// and a key the application does not handle is left to the browser. Bound
  /// to a horizontal scroll, it would take back/forward away from the user.
  ///
  /// The horizontal pair goes through the framework's [ScrollIntent]:
  /// [KeyboardScrollAction] moves only the page's vertical scrollable, while
  /// [ScrollActionPro] takes the axis from the intent and moves the focused
  /// scrollable — in practice, a carousel.
  static const Map<ShortcutActivator, Intent> _appleShortcuts = {
    SingleActivator(LogicalKeyboardKey.arrowUp, meta: true):
        KeyboardScrollIntent(KeyboardScrollKind.toStart),
    SingleActivator(LogicalKeyboardKey.arrowDown, meta: true):
        KeyboardScrollIntent(KeyboardScrollKind.toEnd),
    SingleActivator(LogicalKeyboardKey.home, meta: true): KeyboardScrollIntent(
      KeyboardScrollKind.toStart,
    ),
    SingleActivator(LogicalKeyboardKey.end, meta: true): KeyboardScrollIntent(
      KeyboardScrollKind.toEnd,
    ),
    SingleActivator(LogicalKeyboardKey.arrowUp, alt: true):
        KeyboardScrollIntent(KeyboardScrollKind.pageUp),
    SingleActivator(LogicalKeyboardKey.arrowDown, alt: true):
        KeyboardScrollIntent(KeyboardScrollKind.pageDown),
    SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true): ScrollIntent(
      direction: AxisDirection.left,
      type: ScrollIncrementType.page,
    ),
    SingleActivator(LogicalKeyboardKey.arrowRight, alt: true): ScrollIntent(
      direction: AxisDirection.right,
      type: ScrollIncrementType.page,
    ),
  };

  /// Whether the host lays out modifiers the Apple way. On the web
  /// [defaultTargetPlatform] follows the host OS, so this holds there too.
  static bool get _isApple =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.iOS;

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

  /// One screen up.
  pageUp,

  /// One screen down.
  pageDown,
}

/// Intent to scroll the page with the keyboard.
final class KeyboardScrollIntent extends Intent {
  ///
  const KeyboardScrollIntent(this.kind);

  ///
  final KeyboardScrollKind kind;
}

/// Replaces the framework's [ScrollAction] for [ScrollIntent]: the arrows,
/// PageUp/PageDown and Space.
///
/// The framework animates each press over 100ms with an eased curve, from
/// the offset the page holds at that moment. A held key repeats every
/// 30–60ms, so each repeat cancels the previous animation early in its slow
/// start: the page crawls at a fraction of a step per press. Here a repeat
/// adds its step to the target of the previous press and [_HeldScroll] moves
/// the page towards it every frame, so a held key scrolls a full step per
/// repeat, as a browser page does.
final class ScrollActionPro extends ScrollAction {
  /// The framework's check accepts any client of the route controller and a
  /// scrollable of either axis; [invoke] then finds nothing to move and the
  /// key is swallowed. Both use the same lookup here, so a key this action
  /// cannot use passes on to the next handler.
  @override
  bool isEnabled(ScrollIntent intent, [BuildContext? context]) =>
      _scrollableOf(context, axisDirectionToAxis(intent.direction)) != null;

  ///
  @override
  void invoke(ScrollIntent intent, [BuildContext? context]) {
    final ScrollableState? scrollable = _scrollableOf(
      context,
      axisDirectionToAxis(intent.direction),
    );
    if (scrollable == null) return;

    final ScrollPosition position = scrollable.position;

    /// Physics of a locked list refuse the offset; the key still stops here
    /// rather than scrolling the page around the list.
    final ScrollPhysics? physics = scrollable.resolvedPhysics;
    if (physics != null && !physics.shouldAcceptUserOffset(position)) return;

    final double increment = ScrollAction.getDirectionalIncrement(
      scrollable,
      intent,
    );
    if (increment == 0) return;

    _HeldScroll.step(position, increment);
  }
}

/// Handles [KeyboardScrollIntent] on the vertical scrollable the arrows would
/// move, see [_scrollableOf].
///
/// Inside a text field the keys stay with the field: Home/End move the caret
/// and Shift+Space types a space. The web text-editing shortcuts do not
/// intercept these keys, so the check lives here. They do intercept the
/// Apple ones (from inside a field Cmd/Option+arrow go to the browser); the
/// check covers those all the same.
final class KeyboardScrollAction extends ContextAction<KeyboardScrollIntent> {
  /// Share of the viewport per screen step, as in the framework's page step.
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

    final double page = position.viewportDimension * _pageFraction;

    /// Screen steps are held like any other key, so they add up on the
    /// target; the ends of the page are fixed targets and need no adding up.
    switch (intent.kind) {
      case KeyboardScrollKind.pageUp:
        _HeldScroll.step(position, -page);
      case KeyboardScrollKind.pageDown:
        _HeldScroll.step(position, page);
      case KeyboardScrollKind.toStart:
        _HeldScroll.settle(position, position.minScrollExtent);
      case KeyboardScrollKind.toEnd:
        _HeldScroll.settle(position, position.maxScrollExtent);
    }
  }

  /// The position the key moves; `null` — nothing to move.
  ScrollPosition? _positionOf(BuildContext? context) {
    if (context == null) return null;
    if (context.findAncestorStateOfType<EditableTextState>() != null) {
      return null;
    }

    return _scrollableOf(context, Axis.vertical)?.position;
  }
}

/// The scrollable a key moves; `null` — nothing to move.
///
/// Looked up as the framework's [ScrollAction] does: the scrollable around
/// the focused widget, else the route's [PrimaryScrollController] if it has
/// exactly one position. On top of that it requires:
/// - the [axis]: otherwise the nearest scrollable of the other axis answers
///   and refuses the step, and a page with a carousel in focus cannot scroll;
/// - a finished layout: before it a position has no offset or dimensions.
ScrollableState? _scrollableOf(BuildContext? context, Axis axis) {
  if (context == null) return null;

  final ScrollableState? focused = Scrollable.maybeOf(context, axis: axis);
  if (focused != null) return _laidOut(focused);

  final ScrollController? controller = PrimaryScrollController.maybeOf(context);
  if (controller == null || controller.positions.length != 1) return null;

  final BuildContext? notification =
      controller.position.context.notificationContext;
  if (notification == null) return null;

  final ScrollableState? primary = Scrollable.maybeOf(notification);

  return primary == null ? null : _laidOut(primary);
}

/// [scrollable] once laid out; `null` before that.
ScrollableState? _laidOut(ScrollableState scrollable) =>
    _HeldScroll.isReady(scrollable.position) ? scrollable : null;

/// The target of the scrolling keys, and the follow that moves the page to it.
///
/// A press moves the target instead of animating the page. One ticker —
/// started by the first press, stopped once the page arrives — pulls the page
/// towards the target every frame, critically damped and tuned to the pace
/// the key repeats at. While the key is held, the page trails the target by a
/// fixed distance and so moves at exactly the speed the repeats ask for; on
/// release it closes the gap and stops. Nothing is lost: the page always ends
/// where the presses aimed.
///
/// No animation per press: each runs its own ticker, and a ticker reports zero
/// elapsed time on its first tick, so the frame that starts an animation
/// leaves the page in place. With a key repeating every two or three frames,
/// every other frame stands still, and a repeat off the beat re-times the
/// running animation: the page covers the distance in visible jerks.
///
/// The pull follows the pace because the pace is what the page follows.
/// Pulled harder, the page runs up to each step and waits for the next — a
/// milder form of the same jerk; pulled softer, it falls ever further behind.
/// No fixed pull fits every key: one tuned to a fast key turns each step of a
/// slow one, with repeats half a second apart, into a separate lurch.
abstract final class _HeldScroll {
  /// Pull strength towards the target, per repeat interval. Critically
  /// damped, so it never overshoots; at this strength the page settles about
  /// four intervals after the last press.
  static const double _followFactor = 1.2;

  /// The pace assumed for a lone press: it sets how fast a single step lands,
  /// and a hold starts adapting from it.
  static const Duration _freshInterval = Duration(milliseconds: 28);

  /// Slowest pace the follow adapts to. Slower presses are separate presses,
  /// not a held key, and a pull that soft would leave each of them drifting.
  static const Duration _maxInterval = Duration(milliseconds: 200);

  /// Longest gap between two presses that still counts as a pace. The OS
  /// waits about half a second before the first repeat, and that wait says
  /// nothing about how fast the repeats after it come.
  static const Duration _holdWindow = Duration(milliseconds: 250);

  /// Weight of the newest gap in the pace, the rest being the pace so far.
  /// Two or three repeats settle it, and a single late one does not throw it.
  static const double _paceWeight = 0.6;

  /// Distance under which the page snaps onto the target and the follow ends:
  /// a damped pull never quite arrives on its own.
  static const double _snapDistance = 0.5;

  /// Speed under which the page counts as standing still, px/ms. Distance
  /// alone would end the follow while the page flies through the target.
  static const double _snapSpeed = 0.03;

  /// Longest frame the follow accounts for. A hidden tab stops the frames but
  /// not the clock, so the first frame back would otherwise carry the whole
  /// pause at once.
  static const Duration _maxFrame = Duration(milliseconds: 100);

  /// How far the target may run ahead of the page, in viewports. However many
  /// repeats pile up while the application is busy, the page never owes
  /// seconds of scrolling after the key is released.
  static const double _maxBacklog = 3;

  /// Longest a run may go without a frame before it counts as dead. A ticker
  /// whose frames stop coming (a test binding stops them between tests) still
  /// reports itself active and never ticks again, and the next press would
  /// wait on it forever.
  static const Duration _tickWindow = Duration(milliseconds: 200);

  /// Drives the follow; created with a run and disposed with it. One is
  /// enough: the keys move one page at a time.
  static Ticker? _ticker;

  /// The page being followed; `null` — no follow. Cleared when the follow
  /// ends, so a stale target does not keep a removed page alive.
  static ScrollPosition? _position;

  /// Where the page is headed.
  static double _target = 0;

  /// Page speed, px/ms, carried across the frames of a run: the damped pull
  /// needs it as state, and it keeps the page from stopping at every step of
  /// a held key.
  static double _velocity = 0;

  /// The pace the presses arrive at, ms.
  static double _interval = 0;

  /// Run time when the target last moved. The pace is measured on the
  /// ticker's clock, the one the follow runs on: in frames rather than wall
  /// time, so a repeat that arrives between two frames takes the time of the
  /// last one.
  static Duration _aimTick = Duration.zero;

  /// Offset the follow last wrote, to tell its own movement from anyone
  /// else's.
  static double _written = 0;

  /// Elapsed time of the previous frame of the follow.
  static Duration _lastTick = Duration.zero;

  /// Wall time of the run's last frame. Wall clock rather than the ticker's:
  /// it is the ticker itself being checked for signs of life.
  static DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);

  /// Whether the position has been laid out; before that it has no offset or
  /// dimensions.
  static bool isReady(ScrollPosition position) =>
      position.hasPixels &&
      position.hasContentDimensions &&
      position.hasViewportDimension;

  /// Moves the target by [increment] for a single or repeated press. A repeat
  /// adds to the previous target, not to the offset the page has reached: the
  /// gap between the two is the follow trailing the key, not a lost step.
  static void step(ScrollPosition position, double increment) {
    final double backlog = position.viewportDimension * _maxBacklog;
    final double base = identical(_position, position)
        ? _target
        : position.pixels;

    _aim(
      position,
      (base + increment).clamp(
        math.max(position.minScrollExtent, position.pixels - backlog),
        math.min(position.maxScrollExtent, position.pixels + backlog),
      ),
    );
  }

  /// Moves towards a fixed [target] — an end of the page. Repeats of a held
  /// key aim at the same target, and the follow carries on to it.
  static void settle(ScrollPosition position, double target) =>
      _aim(position, target);

  /// Points the follow at [target], updates the pace, and starts the ticker
  /// unless a run is under way.
  static void _aim(ScrollPosition position, double target) {
    final DateTime now = DateTime.now();

    /// A press with the page at rest starts a run of its own: the pace of
    /// earlier presses says nothing about this one, since the OS waits about
    /// half a second before the first repeat of a held key.
    final bool isFollowing =
        (_ticker?.isActive ?? false) &&
        now.difference(_lastFrame) < _tickWindow;

    _interval = isFollowing
        ? _paced(_lastTick - _aimTick)
        : _freshInterval.inMilliseconds.toDouble();
    _aimTick = _lastTick;
    _position = position;
    _target = target;
    _written = position.pixels;
    if (isFollowing) return;

    _ticker?.dispose();
    _velocity = 0;
    _lastTick = Duration.zero;
    _aimTick = Duration.zero;
    _lastFrame = now;
    _ticker = Ticker(_onTick)..start();
  }

  /// The pace after a gap of [sinceAim] since the previous press. A gap too
  /// long for a repeat means the key is pressed by hand, and resets the pace
  /// to that of a single step.
  static double _paced(Duration sinceAim) {
    if (sinceAim > _holdWindow) return _freshInterval.inMilliseconds.toDouble();

    return (_interval + (sinceAim.inMilliseconds - _interval) * _paceWeight)
        .clamp(
          _freshInterval.inMilliseconds.toDouble(),
          _maxInterval.inMilliseconds.toDouble(),
        );
  }

  /// One frame of the follow. The pull and the speed are per unit of time, so
  /// the page moves as fast on a 60 Hz screen as on a 120 Hz one.
  static void _onTick(Duration elapsed) {
    final Duration frame = elapsed - _lastTick;
    _lastTick = elapsed;
    _lastFrame = DateTime.now();

    final ScrollPosition? position = _position;
    if (position == null || !_isAlive(position)) {
      _stop();
      return;
    }
    if (frame <= Duration.zero) return;

    /// Something else moved the page (a drag, the wheel, a jump to a focused
    /// widget): the follow yields rather than fight over the offset.
    if ((position.pixels - _written).abs() > precisionErrorTolerance) {
      _stop();
      return;
    }

    /// A lazy list grows its extent as it builds and shrinks it as content
    /// goes, so the target is clamped to the current extent every frame.
    final double target = _target.clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    final double distance = position.pixels - target;
    if (distance.abs() < _snapDistance && _velocity.abs() < _snapSpeed) {
      if (distance != 0) position.pointerScroll(-distance);
      _stop();

      return;
    }

    final Duration step = frame > _maxFrame ? _maxFrame : frame;
    final double time =
        step.inMicroseconds / Duration.microsecondsPerMillisecond;

    /// The exact solution of the critically damped pull over the frame, not a
    /// numeric step: a frame is long next to the pull, and stepping would
    /// leave the page wobbling on a slow frame.
    final double pull = _followFactor / _interval;
    final double decay = math.exp(-pull * time);
    final double slope = _velocity + pull * distance;
    final double before = position.pixels;

    _velocity = (_velocity - pull * slope * time) * decay;
    position.pointerScroll(target + (distance + slope * time) * decay - before);
    _written = position.pixels;

    /// The page did not move: it is at the end of a list the key is still
    /// held against.
    if (_written == before) _stop();
  }

  /// Whether the page is still in the tree. The follow can outlive its route
  /// by a frame or two, and an offset written into a removed page goes into a
  /// disposed notifier.
  ///
  /// Checks [ScrollContext.notificationContext], not
  /// [ScrollContext.storageContext]: the latter is the scrollable's own
  /// `State`, which throws once unmounted — the very case being checked.
  static bool _isAlive(ScrollPosition position) =>
      isReady(position) &&
      (position.context.notificationContext?.mounted ?? false);

  ///
  static void _stop() {
    _ticker?.dispose();
    _ticker = null;
    _position = null;
    _velocity = 0;
  }
}
