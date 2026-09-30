import 'package:flutter/widgets.dart';

/// A sheet that [SheetOverdrag] moves by its scrollable content.
abstract interface class SheetOverdragTarget {
  /// How far below its place the sheet is now, in pixels.
  double get dragOffset;

  /// Whether a finger may move the sheet now: dragging is enabled, and the
  /// sheet is not leaving the screen.
  bool get isDraggable;

  /// Puts the sheet [offset] pixels below its place.
  void dragTo(double offset);

  /// The finger let go of the sheet, flinging it down at [velocity] px/s (up
  /// is negative): close the sheet or put it back, by the same rules as after
  /// a drag by its header.
  void release(double velocity);
}

/// Drags a scrollable sheet by its content: once the list has reached its
/// top, a swipe down moves the sheet itself (and closes it) instead of
/// overscrolling the list. The same goes without reaching it first: the list
/// scrolls up to its top, and the rest of the same swipe moves the sheet.
///
/// A sheet's own drag never starts on its content: the scroll view wins the
/// gesture. So the offset past the top edge is intercepted in the physics of
/// the list and handed to [target]. A list with no physics of its own gets
/// them from the `ScrollConfiguration` this widget sets up; a list that sets
/// its physics wraps them with [physicsOf].
final class SheetOverdrag extends StatefulWidget {
  ///
  const SheetOverdrag({required this.target, required this.child, super.key});

  ///
  final SheetOverdragTarget target;

  ///
  final Widget child;

  /// The physics for a vertical list that sets its own: inside a sheet the
  /// sheet takes the offset past the top edge, outside one [physics] is
  /// returned as is.
  ///
  /// The physics a list sets come before those of the configuration, and
  /// [BouncingScrollPhysics] never hands a user offset on — a configuration
  /// alone would not see the gesture.
  static ScrollPhysics physicsOf(BuildContext context, ScrollPhysics physics) {
    final scope = context.getInheritedWidgetOfExactType<_SheetOverdragScope>();
    if (scope == null) return physics;

    return _SheetOverdragPhysics(scope.sheet, parent: physics);
  }

  ///
  @override
  State<SheetOverdrag> createState() => _SheetOverdragState();
}

///
final class _SheetOverdragState extends State<SheetOverdrag> {
  /// The scroll behavior inside the sheet: the parent one, with physics that
  /// hand the offset past the top edge to the sheet. One instance per sheet:
  /// a new one would recreate the scroll positions and break the gesture.
  late ScrollBehavior _scrollBehavior;

  /// The parent scroll behavior [_scrollBehavior] is built from.
  ScrollBehavior? _parentBehavior;

  /// The finger is moving the sheet through the list.
  bool _dragging = false;

  /// An outer link of the physics chain has taken the sheet's share of the
  /// current offset. A list wrapped with [SheetOverdrag.physicsOf] has a
  /// second link underneath, from the configuration, and physics that hand
  /// the offset on would let it take the share again.
  bool _absorbing = false;

  ///
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final parent = ScrollConfiguration.of(context);
    if (parent == _parentBehavior) return;

    _parentBehavior = parent;
    _scrollBehavior = parent.copyWith(
      physics: _SheetOverdragPhysics(
        this,
        parent: parent.getScrollPhysics(context),
      ),
    );
  }

  /// Takes the part of the scroll offset [offset] (down is positive) that
  /// moves the sheet; returns the rest for the list itself.
  double _absorb(ScrollMetrics position, double offset) {
    final target = widget.target;

    // The sheet is already leaving — it needs the gesture no more.
    if (!target.isDraggable) {
      _dragging = false;
      return offset;
    }

    if (!_dragging) {
      // How far the list may still scroll down before it reaches its top.
      final room = position.extentBefore;
      if (offset <= room) return offset;
      _dragging = true;
      target.dragTo(target.dragOffset + offset - room);
      return room;
    }

    // Down: the sheet goes on. Up: first the sheet goes back to its place.
    final dragOffset = target.dragOffset;
    if (offset >= 0 || -offset < dragOffset) {
      target.dragTo(dragOffset + offset);
      return 0;
    }

    // The sheet is in place: the rest of the upward swipe scrolls the list.
    target.dragTo(0);
    _dragging = false;
    return offset + dragOffset;
  }

  /// The end of the scroll gesture: [SheetOverdragTarget.release] closes the
  /// sheet or puts it back.
  bool _onScrollEnd(ScrollEndNotification notification) {
    if (!_dragging ||
        notification.metrics.axisDirection != AxisDirection.down) {
      return false;
    }
    _dragging = false;

    widget.target.release(
      notification.dragDetails?.velocity.pixelsPerSecond.dy ?? 0,
    );
    return false;
  }

  ///
  @override
  Widget build(BuildContext context) {
    return _SheetOverdragScope(
      sheet: this,
      child: NotificationListener<ScrollEndNotification>(
        onNotification: _onScrollEnd,
        child: ScrollConfiguration(
          behavior: _scrollBehavior,
          child: widget.child,
        ),
      ),
    );
  }
}

/// The sheet the lists are built in, for [SheetOverdrag.physicsOf].
final class _SheetOverdragScope extends InheritedWidget {
  ///
  const _SheetOverdragScope({required this.sheet, required super.child});

  ///
  final _SheetOverdragState sheet;

  /// A subtree has one sheet for its whole life — nothing to rebuild for.
  @override
  bool updateShouldNotify(_SheetOverdragScope oldWidget) => false;
}

/// The physics of a list in a sheet: the offset of a vertical scroll past
/// the top edge moves the sheet, the rest goes to the parent physics.
final class _SheetOverdragPhysics extends ScrollPhysics {
  ///
  const _SheetOverdragPhysics(this._sheet, {super.parent});

  ///
  final _SheetOverdragState _sheet;

  ///
  @override
  _SheetOverdragPhysics applyTo(ScrollPhysics? ancestor) =>
      _SheetOverdragPhysics(_sheet, parent: buildParent(ancestor));

  ///
  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // Horizontal strips and reversed lists never move the sheet; an inner
    // link gets what an outer one has left.
    if (position.axisDirection != AxisDirection.down || _sheet._absorbing) {
      return super.applyPhysicsToUserOffset(position, offset);
    }

    final rest = _sheet._absorb(position, offset);
    // Bouncing physics reject a zero offset.
    if (rest == 0) return 0;

    _sheet._absorbing = true;
    try {
      return super.applyPhysicsToUserOffset(position, rest);
    } finally {
      _sheet._absorbing = false;
    }
  }

  ///
  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if (position.axisDirection != AxisDirection.down || !_sheet._dragging) {
      return super.createBallisticSimulation(position, velocity);
    }
    // The sheet takes the momentum; the list only goes back in bounds if the
    // gesture started while it was still bouncing after a fling.
    return position.outOfRange
        ? super.createBallisticSimulation(position, 0)
        : null;
  }
}
