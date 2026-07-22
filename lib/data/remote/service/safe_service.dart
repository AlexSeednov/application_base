import 'dart:convert';

import 'package:application_base/data/remote/entity/response_entity.dart';
import 'package:application_base/data/remote/service/network_logger_service.dart';

/// Methods for safe work with entities
abstract final class SafeService {
  /// Safe parse JSON with list from string
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
          /// Error with one of items in list, log it
          logJsonParsingError(data: data, info: e.toString());
        }
      }
      return result;
    } catch (e) {
      /// Log it
      logJsonParsingError(data: data, info: e.toString());
    }
    return [];
  }

  /// Safe parse JSON from string
  static T? parse<T>(
    ResponseEntity data,
    T Function(Map<String, dynamic> json) parseFunction,
  ) {
    if (data.body.isEmpty) return null;

    try {
      return parseFunction(jsonDecode(data.body) as Map<String, dynamic>);
    } catch (e) {
      /// Log it
      logJsonParsingError(data: data, info: e.toString());
    }
    return null;
  }
}
