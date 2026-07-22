import 'package:flutter/material.dart';

/// Tap target without any visual feedback.
///
/// The overlay colour is forced to transparent so wrapping a laid-out
/// subtree in it does not change how that subtree looks.
final class EmptyButton extends StatelessWidget {
  ///
  const EmptyButton({required this.onClick, required this.child, super.key});

  ///
  final VoidCallback? onClick;

  ///
  final Widget child;

  ///
  @override
  Widget build(BuildContext context) {
    if (onClick == null) return child;

    return InkWell(
      overlayColor: WidgetStateProperty.resolveWith<Color>(
        (states) => Colors.transparent,
      ),
      onTap: onClick,
      child: child,
    );
  }
}
