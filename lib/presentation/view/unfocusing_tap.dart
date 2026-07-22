import 'package:application_base/presentation/navigation/navigation_service.dart';
import 'package:flutter/material.dart';

/// Drops keyboard focus when the user taps outside the focused field.
final class UnfocusingTap extends StatelessWidget {
  ///
  const UnfocusingTap({required this.child, super.key});

  /// Main screen child
  final Widget child;

  ///
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onTap: unfocus,
    child: child,
  );
}
