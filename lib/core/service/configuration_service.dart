import 'package:application_base/core/const/flavor_type.dart';
import 'package:application_base/core/service/logger_service.dart';

/// The current application flavor
///
/// **Important:** do not change after base set up
FlavorType? _flavor;

///
set flavor(FlavorType newFlavor) => _flavor = newFlavor;

///
FlavorType get flavor {
  if (_flavor == null) {
    logError(
      error:
          'Flavor is null. Do you forgot to set it via '
          'ApplicationBase.prepare?',
    );
    flavor = FlavorProduction();
  }
  return _flavor!;
}
