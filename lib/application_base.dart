import 'package:application_base/core/const/flavor_type.dart';
import 'package:application_base/core/service/configuration_service.dart';
import 'package:application_base/core/service/service_locator.dart';
import 'package:application_base/presentation/service/lifecycle_service.dart';

abstract final class ApplicationBase {
  ///
  static void prepare({FlavorType? currentFlavor}) {
    /// Setup service locator
    ServiceLocatorBase.prepare();

    /// Set flator
    if (currentFlavor != null) flavor = currentFlavor;

    /// Prepare services
    getIt<LifecycleService>().prepare();
  }
}
