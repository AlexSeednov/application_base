import 'dart:math' as math;

import 'package:application_base/presentation/utility/middle_button_default.dart'
    if (dart.library.js_interop)
        'package:application_base/presentation/utility/middle_button_default_web.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Middle-button autoscroll, as a browser gives a plain page: the press sets
/// an anchor, the mouse's travel from it sets the direction and speed, and a
/// click ends it.
///
/// On the web the browser cannot provide it: Flutter draws the application
/// into a canvas, and the document has no scrollable element of its own to
/// move. Wrap the whole application, above the navigator, so the anchor mark
/// and the pointer block cover pages, sheets and dialogs alike.
///
/// The scrolling goes out as a synthesized [PointerScrollEvent] aimed at the
/// anchor, like the wheel, rather than as a write into a scroll position: the
/// framework then picks the scrollable the user aimed at, keeps its physics,
/// and hands the movement to the parent once a nested list runs out. Only when
/// nothing under the anchor scrolls does the route's primary position — the
/// one the keyboard scrolls — take the step directly.
///
/// Only the user ends the mode: a click, the wheel or Escape. The cursor
/// leaving the window or the window losing the focus leaves it on: the aim
/// stops updating and the page keeps going the way it was last aimed, as in
/// the browser's own mode.
///
/// A platform without a middle button never starts the mode, so on a phone
/// the widget is inert.
final class AutoScrollPro extends StatefulWidget {
  ///
  const AutoScrollPro({required this.child, super.key});

  /// The application the mode scrolls.
  final Widget child;

  ///
  @override
  State<AutoScrollPro> createState() => _AutoScrollProState();
}

/// Lets a widget claim a middle click, so the mode does not start on it.
/// `RouteLink` does: over a link the middle button belongs to the browser,
/// which opens the link in a new tab.
final class AutoScrollScope extends InheritedWidget {
  ///
  const AutoScrollScope({
    required this.claimPointer,
    required super.child,
    super.key,
  });

  /// Takes the click of the given pointer away from the mode.
  final ValueSetter<int> claimPointer;

  /// `null` — the application is wired without the mode.
  static AutoScrollScope? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AutoScrollScope>();

  /// [maybeOf] reads the scope without subscribing, so there is no one to
  /// notify.
  @override
  bool updateShouldNotify(AutoScrollScope oldWidget) => false;
}

///
final class _AutoScrollProState extends State<AutoScrollPro>
    with SingleTickerProviderStateMixin {
  /// Radius around the anchor within which the page stands still. Past it,
  /// a held button also turns the press into a drag, whose release ends the
  /// mode.
  static const double _deadZone = 12;

  /// Scrolling speed per pixel of travel beyond [_deadZone], px/s.
  static const double _speedFactor = 8;

  /// Upper bound of the speed, px/s: past it a page is a blur anyway.
  static const double _maxSpeed = 4000;

  /// Diameter of the anchor mark.
  static const double _anchorSize = 30;

  /// Longest frame a step accounts for. The mode outlives a hidden tab, where
  /// the frames stop and the clock does not: unbounded, the first frame back
  /// would carry the whole pause and throw the page across the list at once.
  static const Duration _maxFrame = Duration(milliseconds: 100);

  /// Marks the wheel events the mode sends itself, so it does not take its
  /// own scrolling for the user's wheel and stop on the first frame. A real
  /// embedder numbers its events from zero up.
  static const int _syntheticEmbedderId = -1;

  /// Opens the pointer block for the mode's own events.
  final _GateLatch _latch = _GateLatch();

  /// Created in [initState], not on first use: [dispose] touches it, and in
  /// an application that never entered the mode it would be created there,
  /// where looking up the `TickerMode` ancestor is no longer safe.
  late final Ticker _ticker;

  /// The anchor in window coordinates, those of the pointer events and the
  /// hit test; `null` — the mode is off.
  Offset? _anchor;

  /// The anchor in this widget's coordinates, where the mark is drawn: a
  /// wrapper above may shift the two apart.
  Offset _anchorMark = Offset.zero;

  /// Latest position of the mouse.
  Offset _pointer = Offset.zero;

  /// The position the step is written into when no scrollable sits under the
  /// anchor; `null` — the wheel goes out instead.
  ScrollPosition? _fallback;

  /// The pointer whose click a link has claimed.
  int? _claimedPointer;

  /// Whether the button that started the mode is still down.
  bool _isHeld = false;

  /// Whether the held button has travelled far enough to read as a drag.
  bool _isDragged = false;

  /// Elapsed time of the previous frame of scrolling.
  Duration _lastTick = Duration.zero;

  /// Cursor over the whole application while the mode is on.
  MouseCursor _cursor = SystemMouseCursors.allScroll;

  ///
  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  ///
  @override
  void dispose() {
    holdMiddleButtonDefault(isHeld: false);
    HardwareKeyboard.instance.removeHandler(_onKey);
    _ticker.dispose();
    super.dispose();
  }

  ///
  @override
  Widget build(BuildContext context) {
    final bool isOn = _anchor != null;

    return AutoScrollScope(
      claimPointer: (pointer) => _claimedPointer = pointer,
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerHover: _onPointerHover,
        onPointerUp: _onPointerUp,
        onPointerSignal: _onPointerSignal,

        /// The stack stays whether the mode is on or off: moving the
        /// application to another depth of the tree would rebuild it from
        /// scratch and lose every scroll offset.
        child: Stack(
          fit: StackFit.expand,
          children: [
            _PointerGate(latch: _latch, child: widget.child),
            if (isOn) ...[
              Positioned(
                left: _anchorMark.dx - _anchorSize / 2,
                top: _anchorMark.dy - _anchorSize / 2,
                child: const IgnorePointer(
                  child: _AutoScrollAnchor(size: _anchorSize),
                ),
              ),

              /// Topmost, so the direction cursor wins over the application's
              /// own; translucent, so the hit test still reaches the block
              /// below.
              Positioned.fill(
                child: MouseRegion(
                  cursor: _cursor,
                  opaque: false,
                  hitTestBehavior: HitTestBehavior.translucent,
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// A middle click starts the mode; while it is on, any click ends it.
  void _onPointerDown(PointerDownEvent event) {
    final bool isClaimed = _claimedPointer == event.pointer;
    _claimedPointer = null;

    if (_anchor != null) {
      _stop();
      return;
    }
    if (isClaimed || event.kind != PointerDeviceKind.mouse) return;
    if (event.buttons != kMiddleMouseButton) return;

    _start(event.position);
  }

  /// The mouse aims the mode with the button held…
  void _onPointerMove(PointerMoveEvent event) => _track(event.position);

  /// …and after the release as well.
  void _onPointerHover(PointerHoverEvent event) => _track(event.position);

  /// A release ends the mode only when it closes a drag: a plain click leaves
  /// the mode on, as the button does in a browser.
  void _onPointerUp(PointerUpEvent event) {
    if (_anchor == null) return;

    _isHeld = false;
    if (_isDragged) _stop();
  }

  /// The user's wheel ends the mode; its own events are marked and pass by.
  void _onPointerSignal(PointerSignalEvent event) {
    if (_anchor == null || event.embedderId == _syntheticEmbedderId) return;

    _stop();
  }

  /// Escape leaves the mode, as it does in a browser; every other key belongs
  /// to the application.
  bool _onKey(KeyEvent event) {
    if (_anchor == null) return false;
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey != LogicalKeyboardKey.escape) return false;

    _stop();

    return true;
  }

  /// Starts the mode, unless there is nothing to scroll under the anchor:
  /// then the click is left alone, as a browser leaves a page that does not
  /// scroll.
  void _start(Offset anchor) {
    final bool hasScrollable = _hasViewportAt(anchor);
    final ScrollPosition? fallback = hasScrollable ? null : _primaryPosition();
    if (!hasScrollable && fallback == null) return;

    final RenderBox? box = context.findRenderObject() as RenderBox?;

    _isHeld = true;
    _isDragged = false;
    _anchorMark = box?.globalToLocal(anchor) ?? anchor;
    _lastTick = Duration.zero;
    _pointer = anchor;
    _fallback = fallback;
    _latch.isBlocking = true;

    /// The browser answers the middle button on its own — over a link with a
    /// new tab — and the click that ends the mode must do nothing else.
    holdMiddleButtonDefault(isHeld: true);
    HardwareKeyboard.instance.addHandler(_onKey);
    _ticker.start();

    setState(() {
      _anchor = anchor;
      _cursor = SystemMouseCursors.allScroll;
    });
  }

  ///
  void _stop() {
    if (_anchor == null) return;

    _ticker.stop();
    holdMiddleButtonDefault(isHeld: false);
    HardwareKeyboard.instance.removeHandler(_onKey);
    _isHeld = false;
    _isDragged = false;
    _fallback = null;
    _latch
      ..isBlocking = false
      ..isOpen = false;

    setState(() => _anchor = null);
  }

  /// The travel from the anchor drives the speed and the cursor; past the
  /// dead zone a held button reads as a drag.
  void _track(Offset position) {
    final Offset? anchor = _anchor;
    if (anchor == null) return;

    _pointer = position;
    final Offset travel = position - anchor;
    if (_isHeld && travel.distance > _deadZone) _isDragged = true;

    final MouseCursor cursor = _cursorFor(travel);
    if (cursor != _cursor) setState(() => _cursor = cursor);
  }

  /// One frame of scrolling: the travel from the anchor sets the speed, the
  /// length of the frame turns it into pixels.
  void _onTick(Duration elapsed) {
    final Offset? anchor = _anchor;
    if (anchor == null) return;

    final Duration frame = elapsed - _lastTick;
    _lastTick = elapsed;
    if (frame <= Duration.zero) return;
    final Duration step = frame > _maxFrame ? _maxFrame : frame;

    final Offset velocity = _velocityFor(_pointer - anchor);
    if (velocity == Offset.zero) return;

    final double seconds =
        step.inMicroseconds / Duration.microsecondsPerSecond;

    _scrollBy(velocity * seconds, anchor);
  }

  /// Speed along both axes, px/s.
  Offset _velocityFor(Offset travel) =>
      Offset(_axisVelocity(travel.dx), _axisVelocity(travel.dy));

  /// Speed along one axis: zero within the dead zone, so a resting mouse
  /// keeps the page still, and growing with the travel past it, as in the
  /// browser mode.
  double _axisVelocity(double travel) {
    final double distance = travel.abs() - _deadZone;
    if (distance <= 0) return 0;

    return math.min(distance * _speedFactor, _maxSpeed) * travel.sign;
  }

  /// Writes the step into the fallback position, or sends it as the wheel:
  /// one event per axis, since a scrollable reads only the component of its
  /// own axis and a single event reaches a single scrollable.
  void _scrollBy(Offset step, Offset anchor) {
    final ScrollPosition? fallback = _fallback;
    if (fallback != null) {
      _scrollFallback(fallback, step.dy);
      return;
    }

    if (step.dy != 0) _sendWheel(anchor, Offset(0, step.dy));
    if (step.dx != 0) _sendWheel(anchor, Offset(step.dx, 0));
  }

  /// Skips a position that has left the tree: it has no offset or dimensions
  /// to move between.
  void _scrollFallback(ScrollPosition position, double step) {
    if (step == 0) return;
    if (!position.hasPixels || !position.hasContentDimensions) return;

    position.pointerScroll(step);
  }

  /// A wheel event of the framework's own kind, aimed at the anchor, so the
  /// hit test picks the scrollable as it does for the real wheel. The block
  /// opens only for the dispatch: hit testing runs inside it, so no rebuild
  /// comes in between.
  void _sendWheel(Offset position, Offset delta) {
    _latch.isOpen = true;
    GestureBinding.instance.handlePointerEvent(
      PointerScrollEvent(
        viewId: View.of(context).viewId,
        timeStamp: _lastTick,
        position: position,
        scrollDelta: delta,
        embedderId: _syntheticEmbedderId,
      ),
    );
    _latch.isOpen = false;
  }

  /// Whether any scrollable sits under [position] for the wheel to reach.
  /// The mode has not started yet, so the hit test reaches the application
  /// itself.
  bool _hasViewportAt(Offset position) {
    final HitTestResult result = HitTestResult();
    GestureBinding.instance.hitTestInView(
      result,
      position,
      View.of(context).viewId,
    );

    return result.path.any((entry) => entry.target is RenderAbstractViewport);
  }

  /// The route's primary position, the one the keyboard scrolls. It is
  /// provided below the navigator, so it is read from the focused context:
  /// this widget stands above.
  ScrollPosition? _primaryPosition() {
    final BuildContext? focused = FocusManager.instance.primaryFocus?.context;
    if (focused == null) return null;

    final ScrollController? controller = PrimaryScrollController.maybeOf(
      focused,
    );
    if (controller == null || controller.positions.length != 1) return null;

    final ScrollPosition position = controller.position;
    final bool isReady =
        position.hasPixels && position.hasContentDimensions;

    return isReady ? position : null;
  }

  /// The cursor of the direction: one of eight around the anchor, and the
  /// mode's own all-scroll inside the dead zone.
  MouseCursor _cursorFor(Offset travel) {
    final bool isHorizontal = travel.dx.abs() > _deadZone;
    final bool isVertical = travel.dy.abs() > _deadZone;

    if (!isHorizontal && !isVertical) return SystemMouseCursors.allScroll;
    if (!isHorizontal) {
      return travel.dy < 0
          ? SystemMouseCursors.resizeUp
          : SystemMouseCursors.resizeDown;
    }
    if (!isVertical) {
      return travel.dx < 0
          ? SystemMouseCursors.resizeLeft
          : SystemMouseCursors.resizeRight;
    }
    if (travel.dy < 0) {
      return travel.dx < 0
          ? SystemMouseCursors.resizeUpLeft
          : SystemMouseCursors.resizeUpRight;
    }

    return travel.dx < 0
        ? SystemMouseCursors.resizeDownLeft
        : SystemMouseCursors.resizeDownRight;
  }
}

/// The state of the pointer block, read at hit-test time: the mode opens the
/// block for a single dispatch, and a rebuild in the middle of sending an
/// event would come too late.
final class _GateLatch {
  /// Whether the mode is on and the application stands behind the block.
  bool isBlocking = false;

  /// Whether the block is open for the mode's own wheel event.
  bool isOpen = false;
}

/// Keeps the pointer off the application while the mode is on: a click then
/// only ends the mode, as in a browser, and must not press the button under
/// the cursor. For the same reason nothing under the mode shows hover.
final class _PointerGate extends SingleChildRenderObjectWidget {
  ///
  const _PointerGate({required this.latch, required super.child});

  ///
  final _GateLatch latch;

  ///
  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderPointerGate(latch);

  ///
  @override
  void updateRenderObject(
    BuildContext context,
    _RenderPointerGate renderObject,
  ) {
    renderObject.latch = latch;
  }
}

///
final class _RenderPointerGate extends RenderProxyBox {
  ///
  _RenderPointerGate(this.latch);

  ///
  _GateLatch latch;

  /// When blocking, the box takes the hit itself and leaves its child out of
  /// the path, as [AbsorbPointer] does; unlike [IgnorePointer], the
  /// [Listener] above still sees it.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!latch.isBlocking || latch.isOpen) {
      return super.hitTest(result, position: position);
    }

    return size.contains(position);
  }
}

/// The mark the mode is anchored by: the round four-arrow glyph a browser
/// draws in the same place.
final class _AutoScrollAnchor extends StatelessWidget {
  ///
  const _AutoScrollAnchor({required this.size});

  ///
  final double size;

  ///
  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: const _AutoScrollAnchorPainter(),
  );
}

///
final class _AutoScrollAnchorPainter extends CustomPainter {
  ///
  const _AutoScrollAnchorPainter();

  /// Fixed colours, not the theme's: the mark mimics the browser's and is
  /// drawn over light and dark pages alike.
  static const Color _fill = Color(0xF2FFFFFF);

  ///
  static const Color _ink = Color(0xCC202124);

  ///
  static const Color _border = Color(0x33000000);

  ///
  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = size.center(Offset.zero);
    final double radius = size.shortestSide / 2;

    canvas
      ..drawCircle(center, radius, Paint()..color = _border)
      ..drawCircle(center, radius - 1, Paint()..color = _fill)
      ..drawCircle(center, 1.5, Paint()..color = _ink);

    final Path arrow = Path()
      ..moveTo(0, -radius + 3)
      ..lineTo(-3.2, -radius + 7.4)
      ..lineTo(3.2, -radius + 7.4)
      ..close();
    final Paint ink = Paint()..color = _ink;

    for (int quarter = 0; quarter < 4; quarter++) {
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(quarter * math.pi / 2)
        ..drawPath(arrow, ink)
        ..restore();
    }
  }

  ///
  @override
  bool shouldRepaint(_AutoScrollAnchorPainter oldDelegate) => false;
}
