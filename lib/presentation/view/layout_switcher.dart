import 'package:flutter/widgets.dart';

/// Chooses an adaptive screen body. Place it below the owner of the screen's
/// state so resizing replaces the layout without restarting the screen.
final class LayoutSwitcher extends StatelessWidget {
  ///
  const LayoutSwitcher({
    required this.isWide,
    required this.compact,
    required this.wide,
    super.key,
  });

  /// Evaluates the application's layout rule for this screen.
  final bool Function(BuildContext context) isWide;

  /// Body used on compact layouts.
  final WidgetBuilder compact;

  /// Body used when [isWide] is true.
  final WidgetBuilder wide;

  ///
  @override
  Widget build(BuildContext context) =>
      isWide(context) ? wide(context) : compact(context);
}
