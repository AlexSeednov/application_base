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

    /// The banner is drawn before the application, so there is no
    /// `Directionality` above it yet — it has to bring its own
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Banner(
        // The flavor name is not a user-facing string and stays untranslated
        message: flavor.name,
        location: BannerLocation.topEnd,
        child: application,
      ),
    );
  }
}
