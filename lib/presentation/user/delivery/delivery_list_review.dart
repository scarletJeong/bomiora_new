import 'package:flutter/material.dart';

import '../../../core/logging/failure_log.dart';
import '../../../data/models/delivery/delivery_model.dart';
import '../../../data/models/review/review_model.dart';
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
  final reviewWritten = await openOrderReviewWrite(
    context,
    orderDetail: orderDetail,
    selectedProducts: products,
    reviewedItIds: reviewed,
    existingReviews: existing,
  );

  if (reviewWritten == true) {
    return const OrderListReviewResult(reload: true);
  }
  return null;
}

String orderReviewWriteLocation(String odId) {
  return '/review/write/${Uri.encodeComponent(odId.trim())}';
}

Future<bool?> openOrderReviewWrite(
  BuildContext context, {
  required OrderDetailModel orderDetail,
  required List<OrderItem> selectedProducts,
  List<String> reviewedItIds = const [],
  List<ReviewModel> existingReviews = const [],
}) {
  final odId = orderDetail.odId.trim();
  return Navigator.pushNamed<bool>(
    context,
    orderReviewWriteLocation(odId),
    arguments: {
      'orderDetail': orderDetail,
      'selectedProducts': selectedProducts,
      'reviewedItIds': reviewedItIds,
      'existingReviews': existingReviews,
    },
  );
}

/// `/review/write/:주문번호`. 인자로 연 경우 그 주문을 바로 쓰고, 주소만 있으면 다시 불러온다.
class OrderReviewWriteRoute extends StatefulWidget {
  const OrderReviewWriteRoute({super.key, required this.odId});

  final String odId;

  @override
  State<OrderReviewWriteRoute> createState() => _OrderReviewWriteRouteState();
}

class _OrderReviewWriteRouteState extends State<OrderReviewWriteRoute> {
  bool _started = false;
  bool _ready = false;
  OrderDetailModel? _order;
  List<OrderItem> _products = const [];
  List<String> _reviewed = const [];
  List<ReviewModel> _existing = const [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    final map = args is Map ? args : null;
    final order = map?['orderDetail'];
    if (order is OrderDetailModel) {
      _order = order;
      _products = _orderItems(map?['selectedProducts']);
      if (_products.isEmpty) _products = reviewableOrderProducts(order);
      _reviewed = _stringList(map?['reviewedItIds']);
      _existing = _reviewList(map?['existingReviews']);
      _ready = true;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    final odId = widget.odId.trim();
    final user = await AuthService.getUser();
    if (!mounted) return;
    if (user == null) {
      Navigator.pop(context);
      return;
    }
    try {
      final result = await OrderService.getOrderDetail(
        odId: odId,
        mbId: user.id,
      );
      if (!mounted) return;
      if (result['success'] != true || result['order'] is! OrderDetailModel) {
        await _reportOrderProductsFailure(
          context,
          mbId: user.id,
          odId: odId,
          cause: result['message']?.toString() ?? _orderProductsFailMessage,
        );
        if (mounted) Navigator.pop(context);
        return;
      }
      final order = result['order'] as OrderDetailModel;
      final check = await ReviewService.checkReviewExists(
        mbId: user.id,
        odId: odId,
      );
      if (!mounted) return;
      if (check['success'] != true) {
        await _reportReviewInfoFailure(
          context,
          mbId: user.id,
          odId: odId,
          cause: check['message']?.toString() ?? _reviewInfoFailMessage,
        );
        if (mounted) Navigator.pop(context);
        return;
      }
      final reviewed =
          (check['reviewedItIds'] as List<String>?) ?? const <String>[];
      var existing = ReviewService.reviewsOf(check);
      if (existing.isEmpty && reviewed.isNotEmpty) {
        try {
          existing = await ReviewService.reviewsForOrder(
            mbId: user.id,
            odId: odId,
          );
        } catch (e) {
          await _reportReviewInfoFailure(
            context,
            mbId: user.id,
            odId: odId,
            cause: e.toString(),
          );
          if (mounted) Navigator.pop(context);
          return;
        }
      }
      final pending = pendingReviewProducts(order, reviewed);
      if (pending.isEmpty) {
        if (mounted) {
          AppToastOverlay.show(context, '작성할 리뷰가 없습니다.');
          Navigator.pop(context);
        }
        return;
      }
      setState(() {
        _order = order;
        _products = reviewableOrderProducts(order);
        _reviewed = reviewed;
        _existing = existing;
        _ready = true;
      });
    } catch (e) {
      if (!mounted) return;
      await _reportOrderProductsFailure(
        context,
        mbId: user.id,
        odId: odId,
        cause: e.toString(),
      );
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    if (!_ready || order == null) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFFF5A8D)),
        ),
      );
    }
    if (order.isPrescriptionOrder) {
      return ReviewWriteScreen(
        orderDetail: order,
        selectedProducts: _products,
        reviewedItIds: _reviewed,
        existingReviews: _existing,
      );
    }
    return ReviewWriteGeneralScreen(
      orderDetail: order,
      selectedProducts: _products,
      reviewedItIds: _reviewed,
      existingReviews: _existing,
    );
  }
}

List<OrderItem> _orderItems(dynamic raw) {
  if (raw is List<OrderItem>) return raw;
  if (raw is! List) return const [];
  return raw.whereType<OrderItem>().toList();
}

List<String> _stringList(dynamic raw) {
  if (raw is List<String>) return raw;
  if (raw is! List) return const [];
  return raw.map((item) => item.toString().trim()).where((item) => item.isNotEmpty).toList();
}

List<ReviewModel> _reviewList(dynamic raw) {
  if (raw is List<ReviewModel>) return raw;
  if (raw is! List) return const [];
  return raw.whereType<ReviewModel>().toList();
}
