import 'package:flutter/material.dart';

import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../data/models/qa/qa_inquiry_model.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../shopping/widgets/supply_add_expand_block.dart';
import '../models/qa_inquiry_draft.dart';
import 'qa_inquiry_type_badge.dart';

class QaDetailProductCard extends StatefulWidget {
  const QaDetailProductCard({
    super.key,
    required this.inquiry,
    this.fallbackImageUrl,
  });

  final QaInquiry inquiry;
  final String? fallbackImageUrl;

  @override
  State<QaDetailProductCard> createState() => _QaDetailProductCardState();
}

class _QaDetailProductCardState extends State<QaDetailProductCard> {
  final Set<String> _expanded = {};

  static const String _noto = 'Noto Sans KR';

  List<QaInquiryCardItem> _itemsOf(QaInquiry root) {
    final subjectIt = (root.subjectItSubject ?? '').trim();
    final parsed = QaInquiryDraft.parseCardItems(root.wrContent);
    if (parsed.isNotEmpty) {
      // 예전 vendorLabel이 '보미한의원'으로 저장한 카드 → 품목(it_subject) 원문으로 보정
      if (subjectIt.isEmpty) return parsed;
      return [
        for (final item in parsed)
          (item.isHerbal &&
                  ((item.vendor ?? '').trim().isEmpty ||
                      (item.vendor ?? '').trim() == '보미한의원'))
              ? QaInquiryCardItem(
                  name: item.name,
                  vendor: subjectIt,
                  imageUrl: item.imageUrl,
                  price: item.price,
                  qty: item.qty,
                  optionText: item.optionText,
                  showOptions: item.showOptions,
                  isHerbal: item.isHerbal,
                  extras: item.extras,
                )
              : item,
      ];
    }

    final name = (root.subjectProductName ?? '').trim();
    if (name.isEmpty) return const [];
    return [
      QaInquiryCardItem(
        name: name,
        vendor: QaInquiryDraft.vendorLabel(
          brandName: root.subjectBrandName,
          itSubject: root.subjectItSubject,
        ),
        imageUrl: (root.subjectImageUrl ?? '').trim().isNotEmpty
            ? root.subjectImageUrl
            : widget.fallbackImageUrl,
        price: root.subjectPrice,
        optionText: root.subjectOptionText,
        showOptions: (root.subjectTabLabel ?? '') != '찜한상품',
        isHerbal: QaInquiryDraft.isHerbalProduct(null, root.subjectItSubject),
      ),
    ];
  }

  String _orderIdOf(QaInquiry root) {
    final fromSubject = (root.subjectOrderId ?? '').trim();
    if (fromSubject.isNotEmpty) return fromSubject;
    final card = QaInquiryDraft.decodeCardMap(root.wrContent);
    return (card?['od']?.toString() ?? '').trim();
  }

  String _optionLine(QaInquiryCardItem item) {
    if (!item.showOptions) return '';
    final parts = <String>['수량 ${item.qty}'];
    final raw = (item.optionText ?? '').trim();
    if (raw.isNotEmpty) {
      parts.addAll(
        raw
            .split(RegExp(r'\s*[|ㅣ/]\s*'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty && !e.startsWith('수량')),
      );
    }
    return parts.join(' · ');
  }

  List<_VendorGroup> _groups(List<QaInquiryCardItem> items) {
    final map = <String, List<QaInquiryCardItem>>{};
    final order = <String>[];
    for (final item in items) {
      final vendor = (item.vendor ?? '').trim();
      if (!map.containsKey(vendor)) {
        order.add(vendor);
        map[vendor] = [];
      }
      map[vendor]!.add(item);
    }
    return [
      for (final vendor in order)
        _VendorGroup(vendor: vendor, items: map[vendor]!),
    ];
  }

  List<_VendorGroup> _displayableVendorGroups(List<_VendorGroup> groups) {
    return groups.where((g) => g.vendor.isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final root = widget.inquiry;
    final badge = root.inquiryTypeBadgeKey.trim();
    final items = _itemsOf(root);
    final card = QaInquiryDraft.decodeCardMap(root.wrContent);
    final orderId = _orderIdOf(root);
    final tab = (root.subjectTabLabel ?? card?['tab']?.toString() ?? '').trim();
    final showOrder = orderId.isNotEmpty ||
        tab == '주문/배송' ||
        tab == '취소/교환/반품';

    if (items.isEmpty && badge.isEmpty) return const SizedBox.shrink();

    final groups = _groups(items);
    final vendorGroups = _displayableVendorGroups(groups);
    // 업체명은 배지(상태) 아래 업체 바에 표시 (장바구니/찜 · 주문 · 비대면 · 일반 동일)
    final showVendorBar = vendorGroups.isNotEmpty;
    final count = items.fold<int>(
      0,
      (sum, item) => sum + 1 + item.extras.length,
    );

    return Container(
      width: double.infinity,
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: Color(0xFFE5E5E5)),
          borderRadius: BorderRadius.circular(healthDp(context, 16)),
        ),
        shadows: const [
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(healthDp(context, 16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: healthDp(context, 12),
                vertical: healthDp(context, 10),
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAFA),
                border: Border(
                  bottom: BorderSide(color: Color(0xFFF5F5F5)),
                ),
              ),
              child: Row(
                children: [
                  if (badge.isNotEmpty) QaInquiryTypeBadge(type: badge),
                  if (showOrder && orderId.isNotEmpty) ...[
                    SizedBox(width: healthDp(context, 8)),
                    Expanded(
                      child: Text(
                        '주문번호 $orderId',
                        style: TextStyle(
                          color: const Color(0xFF737373),
                          fontSize: healthSp(context, 11),
                          fontFamily: _noto,
                          fontWeight: FontWeight.w400,
                          height: 1.45,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ] else
                    const Spacer(),
                  if (count > 0)
                    Text(
                      '총 $count개 상품',
                      style: TextStyle(
                        color: const Color(0xFFA1A1A1),
                        fontSize: healthSp(context, 10),
                        fontFamily: _noto,
                        fontWeight: FontWeight.w400,
                        height: 1.6,
                      ),
                    ),
                ],
              ),
            ),
            for (var gi = 0; gi < groups.length; gi++)
              _buildVendorGroup(
                context,
                groups[gi],
                showVendorBar: showVendorBar,
                showBottomBorder: gi < groups.length - 1,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVendorGroup(
    BuildContext context,
    _VendorGroup group, {
    required bool showVendorBar,
    required bool showBottomBorder,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        border: showBottomBorder
            ? const Border(bottom: BorderSide(color: Color(0xFFF5F5F5)))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showVendorBar && group.vendor.isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: healthDp(context, 12),
                vertical: healthDp(context, 6),
              ),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAFA),
              ),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      group.vendor,
                      style: TextStyle(
                        color: const Color(0xFF737373),
                        fontSize: healthSp(context, 10),
                        fontFamily: _noto,
                        fontWeight: FontWeight.w400,
                        height: 1.6,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (group.items.any((e) => e.isHerbal)) ...[
                    SizedBox(width: healthDp(context, 6)),
                    const _HerbalBadge(),
                  ],
                ],
              ),
            ),
          for (var i = 0; i < group.items.length; i++)
            _buildProductBlock(
              context,
              group.items[i],
              showDivider: i < group.items.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _buildProductBlock(
    BuildContext context,
    QaInquiryCardItem item, {
    required bool showDivider,
  }) {
    final key = '${item.name}|${item.imageUrl}|${item.price}';
    final expanded = _expanded.contains(key);
    final title = item.extras.isNotEmpty
        ? '${item.name} 외 ${item.extras.length}건'
        : item.name;
    final option = _optionLine(item);
    final imageUrl = (item.imageUrl ?? '').trim();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 12),
        vertical: healthDp(context, 10),
      ),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: Color(0xFFF5F5F5)))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(healthDp(context, 6)),
                child: Container(
                  width: healthDp(context, 48),
                  height: healthDp(context, 48),
                  color: const Color(0xFFF5F5F5),
                  child: imageUrl.isNotEmpty
                      ? Image.network(
                          ImageUrlHelper.getImageUrl(imageUrl),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.image_outlined,
                            size: healthDp(context, 20),
                          ),
                        )
                      : Icon(
                          Icons.image_outlined,
                          size: healthDp(context, 20),
                        ),
                ),
              ),
              SizedBox(width: healthDp(context, 10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: const Color(0xFF171717),
                        fontSize: healthSp(context, 12),
                        fontFamily: _noto,
                        fontWeight: FontWeight.w400,
                        height: 1.33,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (option.isNotEmpty) ...[
                      SizedBox(height: healthDp(context, 2)),
                      Text(
                        option,
                        style: TextStyle(
                          color: const Color(0xFF737373),
                          fontSize: healthSp(context, 10),
                          fontFamily: _noto,
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (item.price != null) ...[
                      SizedBox(height: healthDp(context, 4)),
                      Text(
                        '${PriceFormatter.format(item.price)}원',
                        style: TextStyle(
                          color: const Color(0xFF171717),
                          fontSize: healthSp(context, 12),
                          fontFamily: _noto,
                          fontWeight: FontWeight.w400,
                          height: 1.17,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (item.extras.isNotEmpty) ...[
            SizedBox(height: healthDp(context, 8)),
            SupplyAddExpandBlock(
              count: item.extras.length,
              expanded: expanded,
              onToggle: () => setState(() {
                if (expanded) {
                  _expanded.remove(key);
                } else {
                  _expanded.add(key);
                }
              }),
              children: [
                for (var i = 0; i < item.extras.length; i++)
                  SupplyAddReadOnlyRow(
                    name: item.extras[i].name,
                    optionLine: _optionLine(item.extras[i]),
                    price: item.extras[i].price,
                    imageUrl: item.extras[i].imageUrl,
                    showDivider: i < item.extras.length - 1,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _VendorGroup {
  _VendorGroup({required this.vendor, required this.items});
  final String vendor;
  final List<QaInquiryCardItem> items;
}

class _HerbalBadge extends StatelessWidget {
  const _HerbalBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 6)),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 0.5),
            color: const Color(0xFFFF5A8D),
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 4)),
        ),
      ),
      child: Text(
        '한의약품',
        style: TextStyle(
          color: const Color(0xFFFF5A8D),
          fontSize: healthSp(context, 8),
          fontFamily: 'Noto Sans KR',
          fontWeight: FontWeight.w400,
          height: 1.25,
        ),
      ),
    );
  }
}
