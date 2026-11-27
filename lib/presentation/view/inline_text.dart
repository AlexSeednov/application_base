import 'package:application_base/core/service/platform_service.dart';
import 'package:application_base/presentation/view/route_link.dart';
import 'package:flutter/material.dart';

/// A paragraph part with optional link or button behavior.
final class InlineTextPart {
  /// Ordinary text, optionally with a style of its own.
  const InlineTextPart.text(this.text, {this.style})
    : url = null,
      onClick = null,
      _isAddress = false;

  /// A link caption that can wrap at spaces.
  const InlineTextPart.link(
    this.text, {
    required String this.url,
    required TextStyle this.style,
    required VoidCallback this.onClick,
  }) : _isAddress = false;

  /// A visible URL or email address that can also wrap at URL separators.
  const InlineTextPart.address(
    this.text, {
    required String this.url,
    required TextStyle this.style,
    required VoidCallback this.onClick,
  }) : _isAddress = true;

  /// A button in a sentence, with the specified text style.
  const InlineTextPart.action(
    this.text, {
    required TextStyle this.style,
    required VoidCallback this.onClick,
  }) : url = null,
       _isAddress = false;

  /// The visible text and, for controls, the accessible name.
  final String text;

  ///
  final TextStyle? style;

  ///
  final String? url;

  ///
  final VoidCallback? onClick;

  ///
  final bool _isAddress;
}

/// Builds an inline paragraph for [Text.rich], [RichText] or a text wrapper.
///
/// Each link or button has one Tab stop and one accessibility label. Its
/// fragments share a focus highlight and keep their individual pointer targets
/// so the paragraph can wrap them and the browser can handle link gestures.
final class InlineText extends StatefulWidget {
  ///
  const InlineText({required this.parts, required this.builder, super.key});

  ///
  final List<InlineTextPart> parts;

  /// Builds the surrounding paragraph with the generated text span.
  final Widget Function(TextSpan span) builder;

  ///
  @override
  State<InlineText> createState() => _InlineTextState();
}

///
final class _InlineTextState extends State<InlineText> {
  /// Spaces remain text so the parent paragraph can wrap at them.
  static final RegExp _wordOrSpace = RegExp(r'\S+|\s+');

  /// URL separators belong to the fragment on their left. Keep the expression
  /// free of lookbehind for Safari versions that do not support it.
  static final RegExp _addressFragment = RegExp('[^/.?&=#_@-]*[/.?&=#_@-]*');

  /// Keep a right-to-left address in one fragment so its parts stay in order.
  static final RegExp _rightToLeft = RegExp(
    r'[\u0590-\u08FF\uFB1D-\uFDFF\uFE70-\uFEFF]',
  );

  ///
  int? _focusedPart;

  ///
  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_onHighlightModeChanged);
  }

  ///
  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_onHighlightModeChanged);
    super.dispose();
  }

  ///
  void _onHighlightModeChanged(FocusHighlightMode mode) {
    if (_focusedPart != null) setState(() {});
  }

  /// A previous part losing focus must not clear the next focused part.
  void _onFocusChanged(int index, bool focused) {
    if (_focusedPart == index ? !focused : focused) {
      setState(() => _focusedPart = focused ? index : null);
    }
  }

  ///
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final keyboardFocus =
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    return widget.builder(
      TextSpan(
        children: [
          for (final (index, part) in widget.parts.indexed)
            if (part.onClick == null || part.text.trim().isEmpty)
              TextSpan(text: part.text, style: part.style)
            else
              _interactiveSpan(
                part,
                index: index,
                focusColors: keyboardFocus && _focusedPart == index
                    ? colorScheme
                    : null,
              ),
        ],
      ),
    );
  }

  ///
  InlineSpan _interactiveSpan(
    InlineTextPart part, {
    required int index,
    required ColorScheme? focusColors,
  }) {
    final TextStyle base = part.style!;
    final TextStyle linkStyle = part.url == null
        ? base
        : base.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: base.decorationColor ?? base.color,
          );
    final TextStyle style = focusColors == null
        ? linkStyle
        : linkStyle.copyWith(
            color: focusColors.onInverseSurface,
            decorationColor: focusColors.onInverseSurface,
            backgroundColor: focusColors.inverseSurface,
          );

    final Iterable<String> fragments = switch (part) {
      InlineTextPart(_isAddress: true, :final text)
          when _rightToLeft.hasMatch(text) =>
        [text],
      InlineTextPart(_isAddress: true, :final text) =>
        _addressFragment
            .allMatches(text)
            .map((match) => match[0]!)
            .where((fragment) => fragment.isNotEmpty),
      _ => _wordOrSpace.allMatches(part.text).map((match) => match[0]!),
    };

    bool first = true;
    final List<InlineSpan> spans = [];
    for (final String fragment in fragments) {
      if (fragment.trim().isEmpty) {
        spans.add(TextSpan(text: fragment, style: style));
        continue;
      }

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: _target(part, fragment, style, index: index, first: first),
        ),
      );
      first = false;
    }
    return TextSpan(style: style, children: spans);
  }

  /// Each fragment keeps the native browser link overlay. Only the first
  /// fragment exposes the control to keyboard traversal and assistive tech.
  Widget _target(
    InlineTextPart part,
    String fragment,
    TextStyle style, {
    required int index,
    required bool first,
  }) {
    final target = Material(
      type: MaterialType.transparency,
      child: RouteLink(
        path: part.url,
        onClick: part.onClick,
        showFocusRing: false,
        child: Text(
          fragment,
          style: style,
          semanticsLabel: first ? part.text : null,
          // The paragraph already scales its WidgetSpan placeholders.
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
    if (!first) return ExcludeSemantics(child: ExcludeFocus(child: target));

    return Focus(
      canRequestFocus: false,
      includeSemantics: false,
      onFocusChange: (focused) => _onFocusChanged(index, focused),
      child: Semantics(
        container: true,
        button: part.url == null ? true : null,
        // On the web RouteLink also binds the link to the browser overlay.
        link: part.url != null && !isWeb ? true : null,
        child: target,
      ),
    );
  }
}
