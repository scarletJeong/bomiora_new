import '../../../data/models/delivery/delivery_model.dart';

bool isOrderPaymentWaiting(OrderListModel order) {
  return order.displayStatus == '결제대기중' || order.odStatus == '주문';
}

bool isOrderDelivering(OrderListModel order) {
  return order.displayStatus == '배송중' || order.odStatus == '배송';
}

bool isOrderCompleted(OrderListModel order) {
  return order.displayStatus == '배송완료' || order.odStatus == '완료';
}

bool isOrderCancelled(OrderListModel order) {
  return order.displayStatus.contains('취소') ||
      order.odStatus.contains('취소') ||
      order.displayStatus == '주문 취소' ||
      order.displayStatus == '주문취소';
}

bool isOrderPreparing(OrderListModel order) {
  if (order.isPrescriptionOrder) return false;
  return order.displayStatus == '배송준비중' || order.odStatus == '준비';
}

bool isOrderConsultationDone(OrderListModel order) {
  if (!order.isPrescriptionOrder) return false;
  if (isOrderDelivering(order) ||
      isOrderCompleted(order) ||
      isOrderCancelled(order)) {
    return false;
  }
  if (order.isConsultationDone) return true;
  final display = order.displayStatus;
  return display == '상담완료' || display.contains('상담');
}

bool isOrderPaid(OrderListModel order) {
  if (isOrderPreparing(order) ||
      isOrderConsultationDone(order) ||
      isOrderDelivering(order) ||
      isOrderCompleted(order) ||
      isOrderCancelled(order)) {
    return false;
  }
  if (order.isPrescriptionOrder &&
      (order.odStatus == '입금' || order.odStatus == '준비')) {
    return true;
  }
  return order.displayStatus == '결제완료' || order.odStatus == '입금';
}
