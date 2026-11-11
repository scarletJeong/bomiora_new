import 'package:flutter/material.dart';

import '../../../core/logging/failure_log.dart';
import '../../../data/models/delivery/delivery_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/delivery_service.dart';
import '../../../data/services/review_service.dart';
import '../../common/widgets/app_toast_overlay.dart';
import '../review/review_write_general_screen.dart';
import '../review/review_write_screen.dart';
import 'widgets/delivery_select_list.dart';

bool orderListItemIsReviewable(OrderItem item) {
  if (item.itId.trim().isEmpty) return false;
  final parent = (item.parent ?? '').trim();
  if (parent.isNotEmpty) return false;
  final kind = (item.ctKind ?? '').toLowerCase().trim();
  if (kind.startsWith('supply_add|')) return false;
  return true;
}

/// 아직 쓸 리뷰가 남아 있으면 true.
bool orderListCanWriteReview(OrderListModel order, List<String> reviewedIds) {
  final reviewed = reviewedIds.toSet();
  final products = order.items.where(orderListItemIsReviewable).toList();
  if (products.isEmpty) {
    if (order.odCartCount > 0 && reviewed.length >= order.odCartCount) {
      return false;
    }
    return true;
  }
  return products.any((p) => !reviewed.contains(p.itId.trim()));
}

class OrderListReviewResult {
  const OrderListReviewResult({
    this.reload = false,
    this.reviewedIds,
  });

  final bool reload;
  final List<String>? reviewedIds;
}

const String _orderProductsFailMessage = '주문 상품을 불러오지 못했습니다.';
const String _reviewInfoFailMessage = '리뷰 정보를 불러오지 못했습니다.';

Future<void> _reportOrderProductsFailure(
  BuildContext context, {
  required String mbId,
  required String odId,
  required String cause,
}) async {
  await FailureLog.record(
    code: 'order.products',
    mbId: mbId,
    reason: _orderProductsFailMessage,
    detail: {
      'odId': odId,
      if (cause.isNotEmpty && cause != _orderProductsFailMessage) 'cause': cause,
    },
  );
  if (!context.mounted) return;
  AppToastOverlay.show(context, _orderProductsFailMessage);
}

Future<void> _reportReviewInfoFailure(
  BuildContext context, {
  required String mbId,
  required String odId,
  required String cause,
}) async {
  await FailureLog.record(
    code: 'order.review',
    mbId: mbId,
    reason: _reviewInfoFailMessage,
    detail: {
      'odId': odId,
      if (cause.isNotEmpty && cause != _reviewInfoFailMessage) 'cause': cause,
    },
  );
  if (!context.mounted) return;
  AppToastOverlay.show(context, _reviewInfoFailMessage);
}

/// 목록의 리뷰쓰기. 작성 완료면 목록을 다시 불러온다.
Future<OrderListReviewResult?> writeOrderListReview(
  BuildContext context,
  String odId,
) async {
  final user = await AuthService.getUser();
  if (user == null) return null;
  final userId = user.id;

  late final OrderDetailModel orderDetail;
  try {
    final result = await OrderService.getOrderDetail(
      odId: odId,
      mbId: userId,
    );
    if (result['success'] != true || result['order'] is! OrderDetailModel) {
      await _reportOrderProductsFailure(
        context,
        mbId: userId,
        odId: odId,
        cause: result['message']?.toString() ?? _orderProductsFailMessage,
      );
      return null;
    }
    orderDetail = result['order'] as OrderDetailModel;
  } catch (e) {
    await _reportOrderProductsFailure(
      context,
      mbId: userId,
      odId: odId,
      cause: e.toString(),
    );
    return null;
  }

  final check = await ReviewService.checkReviewExists(
    mbId: userId,
    odId: odId,
  );
  if (check['success'] != true) {
    await _reportReviewInfoFailure(
      context,
      mbId: userId,
      odId: odId,
      cause: check['message']?.toString() ?? _reviewInfoFailMessage,
    );
    return null;
  }
  final reviewed =
      (check['reviewedItIds'] as List<String>?) ?? const <String>[];
  final pending = pendingReviewProducts(orderDetail, reviewed);
  final products = reviewableOrderProducts(orderDetail);
  var existing = ReviewService.reviewsOf(check);
  if (existing.isEmpty && reviewed.isNotEmpty) {
    try {
      existing = await ReviewService.reviewsForOrder(
        mbId: userId,
        odId: odId,
      );
    } catch (e) {
      await _reportReviewInfoFailure(
        context,
        mbId: userId,
        odId: odId,
        cause: e.toString(),
      );
      return null;
    }
  }

  if (pending.isEmpty) {
    if (context.mounted) {
      AppToastOverlay.show(context, '작성할 리뷰가 없습니다.');
    }
    return OrderListReviewResult(reviewedIds: reviewed);
  }

  if (!context.mounted) return null;
  final isPrescription = orderDetail.isPrescriptionOrder;
  final bool? reviewWritten = await Navigator.push<bool>(
    context,
    MaterialPageRoute(
      builder: (_) => isPrescription
          ? ReviewWriteScreen(
              orderDetail: orderDetail,
              selectedProducts: products,
              reviewedItIds: reviewed,
              existingReviews: existing,
            )
          : ReviewWriteGeneralScreen(
              orderDetail: orderDetail,
              selectedProducts: products,
              reviewedItIds: reviewed,
              existingReviews: existing,
            ),
    ),
  );

  if (reviewWritten == true) {
    return const OrderListReviewResult(reload: true);
  }
  return null;
}
