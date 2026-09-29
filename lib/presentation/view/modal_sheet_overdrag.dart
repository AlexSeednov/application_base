import 'dart:async';

import 'package:application_base/core/service/logger_service.dart';
import 'package:application_base/presentation/view/sheet_overdrag.dart';
import 'package:flutter/material.dart';

/// A modal bottom sheet that can be dragged by its scrollable content as
/// well ([SheetOverdrag]): the finger drives the same route transition a
/// drag by the header does. The barrier fades along with it, the sheet
/// closes by the same thresholds, and a sheet let go too early goes back.
///
/// Disposes of [transition] when the sheet leaves the screen.
final class ModalSheetOverdrag extends StatefulWidget {
  ///
  const ModalSheetOverdrag({
    required this.transition,
    required this.child,
    this.enabled = true,
    super.key,
  });

  /// The transition of the sheet's route.
  final SheetOverdragTransition transition;

  /// Whether the sheet may be dragged by its content — off together with the
  /// sheet's own drag.
  final bool enabled;

  ///
  final Widget child;

  ///
  @override
  State<ModalSheetOverdrag> createState() => _ModalSheetOverdragState();
}

/// The transition of a sheet that can be dragged by its content. The
/// controller and the curve go to the route (`transitionAnimationController`
/// and `sheetAnimationStyle`), and [ModalSheetOverdrag] moves the sheet along
/// them after the finger.
final class SheetOverdragTransition {
  ///
  SheetOverdragTransition(TickerProvider vsync)
    : controller = BottomSheet.createAnimationController(vsync) {
    controller.addStatusListener(_onStatus);
  }

  /// The transition controller: 0 — the sheet is gone, 1 — fully open.
  final AnimationController controller;

  /// The transition style: standard durations, the curve is [_curve].
  late final AnimationStyle style = AnimationStyle(
    curve: _curve,
    reverseCurve: _curve,
  );

  /// Flutter's standard curve of a modal sheet transition.
  static const Curve _standardCurve = Easing.legacyDecelerate;

  /// The curve the route sees. A [Curve] must not change, so the curve
  /// itself stays the same, and the mode lives in [_activeCurve].
  late final Curve _curve = _SheetOverdragCurve(this);

  /// The current mode of the curve. The standard curve is nearly flat at an
  /// open sheet, and the sheet would lag far behind the finger, so the curve
  /// is linear while the finger moves it, and after the finger lets go the
  /// sheet settles from where it was left. A drag by the header switches the
  /// curve the same way.
  Curve _activeCurve = _standardCurve;

  /// How far the sheet is shown: 0 — gone, 1 — fully open.
  double get _shown => _curve.transform(controller.value);

  /// The finger puts the sheet at [shown]. The curve is linear during the
  /// gesture, so the controller value is where the sheet is.
  void _drag(double shown) {
    _activeCurve = Curves.linear;
    controller.value = shown;
  }

  /// The finger let go of the sheet at [progress]: it settles from there.
  void _settleFrom(double progress) =>
      _activeCurve = Split(progress, endCurve: _standardCurve);

  /// The sheet is fully open — the curve is the standard one again.
  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) _activeCurve = _standardCurve;
  }

  ///
  void dispose() => controller.dispose();
}

///
final class _ModalSheetOverdragState extends State<ModalSheetOverdrag>
    implements SheetOverdragTarget {
  /// The downward fling speed that closes the sheet, as for the sheet's own
  /// drag.
  static const _closeFlingVelocity = 700.0;

  /// The share of the sheet's height below which a released sheet closes, as
  /// for the sheet's own drag.
  static const _closeProgressThreshold = 0.5;

  /// The route of the sheet.
  ModalRoute<Object?>? _route;

  ///
  SheetOverdragTransition get _transition => widget.transition;

  /// The sheet's height: the transition moves the sheet by all of it.
  double get _height => context.size?.height ?? 0;

  ///
  @override
  double get dragOffset => (1 - _transition._shown) * _height;

  ///
  @override
  bool get isDraggable =>
      widget.enabled &&
      _transition.controller.status != AnimationStatus.reverse &&
      _height > 0;

  ///
  @override
  void dragTo(double offset) => _transition._drag(1 - offset / _height);

  ///
  @override
  void release(double velocity) {
    final progress = _transition.controller.value;
    _transition._settleFrom(progress);

    final closing =
        velocity > _closeFlingVelocity || progress < _closeProgressThreshold;
    if (closing && (_route?.isCurrent ?? false)) {
      logInfo(info: 'Sheet dismissed by dragging its content down');
      Navigator.of(context).pop();
      return;
    }
    unawaited(_transition.controller.forward());
  }

  ///
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  /// The route does not dispose of a controller it was given, so it is done
  /// here. The sheet leaves the screen before the route is disposed, and the
  /// route only removes its listener from the controller. Later, when the
  /// route completes, is too late: a navigator closing with the application
  /// checks that the animations of its routes have stopped.
  @override
  void dispose() {
    _transition.dispose();
    super.dispose();
  }

  ///
  @override
  Widget build(BuildContext context) {
    return SheetOverdrag(target: this, child: widget.child);
  }
}

/// The curve of the sheet's transition: follows the mode
/// [SheetOverdragTransition] has chosen.
final class _SheetOverdragCurve extends Curve {
  ///
  const _SheetOverdragCurve(this._transition);

  ///
  final SheetOverdragTransition _transition;

  ///
  @override
  double transformInternal(double t) => _transition._activeCurve.transform(t);
}
