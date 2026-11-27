import 'dart:math' as math;

import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:flutter/material.dart';

/// Reveals the indicator from the scroll edge as the drag progresses.
final class PullToRefreshIndicatorContainer extends StatelessWidget {
  ///
  const PullToRefreshIndicatorContainer({
    required this.child,
    required this.controller,
    required this.displacement,
    required this.edgeOffset,
    super.key,
  });

  ///
  final IndicatorController controller;

  ///
  final double displacement;

  ///
  final Widget child;

  ///
  final double edgeOffset;

  ///
  Alignment _getAlignment(IndicatorSide side) {
    switch (side) {
      case IndicatorSide.left:
        return Alignment.centerLeft;
      case IndicatorSide.top:
        return Alignment.topCenter;
      case IndicatorSide.right:
        return Alignment.centerRight;
      case IndicatorSide.bottom:
        return Alignment.bottomCenter;
      case IndicatorSide.none:
        throw UnsupportedError('An inactive indicator has no alignment.');
    }
  }

  ///
  EdgeInsets _getEdgeInsets(IndicatorSide side) {
    switch (side) {
      case IndicatorSide.left:
        return EdgeInsets.only(left: displacement);
      case IndicatorSide.top:
        return EdgeInsets.only(top: displacement);
      case IndicatorSide.right:
        return EdgeInsets.only(right: displacement);
      case IndicatorSide.bottom:
        return EdgeInsets.only(bottom: displacement);
      case IndicatorSide.none:
        throw UnsupportedError('Cannot get edge insets for "none" side.');
    }
  }

  ///
  @override
  Widget build(BuildContext context) {
    if (controller.side.isNone) return const SizedBox();

    final isVerticalAxis = controller.side.isTop || controller.side.isBottom;
    final isHorizontalAxis = controller.side.isLeft || controller.side.isRight;

    final AlignmentDirectional alignment = isVerticalAxis
        ? AlignmentDirectional(-1, controller.side.isTop ? 1.0 : -1.0)
        : AlignmentDirectional(controller.side.isLeft ? 1.0 : -1.0, -1);

    final double value = controller.isFinalizing ? 1.0 : controller.value;

    return Positioned(
      top: isHorizontalAxis
          ? 0
          : controller.side.isTop
          ? edgeOffset
          : null,
      bottom: isHorizontalAxis
          ? 0
          : controller.side.isBottom
          ? edgeOffset
          : null,
      left: isVerticalAxis
          ? 0
          : controller.side.isLeft
          ? edgeOffset
          : null,
      right: isVerticalAxis
          ? 0
          : controller.side.isRight
          ? edgeOffset
          : null,
      child: ClipRRect(
        child: Align(
          alignment: alignment,
          heightFactor: isVerticalAxis ? math.max(value, 0) : null,
          widthFactor: isHorizontalAxis ? math.max(value, 0) : null,
          child: Container(
            padding: _getEdgeInsets(controller.side),
            alignment: _getAlignment(controller.side),
            child: child,
          ),
        ),
      ),
    );
  }
}
