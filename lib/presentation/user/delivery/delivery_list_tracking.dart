import 'package:flutter/material.dart';

import '../../../core/logging/failure_log.dart';
import '../../../data/models/delivery/delivery_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/delivery_service.dart';
import '../../../utils/delivery_tracker.dart';
import '../../common/widgets/app_toast_overlay.dart';

/// 목록의 배송 조회.
Future<void> trackOrderDelivery(BuildContext context, String odId) async {
  try {
    final user = await AuthService.getUser();
    if (!context.mounted) return;
    if (user == null) {
      await _notifyTrackingFailure(context, odId, '로그인 정보가 없습니다.');
      return;
    }

    final result = await OrderService.getOrderDetail(
      odId: odId,
      mbId: user.id,
    );
    if (!context.mounted) return;
    if (result['success'] != true) {
      await _notifyTrackingFailure(
        context,
        odId,
        result['message']?.toString() ?? '주문 정보를 불러오지 못했습니다.',
        mbId: user.id,
      );
      return;
    }

    if (!context.mounted) return;
    final orderDetail = result['order'] as OrderDetailModel;
    await _openCourierTracking(
      context,
      odId: odId,
      mbId: user.id,
      companyName: orderDetail.deliveryCompany,
      trackingNumber: orderDetail.trackingNumber,
    );
  } catch (e) {
    if (!context.mounted) return;
    await _notifyTrackingFailure(context, odId, e.toString());
  }
}

Future<bool> _openCourierTracking(
  BuildContext context, {
  required String odId,
  required String mbId,
  required String? companyName,
  required String? trackingNumber,
}) async {
  final company = companyName?.trim() ?? '';
  final tracking = trackingNumber?.trim() ?? '';
  if (company.isEmpty) {
    await _notifyTrackingFailure(context, odId, '택배사 정보가 없습니다.', mbId: mbId);
    return false;
  }
  if (tracking.isEmpty) {
    await _notifyTrackingFailure(
      context,
      odId,
      '운송장 번호가 없습니다.',
      mbId: mbId,
      company: company,
    );
    return false;
  }
  if (!DeliveryTracker.isSupported(company)) {
    await _notifyTrackingFailure(
      context,
      odId,
      '지원하지 않는 택배사입니다.',
      mbId: mbId,
      company: company,
    );
    return false;
  }
  final opened = await DeliveryTracker.openTrackingPage(company, tracking);
  if (!context.mounted) return opened;
  if (!opened) {
    await _notifyTrackingFailure(
      context,
      odId,
      '배송 조회 페이지를 열지 못했습니다.',
      mbId: mbId,
      company: company,
    );
  }
  return opened;
}

Future<void> _notifyTrackingFailure(
  BuildContext context,
  String odId,
  String reason, {
  String? mbId,
  String? company,
}) async {
  await FailureLog.record(
    code: 'order.tracking',
    mbId: mbId ?? AuthService.currentUser?.id ?? '',
    reason: reason,
    detail: {
      'odId': odId,
      if (company != null && company.isNotEmpty) 'company': company,
    },
  );
  if (!context.mounted) return;
  AppToastOverlay.show(context, '배송 조회를 실패했습니다.');
}
