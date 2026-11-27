import 'package:application_base/presentation/view/pull_to_refresh_indicator_container.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Gesture and positioning for a custom pull-to-refresh indicator.
/// The caller supplies the indicator's content and optional arming feedback.
final class PullToRefresh extends StatelessWidget {
  ///
  const PullToRefresh({
    required this.onRefresh,
    required this.pullDistance,
    required this.indicatorBuilder,
    required this.child,
    this.controller,
    this.notificationPredicate,
    this.onArmed,
    this.enabled = true,
    this.forceScrolling = false,
    this.reverse = false,
    this.physics = const AlwaysScrollableScrollPhysics(),
    this.translateContent = false,
    this.edgeOffset = 0,
    this.edgeOffsetShift,
    this.displacement = 40,
    this.indicatorPadding = 4,
    this.backgroundColor,
    super.key,
  });

  /// Work to await while the refresh indicator is visible.
  final AsyncCallback onRefresh;

  /// The drag distance at which releasing triggers [onRefresh].
  final double pullDistance;

  /// Builds the visual indicator, optionally using the gesture's progress.
  final Widget Function(BuildContext context, IndicatorController controller)
  indicatorBuilder;

  /// An optional external controller, owned by the caller.
  final IndicatorController? controller;

  /// Selects which scroll notifications count, for example in a nested list.
  final ScrollNotificationPredicate? notificationPredicate;

  /// Feedback when a drag reaches the arming threshold.
  final VoidCallback? onArmed;

  /// Whether to enable the gesture.
  final bool enabled;

  /// Wrap a short, non-scrollable child in a primary vertical scroll view.
  final bool forceScrolling;

  /// Reverse the scroll view created by [forceScrolling].
  final bool reverse;

  /// Physics for the scroll view created by [forceScrolling].
  final ScrollPhysics physics;

  /// Shift the scrollable away from the edge as the indicator is revealed.
  final bool translateContent;

  /// The distance from the scroll edge where clipping begins.
  final double edgeOffset;

  /// A live adjustment to [edgeOffset], such as a moving header.
  final ValueListenable<double>? edgeOffsetShift;

  /// Distance between the clipping edge and the indicator at rest.
  final double displacement;

  /// Padding around the indicator's circular material.
  final double indicatorPadding;

  /// Color of the indicator's circular material. Defaults to the theme.
  final Color? backgroundColor;

  /// The content of the scroll view, or an existing scrollable.
  final Widget child;

  ///
  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;

    return CustomRefreshIndicator(
      onRefresh: onRefresh,
      controller: controller,
      onStateChanged: (change) {
        if (change.didChange(to: IndicatorState.armed)) onArmed?.call();
      },
      notificationPredicate:
          notificationPredicate ?? defaultScrollNotificationPredicate,
      offsetToArmed: pullDistance,
      builder: _buildIndicator,
      child: forceScrolling
          ? CustomScrollView(
              primary: true,
              reverse: reverse,
              shrinkWrap: true,
              physics: physics,
              slivers: [
                SliverFillRemaining(
                  fillOverscroll: true,
                  hasScrollBody: false,
                  child: child,
                ),
              ],
            )
          : child,
    );
  }

  ///
  Widget _buildIndicator(
    BuildContext context,
    Widget scrollable,
    IndicatorController controller,
  ) {
    final Widget indicator = Transform.scale(
      scale: controller.isFinalizing ? controller.value.clamp(0.0, 1.0) : 1.0,
      child: Padding(
        padding: EdgeInsets.all(indicatorPadding),
        child: Material(
          type: MaterialType.circle,
          color:
              backgroundColor ??
              ProgressIndicatorTheme.of(context).refreshBackgroundColor ??
              Theme.of(context).canvasColor,
          child: indicatorBuilder(context, controller),
        ),
      ),
    );

    return Stack(
      children: [
        if (translateContent)
          Transform.translate(
            offset: _translation(controller),
            child: scrollable,
          )
        else
          scrollable,
        if (edgeOffsetShift case final shift?)
          ValueListenableBuilder<double>(
            valueListenable: shift,
            builder: (_, value, _) =>
                _positionIndicator(controller, indicator, value),
          )
        else
          _positionIndicator(controller, indicator, 0),
      ],
    );
  }

  ///
  Offset _translation(IndicatorController controller) {
    final double distance = controller.value * pullDistance;
    return switch (controller.side) {
      IndicatorSide.top => Offset(0, distance),
      IndicatorSide.bottom => Offset(0, -distance),
      IndicatorSide.left => Offset(distance, 0),
      IndicatorSide.right => Offset(-distance, 0),
      IndicatorSide.none => Offset.zero,
    };
  }

  ///
  Widget _positionIndicator(
    IndicatorController controller,
    Widget indicator,
    double shift,
  ) => PullToRefreshIndicatorContainer(
    edgeOffset: edgeOffset + shift,
    displacement: displacement,
    controller: controller,
    child: indicator,
  );
}
