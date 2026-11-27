import 'package:auto_route/auto_route.dart';
import 'package:flutter/widgets.dart';

/// Reports when an `auto_route` page leaves the active route hierarchy while
/// it is still mounted, for example after switching tabs or pushing a page.
/// Dialogs and sheets that leave the route hierarchy in place do not count.
final class RouteLeaveListener extends StatefulWidget {
  ///
  const RouteLeaveListener({
    required this.onLeave,
    required this.child,
    super.key,
  });

  /// Called after the frame in which the route left the active hierarchy.
  final VoidCallback onLeave;

  ///
  final Widget child;

  ///
  @override
  State<RouteLeaveListener> createState() => _RouteLeaveListenerState();
}

///
final class _RouteLeaveListenerState extends State<RouteLeaveListener> {
  ///
  RouteData<dynamic>? _routeData;

  /// The router's navigation history, used through its listener interface.
  Listenable? _history;

  /// Track the transition out of the active hierarchy.
  bool _wasActive = false;

  ///
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final RouteData<dynamic> routeData = RouteData.of(context);
    if (identical(routeData, _routeData)) return;

    _routeData = routeData;
    _wasActive = routeData.isActive;

    _history?.removeListener(_onUrlChanged);
    _history = routeData.router.navigationHistory..addListener(_onUrlChanged);
  }

  ///
  @override
  void dispose() {
    _history?.removeListener(_onUrlChanged);
    super.dispose();
  }

  ///
  void _onUrlChanged() {
    final bool isActive = _routeData?.isActive ?? false;
    if (isActive == _wasActive) return;

    _wasActive = isActive;
    if (isActive) return;

    /// Declarative navigation can change the address during build. Defer
    /// callbacks that may rebuild the page until the end of the frame.
    WidgetsBinding.instance
      ..addPostFrameCallback((_) {
        if (mounted) widget.onLeave();
      })
      ..ensureVisualUpdate();
  }

  ///
  @override
  Widget build(BuildContext context) => widget.child;
}
