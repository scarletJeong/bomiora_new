import 'dart:convert';
import '../models/shop_default/reservation_settings_model.dart';
import '../../core/network/api_client.dart';

class ShopDefaultService {
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
      return _cachedSettings;
    }
  }
}
