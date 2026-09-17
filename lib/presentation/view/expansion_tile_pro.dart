import 'package:application_base/presentation/view/empty_button.dart';
import 'package:flutter/material.dart';

/// An expandable row of a list: a title with a chevron, and a body below it.
///
/// The caller owns the expanded state ([isExpanded] and [onToggle]): one list
/// wants a single expanded row at a time, another wants any number of them,
/// and that decision stays outside the row.
///
/// The hover highlight covers the whole row and bleeds past it by
/// [highlightBleed] horizontally: the title does not touch the edge of the
/// fill and still sits on the same vertical line as the rest of the block.
/// Two things the caller owns: no ancestor may clip those edges (a list needs
/// `clipBehavior: Clip.none`), and where there is no room outside — a modal, a
/// column flush against the edge — the row is given a padding of the same
/// width for the highlight to take.
final class ExpansionTilePro extends StatefulWidget {
  ///
  const ExpansionTilePro({
    required this.title,
    required this.titleStyle,
    required this.icon,
    required this.isExpanded,
    required this.onToggle,
    required this.child,
    required this.highlightColor,
    required this.borderRadius,
    required this.duration,
    this.highlightBleed = defaultHighlightBleed,
    super.key,
  });

  ///
  final String title;

  ///
  final TextStyle titleStyle;

  /// The collapsed-state indicator: the row turns it half a turn on its own
  /// when expanded
  final Widget icon;

  ///
  final bool isExpanded;

  ///
  final VoidCallback onToggle;

  /// Shown under the title while expanded
  final Widget child;

  /// The fill of the row under the cursor
  final Color highlightColor;

  ///
  final BorderRadius borderRadius;

  /// How long expanding and turning the chevron take
  final Duration duration;

  ///
  final double highlightBleed;

  /// How far the highlight bleeds past the row when the caller does not say
  static const double defaultHighlightBleed = 12;

  /// The vertical padding of the row: the highlight covers it with the title
  static const double headerOffset = 16;

  /// The vertical padding of the tile — the rest of the gap to its
  /// neighbours, left outside the highlight
  static const double itemOffset = 8;

  ///
  @override
  State<ExpansionTilePro> createState() => _ExpansionTileProState();
}

///
final class _ExpansionTileProState extends State<ExpansionTilePro> {
  // MARK: Const

  /// The gap between the title and the chevron
  static const double _headerGap = 16;

  /// The highlight appears and fades noticeably faster than the row expands —
  /// otherwise the fill trails the cursor and lingers once it has left
  static const Duration _highlightDuration = Duration(milliseconds: 100);

  // MARK: Notifiers

  /// Whether the cursor is over the row; never true on a touch device
  final ValueNotifier<bool> _isHoveredNotifier = ValueNotifier<bool>(false);

  // MARK: Base functions

  ///
  @override
  void dispose() {
    _isHoveredNotifier.dispose();

    super.dispose();
  }

  ///
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: ExpansionTilePro.itemOffset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ///
          _header(context),

          ///
          _body(context),
        ],
      ),
    );
  }

  // MARK: Functions

  /// The title row is both the tap target and the highlighted area, and both
  /// take all of it — so neither the cursor nor the fill disagrees with what
  /// a click actually hits
  Widget _header(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _isHoveredNotifier.value = true,
      onExit: (_) => _isHoveredNotifier.value = false,
      child: EmptyButton(
        onClick: widget.onToggle,
        focusBorderRadius: widget.borderRadius,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            ///
            _highlight(),

            /// Sizes the row — the highlight stretches to it
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: ExpansionTilePro.headerOffset,
              ),
              child: Row(
                children: [
                  ///
                  Expanded(
                    child: Text(
                      widget.title,
                      textAlign: TextAlign.start,
                      style: widget.titleStyle,
                    ),
                  ),

                  ///
                  const SizedBox(width: _headerGap),

                  ///
                  AnimatedRotation(
                    duration: widget.duration,
                    turns: widget.isExpanded ? 0.5 : 0,
                    child: widget.icon,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// A layer of its own under the content of the row: that way the fill
  /// reaches past the row without moving either the title or the chevron
  Widget _highlight() {
    return Positioned(
      left: -widget.highlightBleed,
      right: -widget.highlightBleed,
      top: 0,
      bottom: 0,
      child: ValueListenableBuilder<bool>(
        valueListenable: _isHoveredNotifier,
        builder: (context, isHovered, _) {
          return AnimatedContainer(
            duration: _highlightDuration,
            decoration: BoxDecoration(
              color: isHovered ? widget.highlightColor : Colors.transparent,
              borderRadius: widget.borderRadius,
            ),
          );
        },
      ),
    );
  }

  ///
  Widget _body(BuildContext context) {
    return AnimatedCrossFade(
      firstChild: const SizedBox.shrink(),
      secondChild: Padding(
        padding: const EdgeInsets.only(bottom: ExpansionTilePro.headerOffset),
        child: widget.child,
      ),
      crossFadeState: widget.isExpanded
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      duration: widget.duration,
      sizeCurve: Curves.fastOutSlowIn,
      alignment: Alignment.topLeft,
    );
  }
}
