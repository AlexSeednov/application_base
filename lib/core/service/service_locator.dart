import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

/// Common instance for service locator
final getIt = GetIt.instance;

/// Injectable micro-package module.
///
/// build_runner collects every `@injectable` service of the package into
/// `service_locator.module.dart` (the `ApplicationBasePackageModule` class).
/// Consumers wire it via `externalPackageModulesBefore` in their
/// `@InjectableInit` — there is no manual registration
/// (`ServiceLocatorBase.prepare`) anymore; getIt is the single source of
/// singleton ownership.
@InjectableInit.microPackage()
void initApplicationBasePackage() {}
