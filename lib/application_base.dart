import 'package:application_base/core/const/flavor_type.dart';
import 'package:application_base/core/service/configuration_service.dart';
import 'package:application_base/core/service/service_locator.dart';
import 'package:application_base/presentation/service/lifecycle_service.dart';

/// Entry point for the package's own start-up, separate from DI wiring.
abstract final class ApplicationBase {
  /// Sets the flavor and starts the package's services.
  ///
  /// Call it after the consumer's `getIt.init()`: registration belongs to the
  /// injectable module `ApplicationBasePackageModule`, and this method
  /// resolves [LifecycleService] from getIt.
  static void prepare({FlavorType? currentFlavor}) {
    if (currentFlavor != null) flavor = currentFlavor;

    getIt<LifecycleService>().prepare();
  }
}
