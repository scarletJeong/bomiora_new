import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../data/models/delivery/delivery_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/delivery_service.dart' as delivery;
import '../../common/widgets/app_bar.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../user/delivery/widgets/delivery_address_change_popup.dart';

class PaymentCompleteScreen extends StatefulWidget {
  const PaymentCompleteScreen({
    super.key,
    required this.orderId,
  });

  final String orderId;

  @override
  State<PaymentCompleteScreen> createState() => _PaymentCompleteScreenState();
}

class _PaymentCompleteScreenState extends State<PaymentCompleteScreen> {
  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _ink = Color(0xFF1A1A1A);
  static const Color _muted = Color(0xFF898686);
  static const Color _border = Color(0x7FD2D2D2);

  bool _loading = true;
  String? _error;
  OrderDetailModel? _order;

  @override
  void initState() {
    super.initState();
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = await AuthService.getUser();
      if (user == null || user.id.trim().isEmpty) {
        setState(() {
          _error = '로그인 정보가 없습니다.';
          _loading = false;
        });
        return;
      }

      final result = await delivery.OrderService.getOrderDetail(
        odId: widget.orderId,
        mbId: user.id,
      );

      if (result['success'] != true || result['order'] is! OrderDetailModel) {
        setState(() {
          _error = (result['message'] ?? '주문 정보를 불러오지 못했습니다.').toString();
          _loading = false;
        });
        return;
      }

      setState(() {
        _order = result['order'] as OrderDetailModel;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '주문 정보를 불러오는 중 오류가 발생했습니다: $e';
        _loading = false;
      });
    }
  }

  Future<void> _openDeliveryAddressChange() async {
    final result = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '배송지 변경',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, _, __) {
        return Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(color: Colors.black.withValues(alpha: 0.35)),
              ),
            ),
            DeliveryAddressChangePopup(orderId: widget.orderId),
          ],
        );
      },
    );
    if (result == true && mounted) {
      await _loadOrder();
    }
  }

  Future<void> _openCardPurchaseReceipt(OrderDetailModel order) async {
    final url = (order.cardReceiptUrl ?? '').trim();
    if (url.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('영수증 URL이 아직 준비되지 않았습니다. (백엔드 응답 필드 확인 필요)')),
      );
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('영수증 URL 형식이 올바르지 않습니다.')),
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('영수증 페이지를 열 수 없습니다.')),
      );
    }
  }

  bool _isCardPayment(OrderDetailModel order) {
    final m = order.paymentMethod.toLowerCase();
    return m.contains('카드') || m.contains('card') || m.contains('신용');
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: const HealthAppBar(title: '주문 완료', centerTitle: true),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildError()
                : _buildContent(context, _order!),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(healthDp(context, 24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            SizedBox(height: healthDp(context, 12)),
            ElevatedButton(
              onPressed: _loadOrder,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, OrderDetailModel order) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        healthDp(context, 27),
        healthDp(context, 20),
        healthDp(context, 27),
        healthDp(context, 20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(context, '주문상품'),
          SizedBox(height: healthDp(context, 10)),
          ...order.products.map((e) => _productCard(context, e)),
          SizedBox(height: healthDp(context, 10)),
          Divider(height: healthDp(context, 20), color: _border),
          _sectionTitle(context, '주문자'),
          SizedBox(height: healthDp(context, 10)),
          _plainLine(context, order.ordererName),
          _plainLine(context, order.ordererPhone),
          _plainLine(context, order.ordererEmail),
          SizedBox(height: healthDp(context, 10)),
          Divider(height: healthDp(context, 20), color: _border),
          Row(
            children: [
              Expanded(child: _sectionTitle(context, '배송지')),
              InkWell(
                onTap: _openDeliveryAddressChange,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: healthDp(context, 6),
                    vertical: healthDp(context, 4),
                  ),
                  child: Text(
                    '배송지 변경',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFFFF5A8D),
                      fontSize: healthSp(context, 12),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: healthDp(context, 10)),
          _plainLine(context, order.recipientAddress),
          if (order.recipientAddressDetail.isNotEmpty)
            _plainLine(context, order.recipientAddressDetail, color: _muted),
          _plainLine(context, order.recipientPhone),
          if ((order.deliveryMessage ?? '').isNotEmpty)
            _plainLine(context, order.deliveryMessage!, color: _muted),
          SizedBox(height: healthDp(context, 10)),
          Divider(height: healthDp(context, 20), color: _border),
          _sectionTitle(context, '결제 금액'),
          SizedBox(height: healthDp(context, 10)),
          _priceRow(context, '구매금액',
              '${PriceFormatter.format(order.productPrice)} 원'),
          _priceRow(
            context,
            '할인금액',
            order.discountAmount <= 0
                ? '${PriceFormatter.format(order.discountAmount)} 원'
                : '-${PriceFormatter.format(order.discountAmount)} 원',
          ),
          _priceRow(context, '배송비',
              '${PriceFormatter.format(order.deliveryFee)} 원'),
          Divider(height: healthDp(context, 20), color: _border),
          _priceRow(context, '총 결제비용',
              '${PriceFormatter.format(order.totalPrice)}원',
              strong: true),
          Divider(height: healthDp(context, 20), color: _border),
          SizedBox(height: healthDp(context, 10)),
          _sectionTitle(context, '주문 결제정보'),
          SizedBox(height: healthDp(context, 10)),
          _infoCard(context, order),
          SizedBox(height: healthDp(context, 20)),
          Row(
            children: [
              Expanded(
                child: _actionButton(
                  context,
                  '주문내역',
                  onTap: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/order',
                      (route) => route.isFirst,
                    );
                  },
                  filled: false,
                ),
              ),
              SizedBox(width: healthDp(context, 20)),
              Expanded(
                child: _actionButton(
                  context,
                  '쇼핑하기',
                  onTap: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/home',
                      (route) => route.isFirst,
                    );
                  },
                  filled: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        color: _pink,
        fontSize: healthSp(context, 14),
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _plainLine(BuildContext context, String text, {Color color = _ink}) {
    return Padding(
      padding: EdgeInsets.only(bottom: healthDp(context, 6)),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: healthSp(context, 12),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }

  Widget _productCard(BuildContext context, OrderItem item) {
    final imageUrl =
        ImageUrlHelper.normalizeThumbnailUrl(item.imageUrl, item.itId);
    final thumb = healthDp(context, 72);
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: healthDp(context, 10)),
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 10),
        vertical: healthDp(context, 20),
      ),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(width: 1, color: _border),
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: thumb,
            height: thumb,
            decoration: ShapeDecoration(
              color: Colors.grey.shade100,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 4))),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl == null
                ? Icon(Icons.image, color: Colors.grey, size: healthDp(context, 28))
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        Icon(Icons.image, color: Colors.grey, size: healthDp(context, 28)),
                  ),
          ),
          SizedBox(width: healthDp(context, 20)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itName,
                  style: TextStyle(
                    color: _ink,
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: healthDp(context, 5)),
                Text(
                  '수량: ${item.ctQty}${(item.ctOption ?? '').trim().isNotEmpty ? ' / ${item.ctOption!.trim()}' : ''}',
                  style: TextStyle(
                    color: _muted,
                    fontSize: healthSp(context, 10),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: healthDp(context, 5)),
                Text(
                  '${PriceFormatter.format(item.totalPrice)}원',
                  style: TextStyle(
                    color: _ink,
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if ((item.ctOption ?? '').contains('~'))
                  SizedBox(height: healthDp(context, 5)),
                if ((item.ctOption ?? '').contains('~'))
                  Text(
                    '전화진료 예약시간 : ${item.ctOption}',
                    style: TextStyle(
                      color: _pink,
                      fontSize: healthSp(context, 9),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _priceRow(BuildContext context, String label, String value,
      {bool strong = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: healthDp(context, 8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: strong ? _pink : _ink,
              fontSize:
                  strong ? healthSp(context, 14) : healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: strong ? FontWeight.w700 : FontWeight.w300,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: strong ? _ink : _ink,
              fontSize:
                  strong ? healthSp(context, 16) : healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: strong ? FontWeight.w700 : FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(BuildContext context, OrderDetailModel order) {
    final isVirtualAccount = order.paymentMethod.contains('가상계좌') ||
        order.paymentMethod.contains('무통장');
    final accountInfo = (order.paymentMethodDetail ?? '').trim();
    final accountParts = accountInfo
        .split('/')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final bankName = accountParts.isNotEmpty ? accountParts[0] : '';
    final bankAccountNo = accountParts.length >= 2 ? accountParts[1] : '';
    final displayDepositAccount = [
      if (bankName.isNotEmpty) bankName,
      if (bankAccountNo.isNotEmpty) bankAccountNo,
    ].join(' ');
    final canCopyDepositAccount = isVirtualAccount && displayDepositAccount.isNotEmpty;
    final showCardReceipt = _isCardPayment(order);

    final rows = <TableRow>[
      _infoTableRow(
        context,
        label: '주문번호',
        value: Row(
          children: [
            Expanded(child: Text(order.odId)),
            if (showCardReceipt) ...[
              SizedBox(width: healthDp(context, 8)),
              InkWell(
                onTap: () => _openCardPurchaseReceipt(order),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: healthDp(context, 6),
                    vertical: healthDp(context, 4),
                  ),
                  child: Text(
                    '구매 영수증',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFFFF5A8D),
                      fontSize: healthSp(context, 12),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      _infoTableRow(context, label: '주문상태', value: Text(order.displayStatus)),
      _infoTableRow(context, label: '결제일시', value: Text(order.orderDate)),
      _infoTableRow(
        context,
        label: '결제방식',
        value: Text(
          isVirtualAccount
              ? order.paymentMethod
              : '${order.paymentMethod}${order.paymentMethodDetail ?? ''}',
        ),
      ),
    ];

    if (isVirtualAccount) {
      rows.add(
        _infoTableRow(
          context,
          label: '입금계좌',
          value: Row(
            children: [
              Expanded(
                child: Text(
                  displayDepositAccount.isNotEmpty
                      ? displayDepositAccount
                      : (accountInfo.isNotEmpty ? accountInfo : '-'),
                ),
              ),
              if (canCopyDepositAccount) ...[
                SizedBox(width: healthDp(context, 8)),
                _copyChip(context, displayDepositAccount),
              ],
            ],
          ),
        ),
      );
    }

    rows.add(
      _infoTableRow(
        context,
        label: '결제금액',
        value: Text('${PriceFormatter.format(order.totalPrice)}원'),
      ),
    );

    if ((order.paymentMethod.contains('가상계좌') ||
            order.paymentMethod.contains('무통장')) &&
        order.deliveryMessage != null &&
        order.deliveryMessage!.isNotEmpty) {
      rows.add(
        _infoTableRow(
          context,
          label: '입금안내',
          value: Text(order.deliveryMessage!),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(width: 1, color: _border),
          borderRadius: BorderRadius.circular(healthDp(context, 7)),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: {
          0: FixedColumnWidth(healthDp(context, 84)),
          1: const FlexColumnWidth(),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: const TableBorder(
          verticalInside: BorderSide(width: 1, color: Color(0xFFE3E3E3)),
          horizontalInside: BorderSide(width: 1, color: Color(0xFFE3E3E3)),
        ),
        children: rows,
      ),
    );
  }

  TableRow _infoTableRow(
    BuildContext context, {
    required String label,
    required Widget value,
  }) {
    final pad = EdgeInsets.symmetric(
      horizontal: healthDp(context, 10),
      vertical: healthDp(context, 10),
    );
    final cellStyle = TextStyle(
      color: _ink,
      fontSize: healthSp(context, 12),
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: FontWeight.w300,
    );
    return TableRow(
      children: [
        Padding(
          padding: pad,
          child: Text(
            label,
            style: cellStyle,
          ),
        ),
        Padding(
          padding: pad,
          child: DefaultTextStyle(
            style: cellStyle,
            child: value,
          ),
        ),
      ],
    );
  }

  Widget _copyChip(BuildContext context, String copyText) {
    return InkWell(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: copyText));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('입금계좌가 복사되었습니다.')),
        );
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 8),
          vertical: healthDp(context, 6),
        ),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD2D2D2), width: 0.5),
          borderRadius: BorderRadius.circular(healthDp(context, 6)),
          color: Colors.white,
        ),
        child: Text(
          '복사',
          style: TextStyle(
            color: _muted,
            fontSize: healthSp(context, 11),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
    BuildContext context,
    String label, {
    required VoidCallback onTap,
    required bool filled,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(healthDp(context, 10)),
      child: Container(
        height: healthDp(context, 40),
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: filled ? _pink : Colors.white,
          shape: RoundedRectangleBorder(
            side: filled
                ? BorderSide.none
                : BorderSide(width: 0.5, color: const Color(0xFFD2D2D2)),
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? Colors.white : _muted,
            fontSize: healthSp(context, 16),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
