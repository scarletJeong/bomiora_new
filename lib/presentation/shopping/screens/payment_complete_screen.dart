import 'package:flutter/material.dart';

import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../data/models/delivery/delivery_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/delivery_service.dart' as delivery;
import '../../common/widgets/app_bar.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';

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
          _sectionTitle('주문자'),
          const SizedBox(height: 10),
          _plainLine(order.ordererName),
          _plainLine(order.ordererPhone),
          _plainLine(order.ordererEmail),
          const SizedBox(height: 10),
          const Divider(height: 20, color: _border),
          _sectionTitle('배송지'),
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
              '할인금액', '-${PriceFormatter.format(order.discountAmount)} 원'),
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
    final accountNo = accountInfo.contains('/')
        ? accountInfo.split('/')[1].trim()
        : accountInfo;

    return Container(
      width: double.infinity,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: _border),
          borderRadius: BorderRadius.circular(7),
        ),
      ),
      child: Column(
        children: [
          _infoRow(
            isVirtualAccount ? '가상계좌번호' : '주문번호',
            isVirtualAccount && accountNo.isNotEmpty ? accountNo : order.odId,
          ),
          _infoRow('주문상태', order.displayStatus),
          _infoRow('결제일시', order.orderDate),
          _infoRow(
              '결제방식',
              isVirtualAccount
                  ? order.paymentMethod
                  : '${order.paymentMethod}${order.paymentMethodDetail ?? ''}'),
          _infoRow('결제금액', '${PriceFormatter.format(order.totalPrice)}원'),
          if (isVirtualAccount && accountInfo.isNotEmpty)
            _infoRow('입금계좌', accountInfo),
          if ((order.paymentMethod.contains('가상계좌') ||
                  order.paymentMethod.contains('무통장')) &&
              order.deliveryMessage != null &&
              order.deliveryMessage!.isNotEmpty)
            _infoRow('입금안내', order.deliveryMessage!),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(width: 1, color: _border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 72,
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
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _ink,
                fontSize: 12,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ],
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
