import 'package:application_base/presentation/view/opacity_pro.dart';
import 'package:flutter/material.dart';

/// Fades [child] to [disabledOpacity] and blocks its pointer input while not
/// [isEnabled].
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

  /// Opacity while not [isEnabled].
  final double disabledOpacity;

  ///
  final Widget child;

  ///
  @override
  Widget build(BuildContext context) {
    return OpacityPro(
      isFullyOpaque: isEnabled,
      minOpacity: disabledOpacity,
      /// Always wrapped, toggled by `ignoring`: swapping the wrapper in and out
      /// changes the child's place in the tree and resets its state — a field's
      /// text, a scroll offset, a running animation.
      child: IgnorePointer(ignoring: !isEnabled, child: child),
    );
  }
}
