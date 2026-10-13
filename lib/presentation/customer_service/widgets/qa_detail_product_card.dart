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

  static const String _font = 'Gmarket Sans TTF';

  List<QaInquiryCardItem> _itemsOf(QaInquiry root) {
    final parsed = QaInquiryDraft.parseCardItems(root.wrContent);
    if (parsed.isNotEmpty) return parsed;

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
        isHerbal: false,
      ),
    ];
  }

  String _orderIdOf(QaInquiry root) {
    final fromSubject = (root.subjectOrderId ?? '').trim();
    if (fromSubject.isNotEmpty) return fromSubject;
    final card = QaInquiryDraft.decodeCardMap(root.wrContent);
    return (card?['od']?.toString() ?? '').trim();
  }

  List<String> _optionParts(QaInquiryCardItem item) {
    if (!item.showOptions) return const [];
    final raw = (item.optionText ?? '').trim();
    final tokens = raw.isEmpty
        ? <String>[]
        : raw
            .split(RegExp(r'\s*[|ㅣ/]\s*|\u001E'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
    final hasQty = tokens.any((e) => e.startsWith('수량'));
    return [
      if (!hasQty && item.qty > 0) '수량: ${item.qty}',
      ...tokens,
    ];
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
      padding: EdgeInsets.symmetric(vertical: healthDp(context, 14)),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1),
            color: const Color(0x7FD2D2D2),
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 16)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
            child: Row(
              children: [
                if (badge.isNotEmpty) QaInquiryTypeBadge(type: badge),
                if (showOrder && orderId.isNotEmpty) ...[
                  SizedBox(width: healthDp(context, 4)),
                  Expanded(
                    child: Text(
                      '주문번호 $orderId',
                      style: TextStyle(
                        color: const Color(0xFF898986),
                        fontSize: healthSp(context, 10),
                        fontFamily: _font,
                        fontWeight: FontWeight.w500,
                        letterSpacing: healthSp(context, -0.90),
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
                      color: const Color(0xFF898986),
                      fontSize: healthSp(context, 10),
                      fontFamily: _font,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          for (final label in _clinicLabels(items)) ...[
            SizedBox(height: healthDp(context, 10)),
            _clinicBar(context, label),
          ],
          if (groups.isNotEmpty) SizedBox(height: healthDp(context, 14)),
          for (var gi = 0; gi < groups.length; gi++) ...[
            if (gi > 0) SizedBox(height: healthDp(context, 14)),
            _buildVendorGroup(
              context,
              groups[gi],
              showVendorBar: showVendorBar,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVendorGroup(
    BuildContext context,
    _VendorGroup group, {
    required bool showVendorBar,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showVendorBar &&
            group.vendor.isNotEmpty &&
            !group.items.every((e) => e.isHerbal))
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(healthDp(context, 10)),
            decoration: ShapeDecoration(
              color: const Color(0xFFFCFCFB),
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  width: healthDp(context, 1),
                  color: const Color(0x7FD2D2D2),
                ),
              ),
            ),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    group.vendor,
                    style: TextStyle(
                      color: const Color(0xFF898986),
                      fontSize: healthSp(context, 12),
                      fontFamily: _font,
                      fontWeight: FontWeight.w500,
                      letterSpacing: healthSp(context, -0.48),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (group.items.any((e) => e.isHerbal)) ...[
                  SizedBox(width: healthDp(context, 4)),
                  const _HerbalBadge(),
                ],
              ],
            ),
          ),
        for (var i = 0; i < group.items.length; i++) ...[
          SizedBox(height: healthDp(context, 10)),
          _buildProductBlock(context, group.items[i]),
        ],
      ],
    );
  }

  Widget _buildProductBlock(BuildContext context, QaInquiryCardItem item) {
    final key = '${item.name}|${item.imageUrl}|${item.price}';
    final expanded = _expanded.contains(key);
    final parts = _optionParts(item);
    final imageUrl = (item.imageUrl ?? '').trim();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(healthDp(context, 8)),
                child: Container(
                  width: healthDp(context, 56),
                  height: healthDp(context, 56),
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
                      item.name,
                      style: TextStyle(
                        color: const Color(0xFF1A1A1E),
                        fontSize: healthSp(context, 14),
                        fontFamily: _font,
                        fontWeight: FontWeight.w500,
                        letterSpacing: healthSp(context, -0.56),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (parts.isNotEmpty) ...[
                      SizedBox(height: healthDp(context, 4)),
                      _OptionLine(parts: parts),
                    ],
                    if (item.price != null)
                      Padding(
                        padding: EdgeInsets.only(top: healthDp(context, 8)),
                        child: Text(
                          '${PriceFormatter.format(item.price)}원',
                          style: TextStyle(
                            color: const Color(0xFF1A1A1E),
                            fontSize: healthSp(context, 14),
                            fontFamily: _font,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (item.extras.isNotEmpty) ...[
            SizedBox(height: healthDp(context, 14)),
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
                    vendorLabel: (item.extras[i].vendor ?? '').trim().isNotEmpty
                        ? item.extras[i].vendor
                        : item.vendor,
                    optionParts: _optionParts(item.extras[i]),
                    price: item.extras[i].price,
                    imageUrl: item.extras[i].imageUrl,
                    showDivider: i < item.extras.length - 1,
                    thumbBase: 48,
                    nameFontBase: 12,
                    optionFontBase: 10,
                    priceFontBase: 12,
                    nameLetterSpacingBase: -0.48,
                    optionLetterSpacingBase: -0.60,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<String> _clinicLabels(List<QaInquiryCardItem> items) {
    final labels = <String>[];
    for (final item in items) {
      if (!item.isHerbal) continue;
      final label = (item.vendor ?? '').trim();
      if (label.isEmpty || labels.contains(label)) continue;
      labels.add(label);
    }
    return labels;
  }

  Widget _clinicBar(BuildContext context, String label) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 10)),
      decoration: ShapeDecoration(
        color: const Color(0xFFFCFCFB),
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1),
            color: const Color(0x7FD2D2D2),
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: const Color(0xFF898986),
              fontSize: healthSp(context, 12),
              fontFamily: _font,
              fontWeight: FontWeight.w500,
              letterSpacing: healthSp(context, -0.48),
            ),
          ),
          SizedBox(width: healthDp(context, 4)),
          const _HerbalBadge(),
        ],
      ),
    );
  }
}

class _OptionLine extends StatelessWidget {
  const _OptionLine({required this.parts});

  final List<String> parts;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: healthDp(context, 4),
      runSpacing: healthDp(context, 4),
      children: [
        for (var i = 0; i < parts.length; i++)
          Text(
            parts[i],
            style: TextStyle(
              color: i == parts.length - 1 && parts.length > 1
                  ? const Color(0xFF898686)
                  : const Color(0xFF898383),
              fontSize: healthSp(context, 10),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
              letterSpacing: healthSp(context, -0.90),
            ),
          ),
      ],
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
      padding: EdgeInsets.all(healthDp(context, 4)),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 0.8),
            color: const Color(0xFFFF5A8D),
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 50)),
        ),
      ),
      child: Text(
        '한의약품',
        style: TextStyle(
          color: const Color(0xFFFF5A8D),
          fontSize: healthSp(context, 10),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
          letterSpacing: healthSp(context, -0.40),
        ),
      ),
    );
  }
}
