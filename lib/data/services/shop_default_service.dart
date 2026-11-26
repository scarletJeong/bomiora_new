import 'dart:convert';
import '../models/shop_default/company_info_model.dart';
import '../models/shop_default/reservation_settings_model.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';

class ShopDefaultService {
  static CompanyInfo? _cachedCompanyInfo;
  static DateTime? _companyCachedAt;
  static Future<CompanyInfo?>? _companyInFlight;
  static const Duration _companyCacheTtl = Duration(minutes: 5);

  static Future<CompanyInfo?> getCompanyInfo({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedCompanyInfo != null &&
        _companyCachedAt != null &&
        DateTime.now().difference(_companyCachedAt!) < _companyCacheTtl) {
      return _cachedCompanyInfo;
    }
    if (!forceRefresh && _companyInFlight != null) {
      return _companyInFlight;
    }

    final request = _fetchCompanyInfo();
    _companyInFlight = request;
    try {
      return await request;
    } finally {
      if (identical(_companyInFlight, request)) _companyInFlight = null;
    }
  }

  static Future<CompanyInfo?> _fetchCompanyInfo() async {
    try {
      final response = await ApiClient.get(ApiEndpoints.companyInfo);
      if (response.statusCode != 200) return _cachedCompanyInfo;
      final body = json.decode(response.body);
      if (body is! Map || body['success'] != true || body['data'] is! Map) {
        return _cachedCompanyInfo;
      }
      final info = CompanyInfo.fromJson(
        Map<String, dynamic>.from(body['data'] as Map),
      );
      _cachedCompanyInfo = info;
      _companyCachedAt = DateTime.now();
      return info;
    } catch (_) {
      return _cachedCompanyInfo;
    }
  }

  static ReservationSettingsModel? _cachedSettings;
  static DateTime? _cachedAt;
  static Future<ReservationSettingsModel?>? _inFlight;
  static const Duration _cacheTtl = Duration(minutes: 10);

  static Future<ReservationSettingsModel?> getReservationSettings({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cachedSettings != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheTtl) {
      return _cachedSettings;
    }

    if (!forceRefresh && _inFlight != null) {
      return _inFlight;
    }

    _inFlight = _fetchReservationSettings().whenComplete(() {
      _inFlight = null;
    });
    return _inFlight;
  }

  /// 예약 시간 변경 창용. 조회가 실패하면 예전 설정을 성공처럼 돌려주지 않는다.
  static Future<({ReservationSettingsModel? settings, bool failed, String reason})>
      loadReservationSettings({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cachedSettings != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheTtl) {
      return (settings: _cachedSettings, failed: false, reason: '');
    }

    try {
      final response = await ApiClient.get('/api/shop/reservation-settings');
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final settings = ReservationSettingsModel.fromJson(responseData);
        _cachedSettings = settings;
        _cachedAt = DateTime.now();
        return (settings: settings, failed: false, reason: '');
      }
      return (
        settings: null,
        failed: true,
        reason: '예약 설정 조회에 실패했습니다. (${response.statusCode})',
      );
    } catch (e) {
      return (settings: null, failed: true, reason: e.toString());
    }
  }

  static Future<ReservationSettingsModel?> _fetchReservationSettings() async {
    try {
      final response = await ApiClient.get('/api/shop/reservation-settings');

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final settings = ReservationSettingsModel.fromJson(responseData);
        _cachedSettings = settings;
        _cachedAt = DateTime.now();
        return settings;
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
