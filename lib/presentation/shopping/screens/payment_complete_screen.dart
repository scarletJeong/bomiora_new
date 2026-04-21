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
                : _buildContent(_order!),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadOrder,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(OrderDetailModel order) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(27, 20, 27, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('주문상품'),
          const SizedBox(height: 10),
          ...order.products.map(_productCard),
          const SizedBox(height: 10),
          const Divider(height: 20, color: _border),
          _sectionTitle('주문자'),
          const SizedBox(height: 10),
          _plainLine(order.ordererName),
          _plainLine(order.ordererPhone),
          _plainLine(order.ordererEmail),
          const SizedBox(height: 10),
          const Divider(height: 20, color: _border),
          Row(
            children: [
              Expanded(child: _sectionTitle('배송지')),
              InkWell(
                onTap: _openDeliveryAddressChange,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    '배송지 변경',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFFF5A8D),
                      fontSize: 12,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _plainLine(order.recipientAddress),
          if (order.recipientAddressDetail.isNotEmpty)
            _plainLine(order.recipientAddressDetail, color: _muted),
          _plainLine(order.recipientPhone),
          if ((order.deliveryMessage ?? '').isNotEmpty)
            _plainLine(order.deliveryMessage!, color: _muted),
          const SizedBox(height: 10),
          const Divider(height: 20, color: _border),
          _sectionTitle('결제 금액'),
          const SizedBox(height: 10),
          _priceRow('구매금액', '${PriceFormatter.format(order.productPrice)} 원'),
          _priceRow(
            '할인금액',
            order.discountAmount <= 0
                ? '${PriceFormatter.format(order.discountAmount)} 원'
                : '-${PriceFormatter.format(order.discountAmount)} 원',
          ),
          _priceRow('배송비', '${PriceFormatter.format(order.deliveryFee)} 원'),
          const Divider(height: 20, color: _border),
          _priceRow('총 결제비용', '${PriceFormatter.format(order.totalPrice)}원',
              strong: true),
          const Divider(height: 20, color: _border),
          const SizedBox(height: 10),
          _sectionTitle('주문 결제정보'),
          const SizedBox(height: 10),
          _infoCard(order),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _actionButton(
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
              const SizedBox(width: 20),
              Expanded(
                child: _actionButton(
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

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: _pink,
        fontSize: 14,
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _plainLine(String text, {Color color = _ink}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }

  Widget _productCard(OrderItem item) {
    final imageUrl =
        ImageUrlHelper.normalizeThumbnailUrl(item.imageUrl, item.itId);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: _border),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: ShapeDecoration(
              color: Colors.grey.shade100,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageUrl == null
                ? const Icon(Icons.image, color: Colors.grey)
                : Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.image, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.itName,
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '수량: ${item.ctQty}${(item.ctOption ?? '').trim().isNotEmpty ? ' / ${item.ctOption!.trim()}' : ''}',
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 10,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${PriceFormatter.format(item.totalPrice)}원',
                  style: const TextStyle(
                    color: _ink,
                    fontSize: 14,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if ((item.ctOption ?? '').contains('~'))
                  const SizedBox(height: 5),
                if ((item.ctOption ?? '').contains('~'))
                  Text(
                    '전화진료 예약시간 : ${item.ctOption}',
                    style: const TextStyle(
                      color: _pink,
                      fontSize: 9,
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

  Widget _priceRow(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: strong ? _pink : _ink,
              fontSize: strong ? 14 : 12,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: strong ? FontWeight.w700 : FontWeight.w300,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: strong ? _ink : _ink,
              fontSize: strong ? 16 : 12,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: strong ? FontWeight.w700 : FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(OrderDetailModel order) {
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
        label: '주문번호',
        value: Row(
          children: [
            Expanded(child: Text(order.odId)),
            if (showCardReceipt) ...[
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _openCardPurchaseReceipt(order),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    '구매 영수증',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFFFF5A8D),
                      fontSize: 12,
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
      _infoTableRow(label: '주문상태', value: Text(order.displayStatus)),
      _infoTableRow(label: '결제일시', value: Text(order.orderDate)),
      _infoTableRow(
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
                const SizedBox(width: 8),
                _copyChip(displayDepositAccount),
              ],
            ],
          ),
        ),
      );
    }

    rows.add(
      _infoTableRow(
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
          label: '입금안내',
          value: Text(order.deliveryMessage!),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: _border),
          borderRadius: BorderRadius.circular(7),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(84),
          1: FlexColumnWidth(),
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

  TableRow _infoTableRow({
    required String label,
    required Widget value,
  }) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Text(
            label,
            style: const TextStyle(
              color: _ink,
              fontSize: 12,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: DefaultTextStyle(
            style: const TextStyle(
              color: _ink,
              fontSize: 12,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
            ),
            child: value,
          ),
        ),
      ],
    );
  }

  Widget _copyChip(String copyText) {
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFD2D2D2), width: 0.5),
          borderRadius: BorderRadius.circular(6),
          color: Colors.white,
        ),
        child: const Text(
          '복사',
          style: TextStyle(
            color: _muted,
            fontSize: 11,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _actionButton(String label,
      {required VoidCallback onTap, required bool filled}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: filled ? _pink : Colors.white,
          shape: RoundedRectangleBorder(
            side: filled
                ? BorderSide.none
                : const BorderSide(width: 0.5, color: Color(0xFFD2D2D2)),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: filled ? Colors.white : _muted,
            fontSize: 16,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
