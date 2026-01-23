import 'package:application_base/presentation/view/opacity_pro.dart';
import 'package:flutter/material.dart';

///
final class EnabledPro extends StatelessWidget {
  ///
  const EnabledPro({
    required this.isEnabled,
    required this.child,
    this.disabledOpacity = OpacityPro.minOpacityDefault,
    super.key,
  });

  ///
  final bool isEnabled;

  /// Opacity value in disabled state ([isEnabled] is false)
  final double disabledOpacity;

  ///
  final Widget child;

  ///
  @override
  Widget build(BuildContext context) {
    return OpacityPro(
      isFullyOpaque: isEnabled,
      minOpacity: disabledOpacity,
      child: isEnabled ? child : IgnorePointer(child: child),
    );
  }
}
