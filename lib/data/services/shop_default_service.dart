import 'dart:convert';
import '../models/shop_default/reservation_settings_model.dart';
import '../../core/network/api_client.dart';

class ShopDefaultService {
  static Future<ReservationSettingsModel?> getReservationSettings() async {
    try {
      final response = await ApiClient.get('/api/shop/reservation-settings');
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return ReservationSettingsModel.fromJson(responseData);
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }
}

