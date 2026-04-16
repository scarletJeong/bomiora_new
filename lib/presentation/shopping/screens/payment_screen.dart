import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../common/widgets/app_bar.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../user/myPage/screens/address_management_screen.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../data/models/cart/cart_item_model.dart';
import '../../../data/models/coupon/coupon_model.dart';
import '../../../data/services/address_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/coupon_service.dart';
import '../../../data/services/point_service.dart';

class PaymentScreen extends StatefulWidget {
  final List<CartItem> cartItems;
  final int shippingCost;
  final String sourceTitle;

  const PaymentScreen({
    super.key,
    required this.cartItems,
    required this.shippingCost,
    required this.sourceTitle,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const _pink = Color(0xFFFF5A8D);
  static const _ink = Color(0xFF1A1A1A);
  static const _muted = Color(0xFF898686);
  static const _border = Color(0xFFD2D2D2);

  final GlobalKey _couponDropdownAnchorKey = GlobalKey();
  final TextEditingController _pointController = TextEditingController();
  final TextEditingController _addressNameController = TextEditingController();
  final TextEditingController _receiverController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _zipController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _detailAddressController = TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  bool _loading = true;
  bool _useDefaultAddress = true;
  bool _syncingPoint = false;
  bool _useAllPoints = false;
  bool _useEscrow = false;

  int _paymentMethodIndex = 0; // 0 card, 1 bank transfer, 2 virtual account
  int _myPoint = 0;
  int _usedPoint = 0;

  List<Coupon> _applicableCoupons = [];
  List<Coupon> _selectedCoupons = [];
  Map<String, dynamic>? _defaultAddress;

  @override
  void initState() {
    super.initState();
    _pointController.addListener(_onPointChanged);
    _loadData();
  }

  @override
  void dispose() {
    _pointController.removeListener(_onPointChanged);
    _pointController.dispose();
    _addressNameController.dispose();
    _receiverController.dispose();
    _phoneController.dispose();
    _zipController.dispose();
    _addressController.dispose();
    _detailAddressController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = await AuthService.getUser();
    if (user == null || user.id.isEmpty) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    final results = await Future.wait([
      AddressService.getAddressList(user.id),
      CouponService.getAvailableCoupons(user.id),
      PointService.getUserPoint(user.id),
    ]);

    final addresses = results[0] as List<Map<String, dynamic>>;
    final coupons = results[1] as List<Coupon>;
    final point = (results[2] as int?) ?? 0;
    final defaultAddress = addresses.firstWhere(
      (e) => e['adDefault'] == 1,
      orElse: () => addresses.isNotEmpty ? addresses.first : <String, dynamic>{},
    );

    if (!mounted) return;
    setState(() {
      _defaultAddress = defaultAddress.isEmpty ? null : defaultAddress;
      _myPoint = point;
      _applicableCoupons = coupons.where(_isCouponApplicable).toList();
      _loading = false;
    });
    _applyAddressMode();
  }

  bool _isCouponApplicable(Coupon coupon) {
    if (!coupon.isAvailable) return false;
    if (_purchaseAmount < coupon.minimum) return false;
    switch (coupon.method) {
      case 0:
        return widget.cartItems.any((item) => item.itId == coupon.target);
      case 1:
        if (coupon.target.trim().isEmpty) return true;
        final target = coupon.target.trim().toLowerCase();
        return widget.cartItems.any((item) {
          final source = '${item.productType ?? ''} ${item.itSubject ?? ''} ${item.itName}'
              .toLowerCase();
          return source.contains(target);
        });
      case 3:
        return widget.shippingCost > 0;
      default:
        return true;
    }
  }

  int get _purchaseAmount =>
      widget.cartItems.fold(0, (sum, item) => sum + item.ctPrice);

  int _discountForCoupon(Coupon coupon) {
    final base = coupon.method == 3 ? widget.shippingCost : _purchaseAmount;
    if (base <= 0 || base < coupon.minimum) return 0;
    if (coupon.maximum > 0) {
      final discount = (base * coupon.price / 100).floor();
      return discount > coupon.maximum ? coupon.maximum : discount;
    }
    return coupon.price > base ? base : coupon.price;
  }

  int get _couponDiscount =>
      _selectedCoupons.fold(0, (sum, c) => sum + _discountForCoupon(c));

  int get _maxUsablePoint {
    final available = _purchaseAmount + widget.shippingCost - _couponDiscount;
    if (available <= 0) return 0;
    return _myPoint > available ? available : _myPoint;
  }

  int get _pointDiscount => _usedPoint > _maxUsablePoint ? _maxUsablePoint : _usedPoint;

  int get _finalAmount {
    final amount =
        _purchaseAmount + widget.shippingCost - _couponDiscount - _pointDiscount;
    return amount < 0 ? 0 : amount;
  }

  int get _expectedPoint => (_finalAmount * 0.01).floor();

  void _onPointChanged() {
    if (_syncingPoint) return;
    final raw = _pointController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final value = int.tryParse(raw) ?? 0;
    final snapped = (value ~/ 100) * 100;
    final safe = snapped > _maxUsablePoint ? _maxUsablePoint : snapped;
    if (safe != _usedPoint || raw != safe.toString()) {
      _syncingPoint = true;
      _pointController.value = TextEditingValue(
        text: safe == 0 ? '' : '$safe',
        selection: TextSelection.collapsed(offset: safe == 0 ? 0 : '$safe'.length),
      );
      _syncingPoint = false;
      setState(() {
        _usedPoint = safe;
        _useAllPoints = _usedPoint > 0 && _usedPoint == _maxUsablePoint;
      });
    }
  }

  void _applyAddressMode() {
    if (_useDefaultAddress) {
      final ad = _defaultAddress;
      _addressNameController.text = _safe(ad?['adSubject']);
      _receiverController.text = _safe(ad?['adName']);
      _phoneController.text = _safe(ad?['adHp']);
      _zipController.text = _safe(ad?['adZip1']);
      _addressController.text = [
        _safe(ad?['adAddr1']),
        _safe(ad?['adAddr2']),
        _safe(ad?['adAddr3']),
      ].where((e) => e.isNotEmpty).join(' ');
      _detailAddressController.clear();
      _memoController.text = _safe(ad?['adMemo']);
      return;
    }

    _addressNameController.clear();
    _receiverController.clear();
    _phoneController.clear();
    _zipController.clear();
    _addressController.clear();
    _detailAddressController.clear();
    _memoController.clear();
  }

  String _safe(dynamic value) => (value ?? '').toString().trim();

  Future<void> _openCouponMenu() async {
    final renderBox =
        _couponDropdownAnchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final position = RelativeRect.fromRect(
      Rect.fromPoints(
        renderBox.localToGlobal(Offset.zero, ancestor: overlay),
        renderBox.localToGlobal(
          renderBox.size.bottomRight(Offset.zero),
          ancestor: overlay,
        ),
      ),
      Offset.zero & overlay.size,
    );

    final candidates = _applicableCoupons
        .where((c) => !_selectedCoupons.any((s) => s.no == c.no))
        .toList();
    if (candidates.isEmpty) return;

    final picked = await showMenu<Coupon>(
      context: context,
      position: position,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: candidates
          .map((c) => PopupMenuItem<Coupon>(
                value: c,
                child: Text('${c.subject} (${c.discountText})'),
              ))
          .toList(),
    );

    if (!mounted || picked == null) return;
    if (_selectedCoupons.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('쿠폰은 최대 2개까지 선택할 수 있습니다.')),
      );
      return;
    }
    setState(() {
      _selectedCoupons.add(picked);
      if (_usedPoint > _maxUsablePoint) {
        _usedPoint = _maxUsablePoint;
        _pointController.text = _usedPoint == 0 ? '' : '$_usedPoint';
      }
    });
  }

  Future<void> _openAddressManagement() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddressManagementScreen()),
    );
    if (!mounted) return;
    setState(() => _loading = true);
    await _loadData();
  }

  String _itemImageUrl(CartItem item) {
    final normalized =
        ImageUrlHelper.normalizeThumbnailUrl(item.imageUrl, item.itId);
    final fallback =
        normalized ?? '${ImageUrlHelper.imageBaseUrl}/data/item/${item.itId}/no_img.png';
    if (kIsWeb &&
        (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') &&
        fallback.startsWith('http')) {
      return '${ApiClient.baseUrl}/api/proxy/image?url=${Uri.encodeComponent(fallback)}';
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: const HealthAppBar(title: '주문/결제', centerTitle: true),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(27, 20, 27, 20),
                child: DefaultTextStyle.merge(
                  style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    _title('배송지'),
                    const SizedBox(height: 10),
                    const Text(
                      '배송지 선택',
                      style: TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 12,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _modeButton('기본배송지', _useDefaultAddress, () {
                            setState(() {
                              _useDefaultAddress = true;
                              _applyAddressMode();
                            });
                          }),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _modeButton('신규배송지', !_useDefaultAddress, () {
                            setState(() {
                              _useDefaultAddress = false;
                              _applyAddressMode();
                            });
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),                    
                    _inputField('배송지명', _addressNameController, '배송지명을 입력해 주세요.'),
                    _inputField('수령인*', _receiverController, '수령인의 이름을 입력해 주세요.'),
                    _inputField('핸드폰 번호*', _phoneController, '\'-\'없이 기입해주세요.'),
                    _inputField('우편번호*', _zipController, '\'주소 검색\' 클릭'),
                    _inputField('주소*', _addressController, '\'주소 검색\'을 통하여 입력됩니다.'),
                    _inputField('상세 주소*', _detailAddressController, '상세 주소를 입력해 주세요.'),
                    _inputField('배송 요청 사항', _memoController, '배송 관련 요청 사항이 있으시면 입력해 주세요.'),
                    const SizedBox(height: 2),
                    const Text(
                      '※ 영업일 기준 오후 2시 이전 처방완료 시 당일 발송',
                      style: TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 12,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Divider( height: 1, thickness: 1.5, color: Color(0xFFD9D9D9)),
                    const SizedBox(height: 12),
                    _title('결제 예정 목록'),
                    const SizedBox(height: 10),
                    ...widget.cartItems.map(_orderCard),
                    const SizedBox(height: 20),

                    const Divider( height: 1, thickness: 1.5, color: Color(0xFFD9D9D9)),
                    const SizedBox(height: 12),
                    _title('쿠폰 선택'),
                    const SizedBox(height: 8),
                    _couponDropdown(),
                    const SizedBox(height: 8),
                    ..._selectedCoupons.map((c) => _selectedCouponRow(c)),
                    Text(
                      '선택 ${_selectedCoupons.length}/2',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 10,
                        fontFamily: 'Gmarket Sans TTF',
                      ),
                    ),
                    const SizedBox(height: 20),

                    const Divider( height: 1, thickness: 1.5, color: Color(0xFFD9D9D9)),
                    const SizedBox(height: 12),
                    _title('포인트'),
                    const SizedBox(height: 8),
                    _summaryRow('보유 포인트', '${PointService.formatPoint(_myPoint)} 점'),
                    _summaryRow('최대 사용 가능 포인트', '${PointService.formatPoint(_maxUsablePoint)} 점'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 137.08,
                            child: Text(
                              '포인트 사용 (100 점 단위)',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 11.70,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ),
                          Container(
                            width: 80,
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            clipBehavior: Clip.antiAlias,
                            decoration: ShapeDecoration(
                              shape: RoundedRectangleBorder(
                                side: const BorderSide(
                                  width: 1,
                                  color: Color(0xFFD2D2D2),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _pointController,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 12,
                                      fontFamily: 'Gmarket Sans TTF',
                                      fontWeight: FontWeight.w300,
                                    ),
                                    decoration: const InputDecoration(
                                      isCollapsed: true,
                                      border: InputBorder.none,
                                      hintText: '0',
                                      hintStyle: TextStyle(
                                        color: Color(0xFF898686),
                                        fontSize: 12,
                                        fontFamily: 'Gmarket Sans TTF',
                                        fontWeight: FontWeight.w300,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  '점',
                                  style: TextStyle(
                                    color: Color(0xFF898686),
                                    fontSize: 12,
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Theme(
                          data: Theme.of(context).copyWith(
                            checkboxTheme: CheckboxThemeData(
                              side: const BorderSide(
                                color: Color(0xFFE3E3E3),
                                width: 0.8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                          child: Checkbox(
                            value: _useAllPoints,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity:
                                const VisualDensity(horizontal: -4, vertical: -4),
                            activeColor: _pink,
                            onChanged: (checked) {
                              final all = checked ?? false;
                              setState(() {
                                _useAllPoints = all;
                                _usedPoint = all ? _maxUsablePoint : 0;
                                _pointController.text =
                                    _usedPoint == 0 ? '' : '$_usedPoint';
                              });
                            },
                          ),
                        ),
                        const Text(
                          '모두 사용',
                          style: TextStyle(
                            color: _ink,
                            fontSize: 11.7,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    const Divider( height: 1, thickness: 1.5, color: Color(0xFFD9D9D9)),
                    const SizedBox(height: 12),
                    _title('결제 금액'),
                    const SizedBox(height: 8),
                    _summaryRow('구매금액', '${PriceFormatter.format(_purchaseAmount)} 원'),
                    _summaryRow('쿠폰할인', '-${PriceFormatter.format(_couponDiscount)} 원'),
                    _summaryRow('포인트할인', '-${PriceFormatter.format(_pointDiscount)} 원'),
                    _summaryRow('배송비', '${PriceFormatter.format(widget.shippingCost)} 원'),
                    const SizedBox(height: 6),
                    _strongRow('총 결제비용', '${PriceFormatter.format(_finalAmount)}원'),
                    const SizedBox(height: 2),
                    const Text(
                      '*상품별 포인트 설정 기준 예상 적립',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 8,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    _summaryRow('예상 적립 포인트', '${PointService.formatPoint(_expectedPoint)} 점'),
                    const SizedBox(height: 20),
                    const Divider( height: 1, thickness: 1.5, color: Color(0xFFD9D9D9)),
                    const SizedBox(height: 12),
                    _title('결제 수단'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _methodButton('신용카드', 0)),
                        const SizedBox(width: 10),
                        Expanded(child: _methodButton('계좌이체', 1)),
                        const SizedBox(width: 10),
                        Expanded(child: _methodButton('가상계좌', 2)),
                      ],
                    ),
                    if (_paymentMethodIndex == 1 || _paymentMethodIndex == 2) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: _escrowToggle('에스크로 사용', _useEscrow, () {
                              setState(() => _useEscrow = true);
                            }),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _escrowToggle('에스크로 미사용', !_useEscrow, () {
                              setState(() => _useEscrow = false);
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _escrowNotice(),
                    ],
                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 40,
                      child: ElevatedButton(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('결제 기능 준비 중입니다.')),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _pink,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('결제하기'),
                      ),
                    ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _title(String text) => Text(
        text,
        style: const TextStyle(
          color: _pink,
          fontSize: 14,
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        ),
      );

  Widget _modeButton(String text, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0x0CFF5A8D) : Colors.white,
          border: Border.all(color: selected ? _pink : _border),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: selected ? _pink : _muted,
            fontSize: 12,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _inputField(
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: _ink,
              fontSize: 12,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 40,
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                hintText: hint,
                hintStyle: const TextStyle(
                  color: _muted,
                  fontSize: 12,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w300,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _border),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderCard(CartItem item) {
    final reservationLine = _buildReservationLine(item);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(
            width: 1,
            color: Color(0x7FD2D2D2),
          ),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    _itemImageUrl(item),
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 72,
                      height: 72,
                      color: Colors.grey.shade200,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.itName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 14,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      _buildOrderMetaRow(item),
                      const SizedBox(height: 5),
                      Text(
                        '${PriceFormatter.format(item.ctPrice)}원',
                        style: const TextStyle(
                          color: _ink,
                          fontSize: 14,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        height: 0.5,
                        color: const Color(0xFFD2D2D2),
                      ),
                      if (reservationLine != null) ...[
                        const SizedBox(height: 8),
                        reservationLine,
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderMetaRow(CartItem item) {
    final optionParts = item.ctOption
        .split(' / ')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final tokens = <String>['수량: ${item.ctQty}', ...optionParts];
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 5,
      runSpacing: 4,
      children: [
        for (int i = 0; i < tokens.length; i++) ...[
          Text(
            tokens[i],
            style: const TextStyle(
              color: Color(0xFF898686),
              fontSize: 10,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          if (i < tokens.length - 1)
            Container(
              width: 0.5,
              height: 10,
              color: const Color(0xFF898686),
            ),
        ],
      ],
    );
  }

  Widget? _buildReservationLine(CartItem item) {
    final d = item.reservationDate;
    final t = item.reservationTime?.trim() ?? '';
    if (d == null && t.isEmpty) return null;

    final dateText = d != null
        ? '${d.year.toString().padLeft(4, '0')}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}(${_weekdayKor(d.weekday)})'
        : '-';
    final reservationText = t.isNotEmpty ? '$dateText, $t' : dateText;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Text(
          '전화진료 예약시간 :',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: 9,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
            letterSpacing: -0.81,
          ),
        ),
        const SizedBox(width: 2),
        Expanded(
          child: Text(
            reservationText,
            style: const TextStyle(
              color: Color(0xFFFF5A8D),
              fontSize: 9,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
              letterSpacing: -0.81,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _weekdayKor(int weekday) {
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

  Widget _couponDropdown() {
    return Container(
      key: _couponDropdownAnchorKey,
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: _border),
          borderRadius: BorderRadius.circular(10),
        ),
        shadows: const [
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 4,
            offset: Offset(0, 0),
            spreadRadius: 0,
          ),
        ],
      ),
      alignment: Alignment.center,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _openCouponMenu,
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedCoupons.isEmpty ? '선택' : '${_selectedCoupons.length}개 선택됨',
                style: TextStyle(
                  color: _selectedCoupons.isEmpty ? _muted : _ink,
                  fontSize: 16,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _selectedCouponRow(Coupon coupon) {
    final typeLabel = _couponTypeLabel(coupon);
    final safeSubject = coupon.subject.trim();
    final safeTarget = coupon.target.trim();
    final safeDiscount = coupon.discountText.trim();
    final line1 = safeSubject.isNotEmpty
        ? safeSubject
        : (safeTarget.isNotEmpty ? safeTarget : '쿠폰명 없음');
    final line2 = safeDiscount.isNotEmpty ? safeDiscount : '할인 정보 없음';

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                typeLabel,
                style: const TextStyle(
                  color: Color(0xFFFF5A8D),
                  fontSize: 8,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line1,
                      style: const TextStyle(
                        color: Color(0xFF898686),
                        fontSize: 10,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      line2,
                      style: const TextStyle(
                        color: Color(0xFF898686),
                        fontSize: 10,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedCoupons.removeWhere((c) => c.no == coupon.no);
                  if (_usedPoint > _maxUsablePoint) {
                    _usedPoint = _maxUsablePoint;
                    _pointController.text = _usedPoint == 0 ? '' : '$_usedPoint';
                  }
                });
              },
              child: const Text(
                '삭제',
                style: TextStyle(
                  color: _muted,
                  fontSize: 10,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _couponTypeLabel(Coupon coupon) {
    switch (coupon.method) {
      case 0:
        return '[상품 쿠폰]';
      case 1:
        return '[카테고리 쿠폰]';
      case 3:
        return '[배송비 쿠폰]';
      default:
        return '[쿠폰]';
    }
  }

  Widget _summaryRow(String left, String right) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(left),
          Text(right),
        ],
      ),
    );
  }

  Widget _strongRow(String left, String right) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          left,
          style: const TextStyle(
            color: _pink,
            fontSize: 14,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          right,
          style: const TextStyle(
            color: _ink,
            fontSize: 16,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _methodButton(String label, int index) {
    final selected = _paymentMethodIndex == index;
    return InkWell(
      onTap: () => setState(() => _paymentMethodIndex = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 90,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? _pink : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? _pink : _border,
            width: selected ? 1 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : _ink,
            fontSize: 12,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: selected ? FontWeight.w700 : FontWeight.w300,
          ),
        ),
      ),
    );
  }

  Widget _escrowToggle(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0x0CFF5A8D) : Colors.white,
          border: Border.all(color: selected ? _pink : _border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _pink : _ink,
            fontSize: 12,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _escrowNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: const Color(0xFFF1F1F1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 65.95,
            height: 65.95,
            decoration: const BoxDecoration(color: Colors.white),
            child: const Icon(Icons.verified_user_outlined, color: _muted),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '구매안전 (에스크로) 서비스',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 10,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  '고객님은 안전거래를 위해 현금 등으로 결제시 저희 쇼핑몰에 가입한 KCP의 구매안전서비스를 이용하실 수 있습니다.\n계좌이체 또는 가상계좌 등 현금 거래에만 해당(에스크로 결제를 선택했을경우에만 해당)되며, 신용카드로 구매하는 거래에는 해당되지 않습니다.',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 8,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                    height: 1.88,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

