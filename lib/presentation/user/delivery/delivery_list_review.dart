import 'package:flutter/material.dart';

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

/// 목록의 리뷰쓰기. 작성 완료면 목록을 다시 불러온다.
Future<OrderListReviewResult?> writeOrderListReview(
  BuildContext context,
  String odId,
) async {
  try {
    final user = await AuthService.getUser();
    if (user == null) return null;
    final userId = user.id;

    final result = await OrderService.getOrderDetail(
      odId: odId,
      mbId: userId,
    );
    if (result['success'] != true) return null;

    final orderDetail = result['order'] as OrderDetailModel;
    final check = await ReviewService.checkReviewExists(
      mbId: userId,
      odId: odId,
    );
    final reviewed =
        (check['reviewedItIds'] as List<String>?) ?? const <String>[];
    final pending = pendingReviewProducts(orderDetail, reviewed);
    final products = reviewableOrderProducts(orderDetail);
    var existing = ReviewService.reviewsOf(check);
    if (existing.isEmpty && reviewed.isNotEmpty) {
      existing = await ReviewService.reviewsForOrder(
        mbId: userId,
        odId: odId,
      );
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
  } catch (e) {
    return null;
  }
}
