import 'package:flutter/material.dart';

/// Tap target without any visual feedback.
///
/// The overlay colour is forced to transparent so wrapping a laid-out
/// subtree in it does not change how that subtree looks.
///
/// The one thing it does draw is a focus ring. With a transparent overlay the
/// ink well's own focus highlight is invisible, so a keyboard user tabbing
/// through the page could not see where they were. The ring shows only for
/// keyboard-driven focus ([FocusHighlightMode.traditional]): a pointer tap
/// never focuses the button, so touch and mouse users never see it.
final class EmptyButton extends StatefulWidget {
  ///
  const EmptyButton({
    required this.onClick,
    required this.child,
    this.focusBorderRadius,
    super.key,
  });

  ///
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
  /// Whether the ink well (or a descendant) holds the focus.
  bool _isFocused = false;

  /// Whether the focus is driven by the keyboard: only then the ring shows.
  bool _isKeyboardFocus =
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  ///
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightModeChange);
  }

  ///
  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightModeChange);
    super.dispose();
  }

  ///
  void _onHighlightModeChange(FocusHighlightMode mode) {
    final bool isKeyboardFocus = mode == FocusHighlightMode.traditional;
    if (isKeyboardFocus == _isKeyboardFocus) return;

    setState(() => _isKeyboardFocus = isKeyboardFocus);
  }

  ///
  void _onFocusChange(bool isFocused) {
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
      onFocusChange: _onFocusChange,
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
