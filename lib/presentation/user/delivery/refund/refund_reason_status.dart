import 'package:flutter/material.dart';

/// 교환/환불 신청 화면 공통 상수·탭·사유 목록
class RefundReasonStatus {
  RefundReasonStatus._();

  static const Color pink = Color(0xFFFF5A8D);
  static const Color pinkAccent = Color(0xFFFF5C8F);
  static const Color pinkTint = Color(0x0CFF5C8F);
  static const Color ink = Color(0xFF1A1A1E);
  static const Color muted = Color(0xFF898686);
  static const Color mutedLabel = Color(0xFF898383);
  static const Color border = Color(0x7FD2D2D2);
  static const Color borderSolid = Color(0xFFD2D2D2);
  static const Color tabBg = Color(0xFFF9F9F9);
  static const Color required = Color(0xFFEF4444);
  static const Color stepperBg = Color(0xFFF6F6F6);

  /// 교환 신청 — 단계 변경(상담 연계)
  static const String reasonChangeStage = '다른 단계로 변경 필요';

  static const List<String> exchangeReasons = [
    '단순 변심',
    '주문 실수',
    '상품파손/불량',
    '오배송/배송지연',
    reasonChangeStage,
  ];

  static const List<String> refundReasons = [
    '단순 변심',
    '주문 실수',
    '상품파손/불량',
    '오배송/배송지연',
    '기타 사유',
  ];

  /// 헬스케어 스토어(일반) 교환·환불 공통 사유
  static const List<String> generalReasons = refundReasons;
}

enum RefundApplyTab { exchange, refund }
