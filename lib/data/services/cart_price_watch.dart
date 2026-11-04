import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/cart/cart_item_model.dart';

/// 마지막으로 장바구니에서 확인한 단가. 다음 조회에서 달라지면 한 번 알린다.
class CartPriceWatch {
  CartPriceWatch._();

  static const String _prefKey = 'cart_seen_unit_prices_v1';
  static Map<int, String>? _seen;
  static Future<void> _queue = Future<void>.value();

  static String _signature(CartItem item) =>
      '${item.ctPrice}|${item.ioPrice ?? 0}';

  /// 이전에 본 줄의 단가·옵션가가 바뀌었으면 true. 이번 목록을 확인한 가격으로 남긴다.
  static Future<bool> consumeChanges(List<CartItem> incoming) {
    final done = Completer<bool>();
    _queue = _queue.then((_) async {
      try {
        done.complete(await _consume(incoming));
      } catch (e, st) {
        done.completeError(e, st);
      }
    });
    return done.future;
  }

  static Future<bool> _consume(List<CartItem> incoming) async {
    final seen = await _load();
    var changed = false;
    final next = <int, String>{};
    for (final item in incoming) {
      if (item.ctId <= 0) continue;
      final signature = _signature(item);
      final previous = seen[item.ctId];
      if (previous != null && previous != signature) changed = true;
      next[item.ctId] = signature;
    }
    _seen = next;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefKey,
      jsonEncode(next.map((id, signature) => MapEntry('$id', signature))),
    );
    return changed;
  }

  static Future<Map<int, String>> _load() async {
    final cached = _seen;
    if (cached != null) return cached;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    final loaded = <int, String>{};
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          for (final entry in decoded.entries) {
            final id = int.tryParse(entry.key.toString());
            final signature = entry.value?.toString() ?? '';
            if (id == null || id <= 0 || signature.isEmpty) continue;
            loaded[id] = signature;
          }
        }
      } catch (_) {}
    }
    _seen = loaded;
    return loaded;
  }
}
