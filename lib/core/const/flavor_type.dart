/// Build flavor the application runs as.
///
/// Sealed, so a new flavor turns every exhaustive `switch` over the flavors
/// into a compile error instead of a silent change.
sealed class FlavorType {
  /// Short label of the flavor, shown in the debug banner.
  final String name = '';
}

/// Development release version with test functionality
final class FlavorDevelopment implements FlavorType {
  /// Short on purpose: the name is what the debug banner shows, and the
  /// banner's ribbon is narrow — a long word gets cut off by its own corner.
  @override
  final String name = 'Dev';
}

/// Pre-production release version aimed at a staging backend
final class FlavorStage implements FlavorType {
  ///
  @override
  final String name = 'Stage';
}

/// Production release version without test functionality
final class FlavorProduction implements FlavorType {
  ///
  @override
  final String name = 'Prod';
}
