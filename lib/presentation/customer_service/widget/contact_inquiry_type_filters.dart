import 'package:flutter/material.dart';

import '../../common/widgets/dropdown_btn.dart';

/// 문의 유형(목록 필터·문의 폼 공통)
const List<String> contactInquiryPrimaryTypes = [
  '회원',
  '주문/결제',
  '배송',
  '취소/환불/교환',
  '쿠폰/혜택/이벤트',
  '기타',
];

const Map<String, List<String>> contactInquiryDetailMap = {
  '회원': ['가입', '탈퇴', '회원정보', '로그인'],
  '주문/결제': ['상품', '결제', '구매내역'],
  '배송': ['배송상태', '배송정보'],
  '취소/환불/교환': ['취소신청', '환불 신청', '교환 신청'],
  '쿠폰/혜택/이벤트': ['쿠폰', '할인혜택', '이벤트'],
  '기타': ['칭찬', '불만', '제안', '오류 제보'],
};

/// 구 저장 제목의 대분류 문자열을 현재 키로 맞춤 (예: `회원/가입` → `회원`)
String normalizeContactInquiryPrimaryLabel(String raw) {
  final t = raw.trim();
  if (t == '회원/가입') return '회원';
  if (contactInquiryDetailMap.containsKey(t)) return t;
  return contactInquiryPrimaryTypes.first;
}

/// 1:1 문의 **작성/수정 폼** — 목록과 동일한 드롭다운 스타일
class ContactInquiryTypeSelectorRow extends StatefulWidget {
  const ContactInquiryTypeSelectorRow({
    super.key,
    required this.primaryType,
    required this.detailType,
    required this.onChanged,
  });

  final String primaryType;
  final String detailType;
  final void Function(String primary, String detail) onChanged;

  @override
  State<ContactInquiryTypeSelectorRow> createState() =>
      _ContactInquiryTypeSelectorRowState();
}

class _ContactInquiryTypeSelectorRowState
    extends State<ContactInquiryTypeSelectorRow> {
  @override
  Widget build(BuildContext context) {
    final primary = widget.primaryType;
    final detailOpts = contactInquiryDetailMap[primary] ?? const ['기타'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: DropdownBtn(
            items: contactInquiryPrimaryTypes,
            value: primary,
            emptyText: '문의 유형',
            onChanged: (v) {
              final details = contactInquiryDetailMap[v] ?? const ['기타'];
              widget.onChanged(v, details.first);
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownBtn(
            enabled: primary.isNotEmpty,
            items: detailOpts,
            value: widget.detailType,
            emptyText: '상세 유형',
            onChanged: (v) => widget.onChanged(primary, v),
          ),
        ),
      ],
    );
  }
}

/// 1:1 문의 목록 상단 — 문의 유형 / 상세 유형 선택 (미선택 시 플레이스홀더).
class ContactInquiryTypeFilters extends StatefulWidget {
  const ContactInquiryTypeFilters({super.key});

  @override
  State<ContactInquiryTypeFilters> createState() =>
      _ContactInquiryTypeFiltersState();
}

class _ContactInquiryTypeFiltersState extends State<ContactInquiryTypeFilters> {
  String? _selectedPrimary;
  String? _selectedDetail;

  @override
  Widget build(BuildContext context) {
    final hasPrimary =
        _selectedPrimary != null && _selectedPrimary!.isNotEmpty;
    final detailOptions = hasPrimary
        ? (contactInquiryDetailMap[_selectedPrimary!] ?? const ['기타'])
        : const <String>[];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: DropdownBtn(
            items: contactInquiryPrimaryTypes,
            value: _selectedPrimary ?? '',
            emptyText: '문의 유형 선택',
            onChanged: (v) {
              setState(() {
                _selectedPrimary = v;
                _selectedDetail = null;
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownBtn(
            enabled: hasPrimary,
            items: detailOptions,
            value: _selectedDetail ?? '',
            emptyText: '상세 유형 선택',
            onChanged: (v) => setState(() => _selectedDetail = v),
          ),
        ),
      ],
    );
  }
}
