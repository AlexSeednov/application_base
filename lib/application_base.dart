import 'package:application_base/core/const/flavor_type.dart';
import 'package:application_base/core/service/configuration_service.dart';
import 'package:application_base/core/service/service_locator.dart';
import 'package:application_base/presentation/service/lifecycle_service.dart';

abstract final class ApplicationBase {
  /// Post-DI package initialization.
  ///
  /// Service registration is now performed by the injectable module
  /// `ApplicationBasePackageModule` (wired via `externalPackageModulesBefore`
  /// in the consumer's `@InjectableInit`), so this method must be called AFTER
  /// the consumer's `getIt.init()` — it resolves `getIt<LifecycleService>()`.
  static void prepare({FlavorType? currentFlavor}) {
    /// Set flavor
    if (currentFlavor != null) flavor = currentFlavor;

    /// Prepare services
    getIt<LifecycleService>().prepare();
  }
}
