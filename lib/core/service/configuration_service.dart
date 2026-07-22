import 'package:application_base/core/const/flavor_type.dart';

/// The current application flavor
///
/// **Important:** do not change after base set up
FlavorType? _flavor;

///
set flavor(FlavorType newFlavor) => _flavor = newFlavor;

/// Throws a [StateError] when read before the flavor was set.
///
/// Deliberately not falling back to [FlavorProduction]: a forgotten
/// `ApplicationBase.prepare` would silently point a debug build at the
/// production backend and production analytics. Failing loudly on the first
/// read is the cheaper outcome.
FlavorType get flavor {
  final FlavorType? currentFlavor = _flavor;
  if (currentFlavor == null) {
    throw StateError(
      'Flavor is not set. Call ApplicationBase.prepare(currentFlavor: ...) '
      'before reading it.',
    );
  }
  return currentFlavor;
}
