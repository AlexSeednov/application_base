import 'package:flutter/widgets.dart';

/// A footer sliver that fills the remaining viewport and aligns its child
/// to the bottom. With longer content it follows the preceding slivers.
final class SliverFooter extends StatelessWidget {
  ///
  const SliverFooter({required this.footer, super.key});

  ///
  final Widget footer;

  ///
  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(
      hasScrollBody: false,
      // Cover the overscrolled area when the list uses bouncing physics.
      fillOverscroll: true,
      child: Align(alignment: Alignment.bottomCenter, child: footer),
    );
  }
}
