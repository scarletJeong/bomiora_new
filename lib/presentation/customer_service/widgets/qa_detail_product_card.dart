import 'package:flutter/material.dart';

import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../data/models/qa/qa_inquiry_model.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../shopping/widgets/supply_add_expand_block.dart';
import '../models/qa_inquiry_draft.dart';
import '../models/qa_maker_resolver.dart';
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
  static const String _font = 'Gmarket Sans TTF';

  final Map<String, String> _makerById = {};

  @override
  void initState() {
    super.initState();
    _loadMakers();
  }

  Future<void> _loadMakers() async {
    final ids = <String>{};
    void collect(QaInquiryCardItem item) {
      if ((item.maker ?? '').trim().isNotEmpty) return;
      final id = QaMakerResolver.itIdFromImage(item.imageUrl);
      if (id != null) ids.add(id);
      for (final extra in item.extras) {
        collect(extra);
      }
    }

    for (final item in _itemsOf(widget.inquiry, applyResolved: false)) {
      collect(item);
    }
    if (ids.isEmpty) return;
    final labels = await QaMakerResolver.labelsFor(ids);
    if (!mounted || labels.isEmpty) return;
    setState(() => _makerById.addAll(labels));
  }

  List<QaInquiryCardItem> _itemsOf(
    QaInquiry root, {
    bool applyResolved = true,
  }) {
    final parsed = QaInquiryDraft.parseCardItems(root.wrContent);
    final base = parsed.isNotEmpty
        ? parsed
        : () {
            final name = (root.subjectProductName ?? '').trim();
            if (name.isEmpty) return const <QaInquiryCardItem>[];
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
          }();
    if (!applyResolved || _makerById.isEmpty) return base;
    return base.map(_applyMaker).toList();
  }

  QaInquiryCardItem _applyMaker(QaInquiryCardItem item) {
    final existing = (item.maker ?? '').trim();
    final id = QaMakerResolver.itIdFromImage(item.imageUrl);
    final resolved = existing.isNotEmpty ? existing : (id == null ? '' : (_makerById[id] ?? ''));
    return QaInquiryCardItem(
      name: item.name,
      vendor: item.vendor,
      maker: resolved.isEmpty ? null : resolved,
      imageUrl: item.imageUrl,
      price: item.price,
      qty: item.qty,
      optionText: item.optionText,
      showOptions: item.showOptions,
      isHerbal: item.isHerbal,
      extras: item.extras.map(_applyMaker).toList(),
    );
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
              showMakers: _distinctMakers(items).length > 1,
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
    required bool showMakers,
  }) {
    final clusters = showMakers ? _makerClusters(group.items) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showVendorBar &&
            !showMakers &&
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
        for (final cluster in clusters ??
            [_MakerCluster(maker: '', items: group.items)]) ...[
          if (showMakers && cluster.maker.isNotEmpty)
            QaManufacturerBar(name: cluster.maker),
          for (var i = 0; i < cluster.items.length; i++) ...[
            SizedBox(height: healthDp(context, 10)),
            _buildProductBlock(context, cluster.items[i]),
          ],
        ],
      ],
    );
  }

  Widget _buildProductBlock(BuildContext context, QaInquiryCardItem item) {
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

  List<String> _distinctMakers(List<QaInquiryCardItem> items) {
    final names = <String>[];
    for (final item in items) {
      final maker = (item.maker ?? '').trim();
      if (maker.isEmpty || names.contains(maker)) continue;
      names.add(maker);
    }
    return names;
  }

  List<_MakerCluster> _makerClusters(List<QaInquiryCardItem> items) {
    final order = <String>[];
    final map = <String, List<QaInquiryCardItem>>{};
    for (final item in items) {
      final key = (item.maker ?? '').trim();
      if (!map.containsKey(key)) {
        order.add(key);
        map[key] = [];
      }
      map[key]!.add(item);
    }
    return [
      for (final key in order) _MakerCluster(maker: key, items: map[key]!),
    ];
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

class _MakerCluster {
  _MakerCluster({required this.maker, required this.items});
  final String maker;
  final List<QaInquiryCardItem> items;
}

/// 제조사가 서로 다를 때 상품 위에 붙는 이름 바.
class QaManufacturerBar extends StatelessWidget {
  const QaManufacturerBar({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 12),
        vertical: healthDp(context, 6),
      ),
      color: const Color(0xFFFAFAFA),
      child: Text(
        name,
        style: TextStyle(
          color: const Color(0xFF737373),
          fontSize: healthSp(context, 10),
          fontFamily: 'Noto Sans KR',
          fontWeight: FontWeight.w400,
          height: 1.60,
        ),
      ),
    );
  }
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
