import 'package:application_base/core/service/logger_service.dart';
import 'package:meta/meta.dart';

base mixin LoggingMixin {
  /// Name for logger
  @mustBeOverridden
  String get logName;

  ///
  void logNamedInfo({required String info}) =>
      logInfo(info: logName, additional: info);

  ///
  void logNamedImportant({required String info}) =>
      logImportant(info: logName, additional: info);

  ///
  void logNamedError({required String error}) =>
      logError(error: logName, additional: error);
}
