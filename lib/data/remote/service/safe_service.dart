import 'dart:convert';

import 'package:application_base/data/remote/entity/response_entity.dart';
import 'package:application_base/data/remote/service/network_logger_service.dart';

/// JSON parsing that logs a failure instead of throwing it.
abstract final class SafeService {
  /// Parses a JSON array body with [parseFunction], item by item.
  ///
  /// A broken item is logged and skipped, so one bad record does not lose the
  /// whole list. An empty body, or one that is not a valid JSON list, gives
  /// `[]`.
  static List<T> parseList<T>(
    ResponseEntity data,
    T Function(Map<String, dynamic> json) parseFunction,
  ) {
    if (data.body.isEmpty) return [];

    try {
      final Object decodedData = json.decode(data.body) as Object;
      if (decodedData is! List) throw Exception('JSON is not a list');
      final List<T> result = [];
      for (final Object? element in decodedData) {
        try {
          result.add(parseFunction(element! as Map<String, dynamic>));
        } catch (e) {
          logJsonParsingError(data: data, info: e.toString());
        }
      }
      return result;
    } catch (e) {
      logJsonParsingError(data: data, info: e.toString());
    }
    return [];
  }

  /// Parses a JSON object body with [parseFunction]; `null` on an empty body
  /// or a logged failure.
  static T? parse<T>(
    ResponseEntity data,
    T Function(Map<String, dynamic> json) parseFunction,
  ) {
    if (data.body.isEmpty) return null;

    try {
      return parseFunction(jsonDecode(data.body) as Map<String, dynamic>);
    } catch (e) {
      logJsonParsingError(data: data, info: e.toString());
    }
    return null;
  }
}
