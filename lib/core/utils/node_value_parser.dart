import 'dart:convert';

/// Node.js Buffer 응답({type: "Buffer", data: [...]})을 앱에서 사용할 값으로 정규화한다.
class NodeValueParser {
  static dynamic normalize(dynamic value) {
    if (value is Map) {
      if (_isBufferMap(value)) {
        return _decodeBuffer(value);
      }

      return value.map(
        (key, mapValue) => MapEntry(key, normalize(mapValue)),
      );
    }

    if (value is List) {
      return value.map(normalize).toList();
    }

    return value;
  }

  static Map<String, dynamic> normalizeMap(Map<String, dynamic> json) {
    final normalized = normalize(json);
    if (normalized is Map<String, dynamic>) {
      return normalized;
    }
    if (normalized is Map) {
      return Map<String, dynamic>.from(normalized);
    }
    return <String, dynamic>{};
  }

  static String? asString(dynamic value) {
    final normalized = normalize(value);
    if (normalized == null) return null;
    if (normalized is String) return normalized;
    return normalized.toString();
  }

  static int? asInt(dynamic value) {
    final normalized = normalize(value);
    if (normalized == null) return null;
    if (normalized is int) return normalized;
    if (normalized is num) return normalized.toInt();
    return int.tryParse(normalized.toString());
  }

  static double? asDouble(dynamic value) {
    final normalized = normalize(value);
    if (normalized == null) return null;
    if (normalized is double) return normalized;
    if (normalized is num) return normalized.toDouble();
    return double.tryParse(normalized.toString());
  }

  static DateTime? asDateTime(dynamic value) {
    final stringValue = asString(value);
    if (stringValue == null || stringValue.isEmpty) return null;
    return DateTime.tryParse(stringValue);
  }

  static bool _isBufferMap(Map<dynamic, dynamic> value) {
    return value['type'] == 'Buffer' && value['data'] is List;
  }

  static String _decodeBuffer(Map<dynamic, dynamic> value) {
    final rawBytes = value['data'] as List;
    final bytes = rawBytes.whereType<num>().map((e) => e.toInt()).toList();
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return String.fromCharCodes(bytes);
    }
  }
}
