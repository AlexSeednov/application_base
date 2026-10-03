import 'package:flutter/material.dart';

/// Tap target without any visual feedback.
///
/// The overlay colour is forced to transparent, so wrapping a laid-out
/// subtree does not change how it looks.
///
/// It draws only a focus ring: with a transparent overlay the ink well's own
/// focus highlight is invisible, and a keyboard user could not see where the
/// focus is. The ring shows only for keyboard focus
/// ([FocusHighlightMode.traditional]); a pointer tap never focuses the
/// button, so touch and mouse users never see it.
///
/// The ring marks the button itself, not its subtree: a text field inside
/// the child shows its own cursor, and a ring around it while typing would
/// read as a stray border.
final class EmptyButton extends StatefulWidget {
  ///
  const EmptyButton({
    required this.onClick,
    required this.child,
    this.focusBorderRadius,
    super.key,
  });

  /// `null` — no tap target: the child is shown as is.
  final VoidCallback? onClick;

  ///
  final Widget child;

  /// Rounding of the focus ring; `null` — [defaultFocusBorderRadius].
  final BorderRadius? focusBorderRadius;

  /// Stroke width of the focus ring.
  static const double focusRingWidth = 2;

  /// Rounding of the focus ring when the button does not specify its own.
  static const BorderRadius defaultFocusBorderRadius = BorderRadius.all(
    Radius.circular(8),
  );

  ///
  @override
  State<EmptyButton> createState() => _EmptyButtonState();
}

///
final class _EmptyButtonState extends State<EmptyButton> {
  /// The ink well's own node — read for its primary focus, which
  /// `InkWell.onFocusChange` does not report: that one fires for the
  /// subtree too.
  final FocusNode _focusNode = FocusNode(debugLabel: 'EmptyButton');

  /// Whether the ink well itself holds the primary focus.
  bool _isFocused = false;

  /// Whether the focus is driven by the keyboard: only then does the ring
  /// show.
  bool _isKeyboardFocus =
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  ///
  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    FocusManager.instance.addHighlightModeListener(_onHighlightModeChange);
  }

  ///
  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightModeChange);
    _focusNode
      ..removeListener(_onFocusChange)
      ..dispose();
    super.dispose();
  }

  ///
  void _onHighlightModeChange(FocusHighlightMode mode) {
    final bool isKeyboardFocus = mode == FocusHighlightMode.traditional;
    if (isKeyboardFocus == _isKeyboardFocus) return;

    setState(() => _isKeyboardFocus = isKeyboardFocus);
  }

  /// Fires on every focus change of the node, including the primary focus
  /// moving between the button and its subtree.
  void _onFocusChange() {
    final bool isFocused = _focusNode.hasPrimaryFocus;
    if (isFocused == _isFocused) return;

    setState(() => _isFocused = isFocused);
  }

  ///
  bool get _showsRing => _isFocused && _isKeyboardFocus;

  ///
  @override
  Widget build(BuildContext context) {
    if (widget.onClick == null) return widget.child;

    return InkWell(
      overlayColor: WidgetStateProperty.resolveWith<Color>(
        (states) => Colors.transparent,
      ),
      onTap: widget.onClick,
      focusNode: _focusNode,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius:
              widget.focusBorderRadius ?? EmptyButton.defaultFocusBorderRadius,
          border: _showsRing
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: EmptyButton.focusRingWidth,
                )
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}
