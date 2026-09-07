import 'package:uuid/uuid.dart';

/// Source of the random identifiers an application stores with its records.
///
/// One instance for the whole application: `Uuid` carries a random number
/// generator, and building a fresh one per identifier is pure waste.
abstract final class UuidPro {
  ///
  static const Uuid _uuid = Uuid();

  /// A random (v4) identifier.
  static String get() => _uuid.v4();
}
