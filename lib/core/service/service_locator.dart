import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

/// Common instance for service locator
final GetIt getIt = GetIt.instance;

/// Injectable micro-package module of the package.
///
/// build_runner collects every injectable service of the package into
/// `service_locator.module.dart` (`ApplicationBasePackageModule`), and the
/// application wires it through `externalPackageModulesBefore` in its
/// `@InjectableInit`. getIt alone owns the singletons: there is no manual
/// registration to call.
@InjectableInit.microPackage()
void initApplicationBasePackage() {}
