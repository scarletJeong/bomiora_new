import 'package:flutter/material.dart';

import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/price_formatter.dart';
import '../../health/health_common/health_responsive_scale.dart';

const _kGmarketSans = 'Gmarket Sans TTF';
const _kPink = Color(0xFFFF5A8D);
const _kMuted = Color(0xFF898686);
const _kBorderSoft = Color(0x33FF5A8D);
const _kDivider = Color(0x26FF5A8D);
const _kInkAlt = Color(0xFF1A1A1E);
const _kMuted2 = Color(0xFF898383);

/// 추가상품(supply_add) 펼치기/접기 블록 — 장바구니·주문·문의 등 공통
///
/// [onToggle]이 null이면 항상 펼쳐진 상태(장바구니), 있으면 접기/펼치기 가능.
class SupplyAddExpandBlock extends StatelessWidget {
  const SupplyAddExpandBlock({
    super.key,
    required this.count,
    required this.children,
    this.expanded = true,
    this.onToggle,
    this.title,
    this.showSameReservationHint = false,
  });

  final int count;
  final List<Widget> children;
  final bool expanded;
  final VoidCallback? onToggle;
  final String? title;
  final bool showSameReservationHint;

  bool get _collapsible => onToggle != null;

  String _defaultTitle() {
    if (_collapsible) return '추가상품 $count개 포함';
    return '추가 상품 $count개';
  }

  @override
  Widget build(BuildContext context) {
    if (count <= 0 && children.isEmpty) return const SizedBox.shrink();

    final radius = healthDp(context, 8);
    final borderW = healthDp(context, 1.11);
    final headerTitle = title ?? _defaultTitle();

    Widget header = Container(
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 10),
        vertical: healthDp(context, 7),
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: _collapsible
            ? (expanded
                ? Border(
                    bottom: BorderSide(width: borderW, color: _kDivider),
                  )
                : null)
            : const Border(
                bottom: BorderSide(width: 1, color: _kDivider),
              ),
      ),
      child: Row(
        children: [
          Container(
            width: healthDp(context, _collapsible ? 5 : 6),
            height: healthDp(context, _collapsible ? 5 : 6),
            decoration: const BoxDecoration(
              color: _kPink,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: healthDp(context, 6)),
          Text(
            headerTitle,
            style: TextStyle(
              color: _kPink,
              fontSize: healthSp(context, _collapsible ? 12 : 10),
              fontFamily: _kGmarketSans,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
          ),
          if (!_collapsible) ...[
            SizedBox(width: healthDp(context, 6)),
            Expanded(
              child: Container(height: 0.5, color: _kBorderSoft),
            ),
            if (showSameReservationHint) ...[
              SizedBox(width: healthDp(context, 6)),
              Icon(
                Icons.schedule,
                size: healthSp(context, 10),
                color: _kMuted,
              ),
              SizedBox(width: healthDp(context, 3)),
              Text(
                '동일 예약',
                style: TextStyle(
                  color: _kMuted,
                  fontSize: healthSp(context, 9),
                  fontFamily: _kGmarketSans,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ],
          ],
          if (_collapsible) ...[
            const Spacer(),
            Text(
              expanded ? '접기' : '펼치기',
              style: TextStyle(
                color: _kPink,
                fontSize: healthSp(context, 10),
                fontFamily: _kGmarketSans,
                fontWeight: FontWeight.w500,
              ),
            ),
            Icon(
              expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: healthDp(context, 11),
              color: _kPink,
            ),
          ],
        ],
      ),
    );

    if (_collapsible) {
      header = InkWell(onTap: onToggle, child: header);
    }

    final showChildren = !_collapsible || expanded;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          width: _collapsible ? borderW : 1,
          color: _kBorderSoft,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius > 1 ? radius - 1 : radius),
        child: ColoredBox(
          color: Colors.white,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              header,
              if (showChildren) ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// 추가상품 read-only 한 줄 — 문의·주문 상세 등
class SupplyAddReadOnlyRow extends StatelessWidget {
  const SupplyAddReadOnlyRow({
    super.key,
    required this.name,
    this.optionLine,
    this.optionParts,
    this.price,
    this.imageUrl,
    this.vendorLabel,
    this.showDivider = true,
    this.thumbBase = 44,
    this.nameFontBase = 10,
    this.optionFontBase = 9,
    this.priceFontBase = 10,
    this.nameLetterSpacingBase = 0,
    this.optionLetterSpacingBase = 0,
  });

  final String name;
  final String? optionLine;
  final List<String>? optionParts;
  final int? price;
  final String? imageUrl;
  final String? vendorLabel;
  final bool showDivider;
  final double thumbBase;
  final double nameFontBase;
  final double optionFontBase;
  final double priceFontBase;
  final double nameLetterSpacingBase;
  final double optionLetterSpacingBase;

  @override
  Widget build(BuildContext context) {
    final url = (imageUrl ?? '').trim();
    final thumb = healthDp(context, thumbBase);
    final borderW = healthDp(context, 1.11);
    final parts = (optionParts ?? const <String>[])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final gap = healthDp(context, 4);
    final lines = <Widget>[];
    void addLine(Widget child) {
      if (lines.isNotEmpty) lines.add(SizedBox(height: gap));
      lines.add(child);
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 8),
        vertical: healthDp(context, 10),
      ),
      decoration: BoxDecoration(
        border: Border.all(width: borderW, color: const Color(0x1EFF5A8D)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(healthDp(context, 4)),
            child: Container(
              width: thumb,
              height: thumb,
              color: const Color(0xFFE8E8E8),
              child: url.isNotEmpty
                  ? Image.network(
                      ImageUrlHelper.getImageUrl(url),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.image_outlined,
                        color: Colors.grey.shade500,
                        size: healthDp(context, 18),
                      ),
                    )
                  : Icon(
                      Icons.image_outlined,
                      color: Colors.grey.shade500,
                      size: healthDp(context, 18),
                    ),
            ),
          ),
          SizedBox(width: healthDp(context, 8)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...() {
                  if ((vendorLabel ?? '').trim().isNotEmpty) {
                    addLine(
                      Text(
                        vendorLabel!.trim(),
                        style: TextStyle(
                          color: _kMuted,
                          fontSize: healthSp(context, 8),
                          fontFamily: _kGmarketSans,
                          fontWeight: FontWeight.w500,
                          letterSpacing: healthSp(context, -0.72),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }
                  addLine(
                    Text(
                      name,
                      style: TextStyle(
                        color: _kInkAlt,
                        fontSize: healthSp(context, nameFontBase),
                        fontFamily: _kGmarketSans,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                        letterSpacing: healthSp(context, nameLetterSpacingBase),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                  if (parts.isNotEmpty) {
                    addLine(
                      Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          for (final part in parts)
                            Text(
                              part,
                              style: TextStyle(
                                color: _kMuted2,
                                fontSize: healthSp(context, optionFontBase),
                                fontFamily: _kGmarketSans,
                                fontWeight: FontWeight.w500,
                                letterSpacing:
                                    healthSp(context, optionLetterSpacingBase),
                              ),
                            ),
                        ],
                      ),
                    );
                  } else if ((optionLine ?? '').trim().isNotEmpty) {
                    addLine(
                      Text(
                        optionLine!.trim(),
                        style: TextStyle(
                          color: _kMuted2,
                          fontSize: healthSp(context, optionFontBase),
                          fontFamily: _kGmarketSans,
                          fontWeight: FontWeight.w500,
                          height: 1.62,
                          letterSpacing:
                              healthSp(context, optionLetterSpacingBase),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }
                  if (price != null) {
                    addLine(
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '+${PriceFormatter.format(price)}원',
                          style: TextStyle(
                            color: _kInkAlt,
                            fontSize: healthSp(context, priceFontBase),
                            fontFamily: _kGmarketSans,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }
                  return lines;
                }(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
