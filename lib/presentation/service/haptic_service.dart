import 'package:application_base/core/mixin/logging_mixin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:injectable/injectable.dart';

/// Tactile feedback for the moments that deserve it.
///
/// A contract so a view model can be driven by a fake: the haptics engine
/// belongs to the platform, which a unit test has none of.
///
/// The vocabulary is small and semantic on purpose — a caller says what
/// happened, not how hard to buzz — so one application feels the same
/// throughout and can be retuned in this one place. Whether anything is felt
/// at all is left to the system: both mobile platforms honour their own
/// haptics switch, so an app needs no setting of its own.
abstract interface class HapticService {
  /// A selection moving under the finger: an item picked out of a row, a
  /// slider notch passed, a cell painted by a drag.
  ///
  /// The lightest tick there is, made to be repeated many times a second
  /// without getting tiresome.
  Future<void> selection();

  /// A small action landing: something ticked off, a sheet snapping into a
  /// fold, a pull-to-refresh arming.
  Future<void> lightImpact();

  /// A change of mode: a tool switching on, swapping what a gesture does.
  Future<void> mediumImpact();

  /// The pick-up of a context menu on a long press.
  ///
  /// Fills the gap on iOS only: Material's ink already answers a long press
  /// on Android with the platform's own long-press buzz, and a second one on
  /// top of it would double up.
  Future<void> longPress();

  /// A job coming good: a job finished, a file saved, a form accepted.
  Future<void> success();

  /// Something refused: a wrong code, a job that could not be done.
  Future<void> failure();
}

/// [HapticService] on top of the framework's platform bindings.
///
/// The framework offers only single taps, so the two-beat and three-beat
/// cues are composed here — timed to read as the system's own success and
/// error notifications rather than as a run of separate taps.
///
/// Safe to call from anywhere on any platform: where the platform has no
/// haptics engine the calls are dropped rather than thrown or logged over
/// and over.
@LazySingleton(as: HapticService)
final class HapticServicePlatform with LoggingMixin implements HapticService {
  ///
  @visibleForTesting
  HapticServicePlatform();

  ///
  @override
  String get logName => 'Haptic Service';

  /// Pause between the two beats of a success: long enough to be heard as
  /// two, short enough to be one gesture.
  static const Duration _successGap = Duration(milliseconds: 120);

  /// Pause between the beats of a failure: tighter than a success, so the
  /// run reads as a shake of the head rather than a drum roll.
  static const Duration _failureGap = Duration(milliseconds: 90);

  /// Set once the platform has said it has no haptics at all.
  ///
  /// Desktop and the web answer every single call that way, and a cue as
  /// frequent as [selection] would otherwise write a line to the log per
  /// tick of a drag. The verdict is permanent because its cause is: a
  /// platform does not grow an engine mid-session.
  bool _isUnavailable = false;

  ///
  @override
  Future<void> selection() => _play(HapticFeedback.selectionClick);

  ///
  @override
  Future<void> lightImpact() => _play(HapticFeedback.lightImpact);

  ///
  @override
  Future<void> mediumImpact() => _play(HapticFeedback.mediumImpact);

  ///
  @override
  Future<void> longPress() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    await _play(HapticFeedback.mediumImpact);
  }

  /// A lighter beat and then a heavier one: a rise, the way good news lands.
  @override
  Future<void> success() => _sequence([
    HapticFeedback.mediumImpact,
    HapticFeedback.heavyImpact,
  ], gap: _successGap);

  /// Three equal hard beats: a flat «no», nothing rising about it.
  @override
  Future<void> failure() => _sequence([
    HapticFeedback.heavyImpact,
    HapticFeedback.heavyImpact,
    HapticFeedback.heavyImpact,
  ], gap: _failureGap);

  /// Plays [beats] with [gap] between them, stopping the moment the platform
  /// turns out to have nothing to play with — a silent platform must not be
  /// paid for in delays.
  Future<void> _sequence(
    List<Future<void> Function()> beats, {
    required Duration gap,
  }) async {
    for (var index = 0; index < beats.length; index++) {
      if (_isUnavailable) return;

      if (index > 0) await Future<void>.delayed(gap);

      await _play(beats[index]);
    }
  }

  /// A platform that refuses is let go: a missing buzz is nothing, while a
  /// thrown error in the middle of a gesture would cost the gesture.
  ///
  /// A platform with no haptics channel at all is remembered and never asked
  /// again; anything else is logged and tried again next time, since it may
  /// be the one call that went wrong rather than the engine.
  Future<void> _play(Future<void> Function() beat) async {
    if (_isUnavailable) return;

    try {
      await beat();
    } on MissingPluginException {
      _isUnavailable = true;

      logNamedInfo(info: 'the platform has no haptics — cues are now dropped');
    } catch (error) {
      logNamedError(error: 'could not play haptic feedback: $error');
    }
  }
}
