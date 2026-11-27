import 'package:application_base/presentation/view/sliver_footer.dart';
import 'package:flutter/widgets.dart';

/// A scroll view with a padded content sliver and full-width header and
/// footer slots. On short pages [SliverFooter] keeps the footer at the bottom.
final class SlottedScrollView extends StatelessWidget {
  ///
  const SlottedScrollView({
    required this.sliver,
    this.padding = EdgeInsets.zero,
    this.header,
    this.footer,
    this.primary = true,
    this.physics = const AlwaysScrollableScrollPhysics(),
    this.shrinkWrap = false,
    super.key,
  });

  /// Main content sliver.
  final Widget sliver;

  /// Insets applied to [sliver].
  final EdgeInsetsGeometry padding;

  /// Optional box placed before the content in the same scroll view.
  final Widget? header;

  /// Optional full-width footer placed after the content.
  final Widget? footer;

  /// Whether to use the route's [PrimaryScrollController] for keyboard and
  /// other scroll actions. Set to false for a nested vertical list.
  final bool primary;

  /// Defaults to accepting drag gestures even when all content fits, so an
  /// enclosing pull-to-refresh can work on short pages.
  final ScrollPhysics physics;

  ///
  final bool shrinkWrap;

  ///
  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      primary: primary,
      physics: physics,
      shrinkWrap: shrinkWrap,
      slivers: [
        ///
        if (header != null) SliverToBoxAdapter(child: header),

        ///
        SliverPadding(padding: padding, sliver: sliver),

        ///
        if (footer != null) SliverFooter(footer: footer!),
      ],
    );
  }
}
