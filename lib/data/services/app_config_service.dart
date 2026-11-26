import 'dart:convert';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';

class PointSettings {
  final bool usePoint;
  final bool bonusPoint;
  final double pointRate;
  final int settleMinPoint;
  final int settleMaxPoint;
  final int settlePointUnit;

  const PointSettings({
    required this.usePoint,
    required this.bonusPoint,
    required this.pointRate,
    required this.settleMinPoint,
    required this.settleMaxPoint,
    required this.settlePointUnit,
  });

  /// 결제·주문 상세 예상 적립 표시 여부
  bool get showExpectedEarn => usePoint && bonusPoint;

  static const PointSettings defaults = PointSettings(
    usePoint: true,
    bonusPoint: true,
    pointRate: 1,
    settleMinPoint: 0,
    settleMaxPoint: 50000,
    settlePointUnit: 100,
  );
}

class AppConfigService {
  static const Duration _cacheTtl = Duration(minutes: 5);
  static PointSettings? _settings;
  static DateTime? _cachedAt;
  static Future<PointSettings>? _inFlight;

  static Future<bool> usePoint() async {
    final settings = await pointSettings();
    return settings.usePoint;
  }

  static Future<PointSettings> pointSettings({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _settings != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheTtl) {
      return _settings!;
    }
    final pending = _inFlight;
    if (!forceRefresh && pending != null) return pending;

    final request = _fetchPointSettings();
    _inFlight = request;
    try {
      final value = await request;
      _settings = value;
      _cachedAt = DateTime.now();
      return value;
    } finally {
      if (identical(_inFlight, request)) _inFlight = null;
    }
  }

  static Future<PointSettings> _fetchPointSettings() async {
    try {
      final response = await ApiClient.get(ApiEndpoints.config);
      if (response.statusCode != 200) return PointSettings.defaults;
      final body = json.decode(response.body);
      if (body is! Map || body['data'] is! Map) {
        return PointSettings.defaults;
      }
      final data = Map<String, dynamic>.from(body['data'] as Map);
      bool asBool(dynamic value, {bool fallback = true}) {
        if (value == null) return fallback;
        if (value is bool) return value;
        if (value is num) return value == 1;
        final s = '$value'.trim();
        if (s == '1' || s.toLowerCase() == 'true') return true;
        if (s == '0' || s.toLowerCase() == 'false') return false;
        return fallback;
      }

      int asInt(dynamic value, int fallback) {
        if (value is int) return value;
        if (value is num) return value.toInt();
        return int.tryParse('$value'.replaceAll(',', '').trim()) ?? fallback;
      }

      double asRate(dynamic value, double fallback) {
        if (value is double) return value;
        if (value is num) return value.toDouble();
        return double.tryParse('$value'.trim()) ?? fallback;
      }

      final unitRaw = asInt(data['de_settle_point_unit'], 100);
      final unit = (unitRaw == 1 || unitRaw == 10 || unitRaw == 100)
          ? unitRaw
          : 100;
      final maxRaw = asInt(data['de_settle_max_point'], 50000);
      return PointSettings(
        usePoint: asBool(data['cf_use_point'], fallback: true),
        bonusPoint: asBool(data['de_bonus_point'], fallback: true),
        pointRate: asRate(data['de_point_rate'], 1),
        settleMinPoint: asInt(data['de_settle_min_point'], 0).clamp(0, 1 << 30),
        settleMaxPoint: maxRaw > 0 ? maxRaw : 50000,
        settlePointUnit: unit,
      );
    } catch (_) {
      return PointSettings.defaults;
    }
  }
}
