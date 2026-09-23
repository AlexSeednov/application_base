import 'package:application_base/core/const/flavor_type.dart';
import 'package:application_base/core/service/configuration_service.dart';
import 'package:flutter/material.dart';

/// The corner ribbon that tells a non-production build apart at a glance.
///
/// Wraps the whole application, so it sits above every screen and no route
/// can cover it.
final class BannerPro extends StatelessWidget {
  ///
  const BannerPro({required this.application, super.key});

  ///
  final Widget application;

  ///
  @override
  Widget build(BuildContext context) {
    if (flavor is FlavorProduction) return application;

    /// The banner sits above the application, where no `Directionality`
    /// exists yet, so it brings its own.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Banner(
        // The flavor name is not user-facing and stays untranslated.
        message: flavor.name,
        location: BannerLocation.topEnd,
        child: application,
      ),
    );
  }
}
