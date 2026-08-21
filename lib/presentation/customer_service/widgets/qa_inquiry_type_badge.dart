import 'package:flutter/material.dart';

import '../../../data/models/qa/qa_inquiry_model.dart';
import '../../health/health_common/health_responsive_scale.dart';

class QaInquiryTypeBadge extends StatelessWidget {
  const QaInquiryTypeBadge({super.key, required this.type});

  factory QaInquiryTypeBadge.fromInquiry(QaInquiry inquiry) {
    return QaInquiryTypeBadge(type: inquiry.inquiryTypeBadgeKey);
  }

  final String type;

  static const String _font = 'Gmarket Sans TTF';

  static const _Style _fallback = _Style(
    label: '기타',
    background: Color(0xFFDFDFDF),
    foreground: Color(0xFF9CA6B9),
  );

  static const Map<String, _Style> _styles = {
    '상품 문의': _Style(
      label: '상품 문의',
      background: Color(0xFFFFEAF1),
      foreground: Color(0xFFFF5A8D),
    ),
    '예약/결제': _Style(
      label: '예약/결제',
      background: Color(0xFFE5F0FF),
      foreground: Color(0xFF2B6EF2),
    ),
    '배송 문의': _Style(
      label: '배송 문의',
      background: Color(0xFFE3F5EE),
      foreground: Color(0xFF12A879),
    ),
    '교환/반품': _Style(
      label: '교환/반품',
      background: Color(0xFFFFE6E6),
      foreground: Color(0xFFE25353),
    ),
    '취소/환불': _Style(
      label: '취소/환불',
      background: Color(0x33F29F2B),
      foreground: Color(0xFFF29F2B),
    ),
    '이벤트/쿠폰/회원': _Style(
      label: '이벤트/쿠폰/회원',
      background: Color(0xFFEFE5FF),
      foreground: Color(0xFFA52BF2),
    ),
    '기타': _fallback,
  };

  /// 동의어 → 대표 키 1개로 통일
  static String _normalizeKey(String raw) {
    final key = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    switch (key) {
      case '상품':
      case '상품문의':
      case '상품 문의':
        return '상품 문의';
      case '배송':
      case '배송문의':
      case '배송 문의':
        return '배송 문의';
      default:
        return key;
    }
  }

  _Style get _style {
    final key = _normalizeKey(type);
    return _styles[key] ??
        _Style(
          label: key.isEmpty ? _fallback.label : key,
          background: _fallback.background,
          foreground: _fallback.foreground,
        );
  }

  @override
  Widget build(BuildContext context) {
    final style = _style;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 6),
        vertical: healthDp(context, 2),
      ),
      decoration: ShapeDecoration(
        color: style.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(healthDp(context, 4)),
        ),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          color: style.foreground,
          fontSize: healthSp(context, 11),
          fontFamily: _font,
          fontWeight: FontWeight.w300,
          height: 1.5,
        ),
      ),
    );
  }
}

class _Style {
  const _Style({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;
}
