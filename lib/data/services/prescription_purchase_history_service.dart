import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging/failure_log.dart';
import '../../core/network/api_client.dart';
import '../models/delivery/delivery_model.dart';
import 'auth_service.dart';
import 'order_service.dart';

/// 비대면(처방) 상품을 배송/완료까지 구매한 이력이 있는지 판별.
///
/// 이력이 있으면 장바구니 아이콘 → 통합 장바구니,
/// 없으면(비로그인·미구매·일반만 구매) → 기존 드롭다운 유지.
class PrescriptionPurchaseHistoryService {
  static const String _cachePrefix = 'has_prescription_shipped_or_done_';
  static const Duration _negativeCacheTtl = Duration(minutes: 5);
  static final Map<String, DateTime> _negativeCacheAt = {};

  static String _cacheKey(String mbId) => '$_cachePrefix$mbId';

  /// od_status 기준: 배송 || 완료 (표시명/영문 상태 포함)
  static bool isShippedOrCompleted(OrderListModel order) {
    final status = order.odStatus.trim();
    final display = order.displayStatus.trim();
    final combined = '$status $display'.toLowerCase();

    if (status == '배송' || status == '완료') return true;
    if (display == '배송중' || display == '배송완료' || display == '완료') {
      return true;
    }
    if (status.contains('배송') || status.contains('완료')) return true;
    if (display.contains('배송') || display.contains('완료')) return true;
    if (combined.contains('deliver') ||
        combined.contains('finish') ||
        combined.contains('complete')) {
      return true;
    }
    return false;
  }

  static Future<void> markHasHistory(String mbId) async {
    if (mbId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_cacheKey(mbId), true);
  }

  static Future<void> clearCacheForUser(String mbId) async {
    if (mbId.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey(mbId));
  }

  /// 로그아웃 시 현재 유저 캐시 제거
  static Future<void> clearCurrentUserCache() async {
    final user = await AuthService.getUser();
    if (user == null) return;
    await clearCacheForUser(user.id);
  }

  /// 통합 장바구니를 쓸지 여부.
  /// 비로그인이면 항상 false (드롭다운).
  /// 확인에 실패하면 false. 실패는 [checkIntegratedCart]에서 로그를 남긴다.
  static Future<bool> shouldUseIntegratedCart() async {
    final check = await checkIntegratedCart();
    return check.ok && check.useIntegrated;
  }

  /// 비대면 구매 이력 확인. 실패하면 [ok]가 false이며 통합 장바구니로 보낸 것으로 보지 않는다.
  static Future<({bool ok, bool useIntegrated})> checkIntegratedCart() async {
    final user = await AuthService.getUser();
    if (user == null || user.id.trim().isEmpty) {
      return (ok: true, useIntegrated: false);
    }

    final mbId = user.id.trim();
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_cacheKey(mbId)) == true) {
      return (ok: true, useIntegrated: true);
    }
    final negativeAt = _negativeCacheAt[mbId];
    if (negativeAt != null &&
        DateTime.now().difference(negativeAt) < _negativeCacheTtl) {
      return (ok: true, useIntegrated: false);
    }

    try {
      final response = await ApiClient.get(
        '/api/orders/has-prescription-history?mb_id=${Uri.encodeQueryComponent(mbId)}',
      );
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        final hasHistory = body is Map && body['hasHistory'] == true;
        if (hasHistory) {
          await markHasHistory(mbId);
        } else {
          _negativeCacheAt[mbId] = DateTime.now();
        }
        return (ok: true, useIntegrated: hasHistory);
      }

      // 구버전 서버 배포 중에는 기존 목록 방식으로 호환합니다.
      final result = await OrderService.getOrderList(
        mbId: mbId,
        period: 0,
        status: 'all',
        page: 0,
        size: 1000,
      );

      if (result['success'] != true) {
        await _logHistoryFailure(
          mbId,
          result['message']?.toString().trim().isNotEmpty == true
              ? result['message'].toString()
              : '비대면 구매 이력을 확인하지 못했습니다.',
        );
        return (ok: false, useIntegrated: false);
      }

      final ordersList = result['orders'];
      if (ordersList is! List) {
        await _logHistoryFailure(mbId, '비대면 구매 이력 응답이 올바르지 않습니다.');
        return (ok: false, useIntegrated: false);
      }

      for (final raw in ordersList) {
        OrderListModel? order;
        if (raw is OrderListModel) {
          order = raw;
        } else if (raw is Map) {
          order = OrderListModel.fromJson(Map<String, dynamic>.from(raw));
        }
        if (order == null) continue;
        if (order.isPrescriptionOrder && isShippedOrCompleted(order)) {
          await markHasHistory(mbId);
          return (ok: true, useIntegrated: true);
        }
      }
    } catch (e) {
      await _logHistoryFailure(mbId, e.toString());
      return (ok: false, useIntegrated: false);
    }

    _negativeCacheAt[mbId] = DateTime.now();
    return (ok: true, useIntegrated: false);
  }

  static Future<void> _logHistoryFailure(String mbId, String reason) {
    return FailureLog.record(
      code: 'menu.cart.history',
      mbId: mbId,
      reason: reason,
    );
  }
}
