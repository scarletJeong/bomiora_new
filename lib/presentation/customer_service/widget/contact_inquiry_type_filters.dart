import 'package:flutter/material.dart';

const TextStyle _kInquiryMenuItemStyle = TextStyle(
  color: Colors.black,
  fontSize: 10,
  fontFamily: 'Gmarket Sans TTF',
  fontWeight: FontWeight.w300,
);

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
  '회원': ['회원정보', '로그인', '탈퇴'],
  '주문/결제': ['상품', '결제', '구매내역'],
  '배송': ['배송조회', '배송일정', '기타'],
  '취소/환불/교환': ['취소', '환불', '교환'],
  '쿠폰/혜택/이벤트': ['쿠폰', '이벤트', '적립금'],
  '기타': ['기타'],
};

/// 구 저장 제목의 대분류 문자열을 현재 키로 맞춤 (예: `회원/가입` → `회원`)
String normalizeContactInquiryPrimaryLabel(String raw) {
  final t = raw.trim();
  if (t == '회원/가입') return '회원';
  if (contactInquiryDetailMap.containsKey(t)) return t;
  return contactInquiryPrimaryTypes.first;
}

const Color _kBorderStrong = Color(0xFFD2D2D2);
const Color _kMuted = Color(0xFF898686);

/// 1:1 문의 **작성/수정 폼** — 목록과 동일한 오버레이 메뉴 스타일 (값은 항상 선택됨)
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
  final GlobalKey _typeFieldKey = GlobalKey();
  final GlobalKey _detailFieldKey = GlobalKey();
  OverlayEntry? _menuOverlay;

  @override
  void dispose() {
    _removeMenuOverlay();
    super.dispose();
  }

  void _removeMenuOverlay() {
    _menuOverlay?.remove();
    _menuOverlay = null;
  }

  void _openMenu({
    required GlobalKey anchorKey,
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) {
    _removeMenuOverlay();
    final ctx = anchorKey.currentContext;
    if (ctx == null) return;

    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final overlayState = Overlay.of(context);
    final pos = box.localToGlobal(Offset.zero);
    final top = pos.dy + box.size.height + 4;
    const menuWidth = 154.0;

    _menuOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _removeMenuOverlay,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: pos.dx
                  .clamp(8.0, MediaQuery.sizeOf(context).width - menuWidth - 8),
              top: top,
              width: menuWidth,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x19000000),
                        blurRadius: 4,
                        offset: Offset(0, 0),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < options.length; i++) ...[
                        if (i > 0) const SizedBox(height: 5),
                        _MenuLine(
                          label: options[i],
                          showBottomDivider: i < options.length - 1,
                          onTap: () {
                            onSelected(options[i]);
                            _removeMenuOverlay();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    overlayState.insert(_menuOverlay!);
  }

  Widget _buildTrigger({
    required GlobalKey fieldKey,
    required String displayText,
    required bool isPlaceholder,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Expanded(
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          key: fieldKey,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 1, color: _kBorderStrong),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    displayText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isPlaceholder ? _kMuted : Colors.black,
                      fontSize: 10,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: enabled ? Colors.black87 : _kMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = widget.primaryType;
    final detailOpts = contactInquiryDetailMap[primary] ?? const ['기타'];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTrigger(
          fieldKey: _typeFieldKey,
          displayText: primary,
          isPlaceholder: false,
          onTap: () => _openMenu(
            anchorKey: _typeFieldKey,
            options: contactInquiryPrimaryTypes,
            onSelected: (v) {
              final details = contactInquiryDetailMap[v] ?? const ['기타'];
              widget.onChanged(v, details.first);
            },
          ),
        ),
        const SizedBox(width: 10),
        _buildTrigger(
          fieldKey: _detailFieldKey,
          displayText: widget.detailType,
          isPlaceholder: false,
          onTap: () => _openMenu(
            anchorKey: _detailFieldKey,
            options: detailOpts,
            onSelected: (v) => widget.onChanged(primary, v),
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
  final GlobalKey _typeFieldKey = GlobalKey();
  final GlobalKey _detailFieldKey = GlobalKey();
  OverlayEntry? _menuOverlay;

  String? _selectedPrimary;
  String? _selectedDetail;

  @override
  void dispose() {
    _removeMenuOverlay();
    super.dispose();
  }

  void _removeMenuOverlay() {
    _menuOverlay?.remove();
    _menuOverlay = null;
  }

  void _showAnchoredMenu({
    required GlobalKey anchorKey,
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) {
    _removeMenuOverlay();
    final ctx = anchorKey.currentContext;
    if (ctx == null) return;

    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final overlay = Overlay.of(context);
    final pos = box.localToGlobal(Offset.zero);
    final top = pos.dy + box.size.height + 4;
    const menuWidth = 154.0;

    _menuOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _removeMenuOverlay,
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: pos.dx
                  .clamp(8.0, MediaQuery.sizeOf(context).width - menuWidth - 8),
              top: top,
              width: menuWidth,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x19000000),
                        blurRadius: 4,
                        offset: Offset(0, 0),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < options.length; i++) ...[
                        if (i > 0) const SizedBox(height: 5),
                        _MenuLine(
                          label: options[i],
                          showBottomDivider: i < options.length - 1,
                          onTap: () {
                            onSelected(options[i]);
                            _removeMenuOverlay();
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
    overlay.insert(_menuOverlay!);
  }

  Widget _buildFilterTrigger({
    required GlobalKey fieldKey,
    required String? selected,
    required String placeholder,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    final displayText =
        (selected != null && selected.isNotEmpty) ? selected : placeholder;
    final isPlaceholder = selected == null || selected.isEmpty;
    return Expanded(
      child: Opacity(
        opacity: enabled ? 1 : 0.45,
        child: Container(
          key: fieldKey,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 1, color: _kBorderStrong),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    displayText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isPlaceholder ? _kMuted : Colors.black,
                      fontSize: 10,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: enabled ? Colors.black87 : _kMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasPrimary = _selectedPrimary != null && _selectedPrimary!.isNotEmpty;
    final detailOptions = hasPrimary
        ? (contactInquiryDetailMap[_selectedPrimary!] ?? const ['기타'])
        : const <String>[];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFilterTrigger(
          fieldKey: _typeFieldKey,
          selected: _selectedPrimary,
          placeholder: '문의 유형 선택',
          onTap: () => _showAnchoredMenu(
            anchorKey: _typeFieldKey,
            options: contactInquiryPrimaryTypes,
            onSelected: (v) {
              setState(() {
                _selectedPrimary = v;
                _selectedDetail = null;
              });
            },
          ),
        ),
        const SizedBox(width: 10),
        _buildFilterTrigger(
          fieldKey: _detailFieldKey,
          selected: _selectedDetail,
          placeholder: '상세 유형 선택',
          enabled: hasPrimary,
          onTap: () => _showAnchoredMenu(
            anchorKey: _detailFieldKey,
            options: detailOptions,
            onSelected: (v) => setState(() => _selectedDetail = v),
          ),
        ),
      ],
    );
  }
}

class _MenuLine extends StatelessWidget {
  const _MenuLine({
    required this.label,
    required this.showBottomDivider,
    required this.onTap,
  });

  final String label;
  final bool showBottomDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(bottom: 5),
        decoration: BoxDecoration(
          border: showBottomDivider
              ? const Border(
                  bottom: BorderSide(
                    width: 0.3,
                    color: Color(0x7FD2D2D2),
                  ),
                )
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: _kInquiryMenuItemStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
