import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/utils/node_value_parser.dart';
import '../services/auth_service.dart';

class RecentViewService {
  static const String _localKey = 'recent_view_products_v1';
  static const int _maxLocalItems = 20;

  /// [recordView] 호출 시 증가 — 드로어 등에서 목록 갱신용
  static final ValueNotifier<int> revision = ValueNotifier(0);

  static void _notifyRevision() {
    revision.value++;
  }

  /// 상품 상세 진입 시 최근 본 상품 기록 (비로그인: 로컬, 로그인: 로컬+서버)
  static Future<void> recordView(
    String itId, {
    required String productKind,
    String? productName,
    String? imageUrl,
    int? price,
  }) async {
    final trimmedId = itId.trim();
    final kind = productKind.trim();
    if (trimmedId.isEmpty || kind.isEmpty) return;

    final entry = <String, dynamic>{
      'it_id': trimmedId,
      'it_kind': kind,
      if (productName != null && productName.trim().isNotEmpty)
        'product_name': productName.trim(),
      if (imageUrl != null && imageUrl.trim().isNotEmpty)
        'image_url': imageUrl.trim(),
      if (price != null) 'product_price': price,
      'viewed_at': DateTime.now().toIso8601String(),
    };

    await _saveLocalEntry(entry);
    _notifyRevision();

    try {
      final user = await AuthService.getUser();
      if (user == null || user.id.trim().isEmpty) return;

      await ApiClient.post(
        ApiEndpoints.recentViewRecord,
        {
          'mb_id': user.id,
          'it_id': trimmedId,
          'it_kind': kind,
        },
      );
    } catch (_) {
      // 최근 본 상품 기록 실패는 상세 화면 UX에 영향 없음
    }
  }

  /// 로그인·회원가입 직후 비로그인 시 로컬에 쌓인 기록을 서버에 반영
  static Future<void> syncLocalToAccount(String mbId) async {
    final id = mbId.trim();
    if (id.isEmpty) return;

    final local = await _getLocalList();
    if (local.isEmpty) return;

    for (final item in local.reversed) {
      final itId = NodeValueParser.asString(item['it_id'])?.trim() ?? '';
      final kind = (NodeValueParser.asString(item['it_kind']) ??
              NodeValueParser.asString(item['product_kind']) ??
              '')
          .trim();
      if (itId.isEmpty || kind.isEmpty) continue;

      try {
        await ApiClient.post(
          ApiEndpoints.recentViewRecord,
          {
            'mb_id': id,
            'it_id': itId,
            'it_kind': kind,
          },
        );
      } catch (_) {
        // 개별 실패는 무시하고 나머지 동기화 계속
      }
    }
  }

  /// 드로어·마이페이지 등에서 최근 본 상품 목록 조회
  static Future<List<Map<String, dynamic>>> getRecentList({
    int limit = 4,
  }) async {
    final safeLimit = limit.clamp(1, 20);

    try {
      final user = await AuthService.getUser();
      if (user != null && user.id.trim().isNotEmpty) {
        final server = await _fetchFromServer(user.id, safeLimit);
        if (server.isNotEmpty) return server;
      }
    } catch (_) {}

    return (await _getLocalList()).take(safeLimit).toList();
  }

  static Future<List<Map<String, dynamic>>> _fetchFromServer(
    String mbId,
    int limit,
  ) async {
    final response = await ApiClient.get(
      '${ApiEndpoints.recentViewList}?mb_id=${Uri.encodeQueryComponent(mbId)}&limit=$limit',
    );

    if (response.statusCode != 200 || response.body.trim().isEmpty) {
      return [];
    }

    final data = json.decode(response.body);
    if (data is! Map || data['success'] != true) return [];
    final rows = data['data'];
    if (rows is! List) return [];

    return rows
        .map((raw) {
          if (raw is! Map) return null;
          return NodeValueParser.normalizeMap(
            Map<String, dynamic>.from(raw),
          );
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  static Future<List<Map<String, dynamic>>> _getLocalList() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_localKey);
      if (raw == null || raw.trim().isEmpty) return [];

      final decoded = json.decode(raw);
      if (decoded is! List) return [];

      return decoded
          .map((item) {
            if (item is! Map) return null;
            return NodeValueParser.normalizeMap(
              Map<String, dynamic>.from(item),
            );
          })
          .whereType<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> _saveLocalEntry(Map<String, dynamic> entry) async {
    final itId = NodeValueParser.asString(entry['it_id'])?.trim() ?? '';
    final kind = NodeValueParser.asString(entry['it_kind'])?.trim() ?? '';
    if (itId.isEmpty || kind.isEmpty) return;

    final list = await _getLocalList();
    list.removeWhere((item) {
      final id = NodeValueParser.asString(item['it_id'])?.trim() ?? '';
      final k = (NodeValueParser.asString(item['it_kind']) ??
              NodeValueParser.asString(item['product_kind']) ??
              '')
          .trim();
      return id == itId && k == kind;
    });
    list.insert(0, entry);
    while (list.length > _maxLocalItems) {
      list.removeLast();
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localKey, json.encode(list));
  }
}
