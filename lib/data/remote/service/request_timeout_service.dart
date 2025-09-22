import 'package:application_base/data/remote/const/request_duration_type.dart';

abstract final class RequestTimeoutService {
  /// For super fast requests, e.g. ping
  static const _short = Duration(seconds: 3);

  /// Default value for most requests
  static const _normal = Duration(seconds: 20);

  /// For probably heavy requests, e.g. sending a photo
  static const _long = Duration(seconds: 30);

  ///
  static Duration timeout(RequestDurationType type) => switch (type) {
    RequestDurationType.short => _short,
    RequestDurationType.normal => _normal,
    RequestDurationType.long => _long,
  };
}
