// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'dart:async' as _i687;

import 'package:application_base/data/local/service/storage_service.dart'
    as _i431;
import 'package:application_base/data/remote/service/connectivity_service.dart'
    as _i29;
import 'package:application_base/data/remote/utility/url_launcher_pro.dart'
    as _i268;
import 'package:application_base/data/remote/utility/url_launcher_router.dart'
    as _i635;
import 'package:application_base/domain/subject/network_subject.dart' as _i657;
import 'package:application_base/presentation/navigation/navigation_service_pro.dart'
    as _i229;
import 'package:application_base/presentation/navigation/navigation_service_router.dart'
    as _i429;
import 'package:application_base/presentation/service/lifecycle_service.dart'
    as _i198;
import 'package:application_base/presentation/view_model/access_vm.dart'
    as _i1049;
import 'package:injectable/injectable.dart' as _i526;

class ApplicationBasePackageModule extends _i526.MicroPackageModule {
// initializes the registration of main-scope dependencies inside of GetIt
  @override
  _i687.FutureOr<void> init(_i526.GetItHelper gh) {
    gh.lazySingleton<_i431.StorageService>(
        () => _i431.StorageService.singleton());
    gh.lazySingleton<_i29.ConnectivityService>(
      () => _i29.ConnectivityService.singleton(),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i657.NetworkSubject>(
      () => _i657.NetworkSubject.singleton(),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i198.LifecycleService>(
      () => _i198.LifecycleService.singleton(),
      dispose: (i) => i.dispose(),
    );
    gh.lazySingleton<_i1049.AccessVM>(() => _i1049.AccessVM.singleton());
    gh.lazySingleton<_i268.UrlLauncherPro>(() => _i635.UrlLauncherRouter());
    gh.lazySingleton<_i229.NavigationServicePro>(
        () => _i429.NavigationServiceRouter());
  }
}
