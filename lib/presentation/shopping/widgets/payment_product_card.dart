import 'package:flutter/material.dart';

import '../../../core/utils/price_formatter.dart';
import '../../../data/models/cart/cart_item_model.dart';
import '../../../data/models/cart/cart_line_group.dart';
import '../../../data/models/delivery/delivery_model.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../user/delivery/widgets/order_item_subject_groups.dart';
import 'cart_add_group_card.dart';
import 'cart_group_general_card.dart';
import 'get_cartImage.dart';

const _kGmarketSans = 'Gmarket Sans TTF';
const _kPink = Color(0xFFFF5A8D);
const _kMuted = Color(0xFF898686);
const _kInk = Color(0xFF1A1A1E);
const _kOption = Color(0xFF898383);
const _kBorder = Color(0x7FD2D2D2);
const _kDivider = Color(0xFFEFEFEF);

/// 주문 상품 → 결제/완료 UI용 CartItem
List<CartItem> cartItemsFromOrderItems(
  List<OrderItem> products, {
  String odId = '',
}) {
  return products
      .map(
        (p) => CartItem.fromJson({
          ...p.toJson(),
          'od_id': odId,
          'ct_id': p.ctId,
          'it_id': p.itId,
          'it_name': p.itName,
          'it_subject': p.itSubject,
          'it_kind': p.itKind,
          'ct_option': p.ctOption ?? '',
          'ct_qty': p.ctQty,
          'ct_price': p.ctPrice > 0 ? p.ctPrice : p.totalPrice,
          'io_price': p.ioPrice,
          'io_id': p.ioId,
          'io_type': p.ioType,
          'ct_kind': p.ctKind ?? p.itKind ?? 'general',
          'parent': p.parent ?? '',
          'parent_it_id': p.parent ?? '',
          'image_url': p.imageUrl,
          'ct_status': p.ctStatus ?? '',
        }),
      )
      .toList(growable: false);
}

/// 비대면 결제 — 결제 예정 목록 (예약시간 + 본품/추가상품 그룹)
class PaymentProductCard extends StatelessWidget {
  const PaymentProductCard({
    super.key,
    required this.cartItems,
    this.reservationDate,
    this.reservationTime,
    this.title = '결제 예정 목록',
    this.showHeader = true,
    this.showReservationBanner = true,
    this.showSameReservationHint = true,
  });

  final List<CartItem> cartItems;
  final DateTime? reservationDate;
  final String? reservationTime;
  final String title;
  final bool showHeader;
  final bool showReservationBanner;
  final bool showSameReservationHint;

  @override
  Widget build(BuildContext context) {
    final groups = cartGroupsForTab(cartItems, prescriptionTab: true);
    // 처방 그룹이 없으면 전체 그룹으로 표시 (결제 화면 진입 데이터 호환)
    final displayGroups = groups.isNotEmpty
        ? groups
        : CartLineGroup.groupItems(cartItems)
            .where((g) => !g.parent.isSupplyAdd)
            .toList();
    final totalCount = displayGroups.fold<int>(
      0,
      (sum, g) => sum + g.allItems.length,
    );
    final reservationBanner =
        showReservationBanner ? _reservationBannerText() : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: _kInk,
                  fontSize: healthSp(context, 16),
                  fontFamily: _kGmarketSans,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -1.44,
                ),
              ),
              SizedBox(width: healthDp(context, 10)),
              Text(
                '총 $totalCount개',
                style: TextStyle(
                  color: _kMuted,
                  fontSize: healthSp(context, 12),
                  fontFamily: _kGmarketSans,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
          if (reservationBanner != null) ...[
            SizedBox(height: healthDp(context, 10)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                horizontal: healthDp(context, 14),
                vertical: healthDp(context, 10),
              ),
              decoration: ShapeDecoration(
                color: const Color(0x7FF1F1F1),
                shape: RoundedRectangleBorder(
                  side: const BorderSide(width: 0.5, color: Color(0x33D2D2D2)),
                  borderRadius: BorderRadius.circular(healthDp(context, 8)),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '전화진료 예약시간 :',
                    style: TextStyle(
                      color: _kMuted,
                      fontSize: healthSp(context, 10),
                      fontFamily: _kGmarketSans,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(width: healthDp(context, 5)),
                  Expanded(
                    child: Text(
                      reservationBanner,
                      style: TextStyle(
                        color: _kPink,
                        fontSize: healthSp(context, 10),
                        fontFamily: _kGmarketSans,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: healthDp(context, 10)),
          Container(
            width: double.infinity,
            height: healthDp(context, 1),
            color: _kDivider,
          ),
          SizedBox(height: healthDp(context, 10)),
        ],
        for (var i = 0; i < displayGroups.length; i++) ...[
          if (i > 0) ...[
            SizedBox(height: healthDp(context, 10)),
            Container(
              width: double.infinity,
              height: 0.5,
              color: _kBorder,
            ),
            SizedBox(height: healthDp(context, 10)),
          ],
          CartAddGroupCard(
            group: displayGroups[i],
            selectedItems: const {},
            supplyInteractive: false,
            showBundleTotal: false,
            showSameReservationHint: showSameReservationHint,
            onToggleSelect: (_, __) {},
            buildParentOrMainCard: (item, {required isChild, footer}) =>
                _PaymentParentBlock(item: item, footer: footer),
          ),
        ],
      ],
    );
  }

  String? _reservationBannerText() {
    final fromBooking = _formatReservationBanner(
      reservationDate,
      reservationTime,
    );
    if (fromBooking != null) return fromBooking;

    for (final item in cartItems) {
      final text = _formatReservationBanner(
        item.reservationDate,
        item.reservationTime,
      );
      if (text != null) return text;
    }
    return null;
  }

  static String? _formatReservationBanner(DateTime? date, String? timeRaw) {
    final t = (timeRaw ?? '').trim();
    if (date == null && t.isEmpty) return null;

    final dateText = date == null
        ? ''
        : '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}(${_weekdayKor(date.weekday)})';

    final timeText = _formatReservationTimeRange(t);
    if (dateText.isNotEmpty && timeText.isNotEmpty) {
      return '$dateText, $timeText';
    }
    if (dateText.isNotEmpty) return dateText;
    return timeText.isEmpty ? null : timeText;
  }

  static String _formatReservationTimeRange(String time) {
    final trimmed = time.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.contains('~')) return trimmed;
    final parts = trimmed.split(':');
    if (parts.length != 2) return trimmed;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final end = DateTime(2000, 1, 1, h, m).add(const Duration(minutes: 30));
    final endText =
        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    return '$trimmed ~$endText';
  }

  static String _weekdayKor(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return '월';
      case DateTime.tuesday:
        return '화';
      case DateTime.wednesday:
        return '수';
      case DateTime.thursday:
        return '목';
      case DateTime.friday:
        return '금';
      case DateTime.saturday:
        return '토';
      case DateTime.sunday:
        return '일';
      default:
        return '-';
    }
  }
}

/// 일반상품 결제/완료 — 하나의 카드 안에 업체별 섹션
class PaymentGeneralProductCard extends StatelessWidget {
  const PaymentGeneralProductCard({
    super.key,
    required this.cartItems,
    this.title = '결제 예정 목록',
    this.showHeader = true,
    this.showOuterCard = true,
    this.showFooterNote = true,
    this.footerNote = '주문자 정보로 주문 관련 정보가 문자와 이메일로 발송됩니다.',
  });

  final List<CartItem> cartItems;
  final String title;
  final bool showHeader;
  final bool showOuterCard;
  final bool showFooterNote;
  final String footerNote;

  @override
  Widget build(BuildContext context) {
    final groups = cartGroupsForTab(cartItems, prescriptionTab: false);
    final displayGroups = groups.isNotEmpty
        ? groups
        : CartLineGroup.groupItems(cartItems)
            .where((g) => !g.parent.isSupplyAdd)
            .toList();
    final vendors = groupCartByVendor(displayGroups);
    final totalCount = displayGroups.fold<int>(
      0,
      (sum, g) => sum + g.allItems.length,
    );

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) ...[
          Text(
            '$title ($totalCount)',
            style: TextStyle(
              color: _kInk,
              fontSize: healthSp(context, 16),
              fontFamily: _kGmarketSans,
              fontWeight: FontWeight.w500,
              letterSpacing: -1.44,
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
        ],
        for (var i = 0; i < vendors.length; i++) ...[
          if (i > 0) ...[
            SizedBox(height: healthDp(context, 10)),
            Container(
              width: double.infinity,
              height: 0.5,
              color: _kBorder,
            ),
            SizedBox(height: healthDp(context, 10)),
          ],
          _PaymentVendorSection(
            vendorName: vendors[i].key,
            items: vendors[i]
                .value
                .expand((g) => g.allItems)
                .toList(growable: false),
          ),
        ],
        if (showFooterNote && footerNote.trim().isNotEmpty) ...[
          SizedBox(height: healthDp(context, 10)),
          Text(
            footerNote,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _kMuted,
              fontSize: healthSp(context, 10),
              fontFamily: _kGmarketSans,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ],
    );

    if (!showOuterCard) return body;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 14),
        vertical: healthDp(context, 20),
      ),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: _kBorder),
          borderRadius: BorderRadius.circular(healthDp(context, 15)),
        ),
      ),
      child: body,
    );
  }
}

class _PaymentVendorSection extends StatelessWidget {
  const _PaymentVendorSection({
    required this.vendorName,
    required this.items,
  });

  final String vendorName;
  final List<CartItem> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  vendorName.isEmpty ? '판매자' : vendorName,
                  style: TextStyle(
                    color: _kMuted,
                    fontSize: healthSp(context, 12),
                    fontFamily: _kGmarketSans,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: healthDp(context, 10)),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) SizedBox(height: healthDp(context, 10)),
          _PaymentParentBlock(item: items[i]),
        ],
      ],
    );
  }
}

class _PaymentParentBlock extends StatelessWidget {
  const _PaymentParentBlock({
    required this.item,
    this.footer,
  });

  final CartItem item;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final thumb = healthDp(context, 72);
    final optionParts = filterOptionPartsAgainstTitle(
      title: item.itName.trim(),
      rawOption: item.ctOption.trim(),
    );
    final qtyOptionLine = optionParts.isEmpty
        ? '수량: ${item.ctQty}'
        : '수량: ${item.ctQty} ㅣ ${optionParts.join(' ㅣ ')}';
    final titleStyle = TextStyle(
      color: _kInk,
      fontSize: healthSp(context, 14),
      fontFamily: _kGmarketSans,
      fontWeight: FontWeight.w500,
      letterSpacing: -1.26,
    );
    final optionStyle = TextStyle(
      color: _kOption,
      fontSize: healthSp(context, 10),
      fontFamily: _kGmarketSans,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.90,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CartItemThumbnail(
                item: item,
                size: thumb,
                borderRadius: BorderRadius.circular(healthDp(context, 4)),
              ),
              SizedBox(width: healthDp(context, 10)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OrderItemTitleOptionBlock(
                      title: item.itName,
                      qtyOptionLine: qtyOptionLine,
                      titleStyle: titleStyle,
                      optionStyle: optionStyle,
                    ),
                    SizedBox(height: healthDp(context, 5)),
                    Text(
                      '${PriceFormatter.format(item.lineAmount)}원',
                      style: TextStyle(
                        color: _kInk,
                        fontSize: healthSp(context, 14),
                        fontFamily: _kGmarketSans,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (footer != null) footer!,
      ],
    );
  }
}
