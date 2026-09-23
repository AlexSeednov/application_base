import 'package:flutter/material.dart';

/// Animates [child] between full opacity and [minOpacity].
final class OpacityPro extends StatelessWidget {
  ///
  const OpacityPro({
    required this.isFullyOpaque,
    required this.child,
    this.minOpacity = minOpacityDefault,
    this.animationDuration = animationDurationDefault,
    super.key,
  });

  /// Material's opacity for disabled content.
  static const double minOpacityDefault = 0.38;

  ///
  static const Duration animationDurationDefault = Duration(milliseconds: 500);

  ///
  final bool isFullyOpaque;

  /// Opacity while not [isFullyOpaque].
  final double minOpacity;

  ///
  final Duration animationDuration;

  ///
  final Widget child;

  ///
  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      duration: animationDuration,
      opacity: isFullyOpaque ? 1.0 : minOpacity,
      child: child,
    );
  }
}
