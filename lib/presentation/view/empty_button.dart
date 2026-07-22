import 'package:flutter/material.dart';

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
