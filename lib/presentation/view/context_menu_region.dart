import 'package:application_base/presentation/service/browser_context_menu_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// A region where the right mouse button belongs to the application, not to
/// the browser.
///
/// While the cursor is inside, the browser menu is suppressed and a right
/// click opens the application's menu. Outside the region everything stays as
/// usual: text fields, text selection and links keep their menu. Opening the
/// target in a new tab still works with the middle button and a modifier
/// click — they do not go through the context menu.
///
/// Outside the web the region only adds the right-button call of the menu:
/// there is nothing to suppress there.
final class ContextMenuRegion extends StatefulWidget {
  ///
  const ContextMenuRegion({
    required this.onMenu,
    required this.child,
    super.key,
  });

  /// `null` — the element has no menu, and the right button stays with the
  /// browser.
  final VoidCallback? onMenu;

  ///
  final Widget child;

  ///
  @override
  State<ContextMenuRegion> createState() => _ContextMenuRegionState();
}

///
final class _ContextMenuRegionState extends State<ContextMenuRegion> {
  // MARK: Data

  /// The region holds the suppression. It has to be released exactly once,
  /// and the release may come from three sides — the cursor leaving, the menu
  /// going away and the region itself being removed.
  bool _isSuppressing = false;

  // MARK: Base functions

  ///
  @override
  void didUpdateWidget(ContextMenuRegion oldWidget) {
    super.didUpdateWidget(oldWidget);

    /// The menu went away from the element right under the cursor — no exit
    /// will follow
    if (widget.onMenu == null) _release();
  }

  /// The region vanished from under the cursor — the feed scrolled, the list
  /// rebuilt. `MouseRegion.onExit` does not come in this case by the design
  /// of the framework, and an unclosed counter would switch the browser menu
  /// off until the page is reloaded.
  @override
  void dispose() {
    _release();
    super.dispose();
  }

  ///
  @override
  Widget build(BuildContext context) {
    if (widget.onMenu == null) return widget.child;

    return MouseRegion(
      onEnter: (_) => _suppress(),
      onExit: (_) => _release(),
      child: Listener(
        onPointerDown: _onPointerDown,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onSecondaryTapDown: (_) => widget.onMenu?.call(),
          child: widget.child,
        ),
      ),
    );
  }

  // MARK: Functions

  /// A safety net for when there was no hover: the cursor already stood over
  /// the region and the mouse did not move — the window has just got the
  /// focus, or the page was drawn right under the cursor. In the DOM
  /// `pointerdown` comes before `contextmenu`, so the suppression is in place
  /// in time.
  void _onPointerDown(PointerDownEvent event) {
    if (event.buttons != kSecondaryButton) return;

    _suppress();
  }

  ///
  void _suppress() {
    if (_isSuppressing) return;

    _isSuppressing = true;
    BrowserContextMenuService.suppress();
  }

  ///
  void _release() {
    if (!_isSuppressing) return;

    _isSuppressing = false;
    BrowserContextMenuService.release();
  }
}
