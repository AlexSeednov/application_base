import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
/// the aim the previous press set, and the page walks towards that aim on
/// every frame — see [_HeldScroll] — so holding a key scrolls a full step per
/// repeat, the way a browser page does.
final class ScrollActionPro extends ScrollAction {
  /// The framework's own answer says yes to any client of the route
  /// controller and to a scrollable of any axis; [invoke] then finds nothing
  /// to move, and the key is spent on standing still. The same lookup for
  /// both, so a key the action cannot use is left to whoever is next.
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
}

/// Scrolls on [KeyboardScrollIntent]; the scrollable is the vertical one the
/// arrows would move, see [_scrollableOf].
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

    return _scrollableOf(context, Axis.vertical)?.position;
  }
}

/// The scrollable a key moves, looked up the way the framework's [ScrollAction]
/// does it: the scrollable around the focused widget, and without one — the
/// route's [PrimaryScrollController] with exactly one position. Two things are
/// asked for on top: the [axis], since the nearest scrollable of the other
/// axis would otherwise answer and refuse the step, leaving a page with a
/// carousel in focus unscrollable; and a finished layout, since a position
/// without one has neither an offset nor dimensions to move between. `null` —
/// nothing to move.
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

///
ScrollableState? _laidOut(ScrollableState scrollable) =>
    _HeldScroll.isReady(scrollable.position) ? scrollable : null;

/// The aim of the keys, and the page drawn towards it.
///
/// A press does not animate the page: it moves the aim, and a single ticker —
/// started with the first press, stopped once the page has arrived — draws
/// the page after it, frame by frame, with a pull that is critically damped
/// and tuned to the pace the key repeats at. Held down, the page trails the
/// aim by a fixed distance and therefore holds exactly the speed the repeats
/// ask for; released, it closes that distance and stops. Nothing is lost on
/// the way: the page always ends where the presses aimed it.
///
/// An animation per press cannot do that, and that is why one is no longer
/// started. Each is a ticker of its own, and a ticker reports zero elapsed
/// time on its first tick: the frame that starts an animation leaves the page
/// exactly where it was. A key repeating every two or three frames therefore
/// spent every other frame standing still, and a repeat arriving off the beat
/// re-timed the animation under it. The page covered the whole distance — in
/// visible jerks.
///
/// The pull is measured against the pace because the pace is what the page is
/// following. Pulled harder than the repeats arrive, the page runs up to each
/// step and waits for the next one, which is the jerking again in a milder
/// form; pulled softer, it drifts ever further behind. Both ends are visible:
/// with the repeats of a slow key half a second apart, a pull tuned to a fast
/// one turns each step into a separate lurch.
abstract final class _HeldScroll {
  /// How hard the page is pulled towards the aim, in pulls per interval of
  /// the repeats. The pull is critically damped — it never overshoots — and
  /// at this strength the page settles about four intervals after the key.
  static const double _followFactor = 1.2;

  /// The pace assumed for a press that stands alone: the response of a single
  /// step, and the pace a hold starts adapting from.
  static const Duration _freshInterval = Duration(milliseconds: 28);

  /// Slowest pace the follow adapts to. Slower than this the page is being
  /// scrolled press by press rather than by a held key, and a pull that soft
  /// would leave every one of those presses drifting.
  static const Duration _maxInterval = Duration(milliseconds: 200);

  /// Longest gap between two presses that still counts as a pace. An OS waits
  /// about half a second before the first repeat, and that wait says nothing
  /// about how fast the ones after it will come.
  static const Duration _holdWindow = Duration(milliseconds: 250);

  /// Weight of the newest gap in the pace, the rest being the pace so far.
  /// Two or three repeats settle it, and a single late one does not throw it.
  static const double _paceWeight = 0.6;

  /// Distance at which the page is put on the aim exactly and the follow
  /// ends: a pull of this kind never quite arrives on its own.
  static const double _snapDistance = 0.5;

  /// Speed under which the page counts as standing still, px/ms. Distance
  /// alone would end the follow as the page flies through the aim.
  static const double _snapSpeed = 0.03;

  /// Upper bound of the frame the follow is measured over. The frames stop
  /// with a hidden tab and the clock does not: the first frame back would
  /// otherwise carry the whole pause at once.
  static const Duration _maxFrame = Duration(milliseconds: 100);

  /// How far ahead of the page the aim may run, in viewports. A safety valve:
  /// however many repeats arrive while the application is busy, the page
  /// cannot end up owing seconds of scrolling after the key is up.
  static const double _maxBacklog = 3;

  /// Longest a run may go without a frame before it is taken as gone. A
  /// ticker whose frames were dropped from under it — a test binding stops
  /// them between tests — says it is active and never ticks again, and the
  /// next press would wait on it forever.
  static const Duration _tickWindow = Duration(milliseconds: 200);

  /// Carries the follow: built with the run and let go with it, since the
  /// keys move one page at a time.
  static Ticker? _ticker;

  /// The page being followed; `null` — the follow is over. Cleared with it, so
  /// that a page which has left the tree is not held alive by an old aim.
  static ScrollPosition? _position;

  /// Where the page is headed.
  static double _target = 0;

  /// Speed of the page, px/ms, carried between the frames of a run: it is the
  /// state a damped pull is made of, and what keeps the page from stopping at
  /// every step of a held key.
  static double _velocity = 0;

  /// The pace the presses arrive at, ms.
  static double _interval = 0;

  /// Elapsed time of the run when the aim last moved. The pace is measured on
  /// the clock of the ticker — the one the follow itself runs on — so it is
  /// counted in frames rather than in wall time, and a repeat that arrives
  /// between two frames is measured from the frame it is answered on.
  static Duration _aimTick = Duration.zero;

  /// The offset the follow last left the page at, to tell its own movement
  /// from everyone else's.
  static double _written = 0;

  /// Elapsed time of the previous frame of the follow.
  static Duration _lastTick = Duration.zero;

  /// When the run last had a frame, by the clock rather than by the ticker:
  /// it is the ticker itself that is being checked for signs of life.
  static DateTime _lastFrame = DateTime.fromMillisecondsSinceEpoch(0);

  /// Whether the position has been laid out: any other has neither an offset
  /// nor dimensions.
  static bool isReady(ScrollPosition position) =>
      position.hasPixels &&
      position.hasContentDimensions &&
      position.hasViewportDimension;

  /// One step of a held or single key press: the aim moves on, the page
  /// follows. A repeat adds to the aim the previous press set rather than to
  /// the offset the page has reached by then — the distance between the two
  /// is the follow trailing the key, not a step lost.
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

  /// A move to a fixed target — the ends of the page. Held down it repeats
  /// against an aim that no longer changes, and the follow carries on to it.
  static void settle(ScrollPosition position, double target) =>
      _aim(position, target);

  /// Points the follow at [target], takes the pace of the presses, and puts
  /// the page in motion.
  static void _aim(ScrollPosition position, double target) {
    final DateTime now = DateTime.now();

    /// A press that arrives with the page already at rest starts a run of its
    /// own, and the pace of whatever was pressed before it says nothing about
    /// the pace of this one — an OS waits about half a second before the
    /// first repeat of a held key.
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

  /// The pace after a gap of [sinceAim] between two presses. A gap too long
  /// to be a repeat leaves the pace of a single step: the key is being
  /// pressed by hand.
  static double _paced(Duration sinceAim) {
    if (sinceAim > _holdWindow) return _freshInterval.inMilliseconds.toDouble();

    return (_interval + (sinceAim.inMilliseconds - _interval) * _paceWeight)
        .clamp(
          _freshInterval.inMilliseconds.toDouble(),
          _maxInterval.inMilliseconds.toDouble(),
        );
  }

  /// One frame of the follow. Both the pull and the speed are per unit of
  /// time, so the page moves the same distance per second on a 60 and on a
  /// 120 Hz screen.
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

    /// Someone else has moved the page — a drag, the wheel, a jump to a
    /// focused widget: the keys step aside rather than fight for the offset.
    if ((position.pixels - _written).abs() > precisionErrorTolerance) {
      _stop();
      return;
    }

    /// A lazy list grows its extent as it builds, and shrinks it when its
    /// content goes: the aim is kept on the page it is aimed at.
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

    /// The exact answer of a critically damped pull over the frame, rather
    /// than a step of it: a frame is long next to the pull, and stepping it
    /// would leave the page wobbling on a slow one.
    final double pull = _followFactor / _interval;
    final double decay = math.exp(-pull * time);
    final double slope = _velocity + pull * distance;
    final double before = position.pixels;

    _velocity = (_velocity - pull * slope * time) * decay;
    position.pointerScroll(target + (distance + slope * time) * decay - before);
    _written = position.pixels;

    /// The page has nowhere left to go — the end of a list the key is still
    /// held against.
    if (_written == before) _stop();
  }

  /// Whether the page is still in the tree — the follow outlives by a frame
  /// or two the route it was started on, and an offset written into a page
  /// that has gone is written into a disposed notifier.
  ///
  /// The context is taken from the notification one and not from the storage
  /// one: the latter is the `State` of the scrollable itself and throws once
  /// it is unmounted, which is the very case being asked about.
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
