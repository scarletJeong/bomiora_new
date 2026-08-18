import 'package:flutter/material.dart';

import '../models/product/product_option_model.dart';
import 'cart_service.dart';

enum PendingProductCheckoutAction { prescriptionCart, reserve }

/// 비로그인 상태에서 고른 본품/추가상품 옵션을 로그인·회원가입 이후까지 유지한다.
class PendingProductCheckout {
  PendingProductCheckout._({
    required this.productId,
    required this.action,
    required this.optionEntries,
    required this.supplyEntries,
  });

  final String productId;
  final PendingProductCheckoutAction action;
  final List<Map<String, dynamic>> optionEntries;
  final List<Map<String, dynamic>> supplyEntries;

  static PendingProductCheckout? _current;

  static bool get hasPending => _current != null;

  static PendingProductCheckout? peek() => _current;

  static PendingProductCheckout? take() {
    final current = _current;
    _current = null;
    return current;
  }

  static void clear() {
    _current = null;
  }

  static void save({
    required String productId,
    required PendingProductCheckoutAction action,
    required Map<ProductOption, int> selectedOptions,
    List<SupplyCartLine> supplyLines = const [],
  }) {
    _current = PendingProductCheckout._(
      productId: productId,
      action: action,
      optionEntries: [
        for (final e in selectedOptions.entries)
          {
            ..._optionToJson(e.key),
            'qty': e.value,
          },
      ],
      supplyEntries: [
        for (final line in supplyLines)
          {
            'productId': line.productId,
            'productName': line.productName,
            'basePrice': line.basePrice,
            'quantity': line.quantity,
            'attachedMainLineId': line.attachedMainLineId,
            if (line.option != null) 'option': _optionToJson(line.option!),
          },
      ],
    );
  }

  static Map<String, dynamic> _optionToJson(ProductOption option) {
    return {
      'id': option.id,
      'io_id': option.id,
      'productId': option.productId,
      'it_id': option.productId,
      'io_price': option.price,
      'io_stock_qty': option.stock,
      'io_type': option.ioType,
      'type': option.type,
    };
  }

  Map<ProductOption, int> restoreOptions(List<ProductOption> loaded) {
    final byId = {for (final o in loaded) o.id: o};
    final restored = <ProductOption, int>{};
    for (final raw in optionEntries) {
      final id = (raw['id'] ?? raw['io_id'] ?? '').toString();
      final qty = raw['qty'];
      final quantity = qty is int ? qty : int.tryParse('$qty') ?? 1;
      if (id.isEmpty || quantity <= 0) continue;
      restored[byId[id] ?? ProductOption.fromJson(raw)] = quantity;
    }
    return restored;
  }

  List<SupplyCartLine> restoreSupplyLines() {
    return [
      for (final raw in supplyEntries)
        SupplyCartLine(
          productId: (raw['productId'] ?? '').toString(),
          productName: (raw['productName'] ?? '').toString(),
          basePrice: raw['basePrice'] is int
              ? raw['basePrice'] as int
              : int.tryParse('${raw['basePrice']}') ?? 0,
          quantity: raw['quantity'] is int
              ? raw['quantity'] as int
              : int.tryParse('${raw['quantity']}') ?? 1,
          attachedMainLineId: raw['attachedMainLineId']?.toString(),
          option: raw['option'] is Map
              ? ProductOption.fromJson(
                  Map<String, dynamic>.from(raw['option'] as Map),
                )
              : null,
        ),
    ];
  }

  static bool navigateAfterAuth(BuildContext context) {
    final pending = peek();
    if (pending == null || pending.productId.isEmpty) return false;
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/product/${pending.productId}',
      (route) => false,
    );
    return true;
  }
}
