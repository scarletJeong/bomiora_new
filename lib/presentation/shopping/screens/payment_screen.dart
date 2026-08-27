import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';

import '../../health/health_common/widgets/health_app_bar.dart';
import '../../common/widgets/dropdown_btn.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/daum_postcode_search_dialog.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../data/models/cart/cart_item_model.dart';
import '../../../data/models/coupon/coupon_model.dart';
import '../../../data/models/user/user_model.dart';
import '../../../data/services/address_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/coupon_service.dart';
import '../../../data/services/point_service.dart';
import '../../user/delivery/widgets/delivery_address_change_popup_ver2.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../widgets/payment_product_card.dart';
import '../widgets/prescription_booking_progress_bar.dart';
import 'kcp_pay_webview_screen.dart';

class PaymentPrefetchData {
  final List<Map<String, dynamic>> addresses;
  final List<Coupon> coupons;
  final int point;

  const PaymentPrefetchData({
    required this.addresses,
    required this.coupons,
    required this.point,
  });

  static Future<PaymentPrefetchData?> load(String mbId) async {
    final id = mbId.trim();
    if (id.isEmpty) return null;
    try {
      final results = await Future.wait([
        AddressService.getAddressList(id),
        CouponService.getAvailableCoupons(id),
        PointService.getUserPoint(id),
      ]);
      return PaymentPrefetchData(
        addresses: results[0] as List<Map<String, dynamic>>,
        coupons: results[1] as List<Coupon>,
        point: (results[2] as int?) ?? 0,
      );
    } catch (_) {
      return null;
    }
  }
}

class PaymentScreen extends StatefulWidget {
  final List<CartItem> cartItems;
  final int shippingCost;
  final String sourceTitle;
  final PaymentPrefetchData? prefetch;

  /// 비대면 진료(처방) 예약 플로우에서 진입한 결제 화면일 때 앱바 4단 프로그레스 표시.
  final bool showPrescriptionBookingProgress;

  /// 앞 단계에서 선택한 전화진료 예약일 (비대면 진료 결제).
  final DateTime? reservationDate;

  /// 앞 단계에서 선택한 예약 시작 시각 `HH:mm` (비대면 진료 결제).
  final String? reservationTime;

  const PaymentScreen({
    super.key,
    required this.cartItems,
    required this.shippingCost,
    required this.sourceTitle,
    this.prefetch,
    this.showPrescriptionBookingProgress = false,
    this.reservationDate,
    this.reservationTime,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  static const _pink = Color(0xFFFF5A8D);
  static const _muted = Color(0xFF898686);
  static const _border = Color(0xFFD2D2D2);
  static const _figmaPink = Color(0xFFFF5B8C);
  static const _figmaBrown = Color(0xFF584045);
  static const _figmaDark = Color(0xFF1A1B1F);

  static const _deliveryMemoPresets = <String>[
    '문 앞에 놓아주세요',
    '경비실에 맡겨주세요',
    '직접 받겠습니다',
    '배송 전 연락바랍니다',
    '부재 시 연락주세요',
  ];

  final TextEditingController _pointController = TextEditingController();
  final TextEditingController _addressNameController = TextEditingController();
  final TextEditingController _receiverController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _zipController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _detailAddressController =
      TextEditingController();
  final TextEditingController _memoController = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  bool _syncingPoint = false;
  bool _useEscrow = false;
  final ValueNotifier<double> _scrollProgress = ValueNotifier(0);

  int _paymentMethodIndex = 0; // 0 card, 1 bank transfer, 2 virtual account
  int _myPoint = 0;
  int _usedPoint = 0;
  static const int _minPayableAmount = 3000;

  List<Coupon> _applicableCoupons = [];
  List<Coupon> _selectedCoupons = [];
  Map<String, dynamic>? _defaultAddress;
  /// 기본 배송지 없을 때: 배송지명 칩 (집/회사/직접입력)
  String _addressLabelChip = '집';
  bool _saveAsDefault = false;
  bool _showCustomAddressName = false;

  @override
  void initState() {
    super.initState();
    _pointController.addListener(_onPointChanged);
    _loadData();
  }

  bool _handleBookingScrollNotification(ScrollNotification notification) {
    if (!widget.showPrescriptionBookingProgress) return false;
    if (notification.depth != 0) return false;
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is! ScrollUpdateNotification &&
        notification is! ScrollEndNotification) {
      return false;
    }
    final next = prescriptionBookingScrollProgress(notification.metrics);
    if ((next - _scrollProgress.value).abs() < 0.01) return false;
    _scrollProgress.value = next;
    return false;
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
    _scrollProgress.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = await AuthService.getUser();
    if (user == null || user.id.isEmpty) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    if (widget.prefetch != null) {
      _applyPrefetch(user, widget.prefetch!);
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
      orElse: () =>
          addresses.isNotEmpty ? addresses.first : <String, dynamic>{},
    );

    if (!mounted) return;
    setState(() {
      _defaultAddress = defaultAddress.isEmpty ? null : defaultAddress;
      _myPoint = point;
      _applicableCoupons = _couponPointDisabled
          ? []
          : coupons.where(_isCouponApplicable).toList();
      if (_couponPointDisabled) {
        _selectedCoupons = [];
        _usedPoint = 0;
        _pointController.clear();
      }
      _loading = false;
    });
    _applyAddressMode();
    // 기본 배송지 없으면 회원 성함/연락처 프리필
    if (_defaultAddress == null) {
      setState(() {
        if (_receiverController.text.trim().isEmpty) {
          _receiverController.text = user.name;
        }
        if (_phoneController.text.trim().isEmpty &&
            (user.phone ?? '').trim().isNotEmpty) {
          _phoneController.text =
              (user.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
        }
        _addressNameController.text = _addressLabelChip;
      });
    }
  }

  void _applyPrefetch(UserModel user, PaymentPrefetchData prefetch) {
    if (!mounted) return;
    final defaultAddress = prefetch.addresses.firstWhere(
      (e) => e['adDefault'] == 1,
      orElse: () =>
          prefetch.addresses.isNotEmpty
              ? prefetch.addresses.first
              : <String, dynamic>{},
    );
    setState(() {
      _defaultAddress = defaultAddress.isEmpty ? null : defaultAddress;
      _myPoint = prefetch.point;
      _applicableCoupons = _couponPointDisabled
          ? []
          : prefetch.coupons.where(_isCouponApplicable).toList();
      if (_couponPointDisabled) {
        _selectedCoupons = [];
        _usedPoint = 0;
        _pointController.clear();
      }
      _loading = false;
    });
    _applyAddressMode();
    if (_defaultAddress == null) {
      setState(() {
        if (_receiverController.text.trim().isEmpty) {
          _receiverController.text = user.name;
        }
        if (_phoneController.text.trim().isEmpty &&
            (user.phone ?? '').trim().isNotEmpty) {
          _phoneController.text =
              (user.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
        }
        _addressNameController.text = _addressLabelChip;
      });
    }
  }

  bool get _hasSavedAddress {
    final ad = _defaultAddress;
    if (ad == null) return false;
    final addr = [
      _safe(ad['adAddr1']),
      _safe(ad['adAddr2']),
      _safe(ad['adName']),
    ].any((e) => e.isNotEmpty);
    return addr;
  }

  bool _isCouponApplicable(Coupon coupon) {
    if (!coupon.isAvailable) return false;
    if (_couponPointDisabled) return false;
    if (_nonInfluencerAmount < coupon.minimum) return false;
    switch (coupon.method) {
      case 0:
        return widget.cartItems.any(
          (item) =>
              !_isInfluencerCartItem(item) &&
              item.itId == coupon.target,
        );
      case 1:
        if (coupon.target.trim().isEmpty) return _nonInfluencerAmount > 0;
        final target = coupon.target.trim().toLowerCase();
        return widget.cartItems.any((item) {
          if (_isInfluencerCartItem(item)) return false;
          final source =
              '${item.productType ?? ''} ${item.itSubject ?? ''} ${item.itName}'
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

  bool _isInfluencerCartItem(CartItem item) =>
      item.ctMbInf.trim().isNotEmpty;

  int get _nonInfluencerAmount => widget.cartItems
      .where((item) => !_isInfluencerCartItem(item))
      .fold<int>(0, (sum, item) => sum + item.ctPrice);

  bool get _hasInfluencerItems =>
      widget.cartItems.any(_isInfluencerCartItem);

  bool get _isInfluencerOnly =>
      widget.cartItems.isNotEmpty &&
      widget.cartItems.every(_isInfluencerCartItem);

  bool get _couponPointDisabled => _nonInfluencerAmount <= 0;

  String get _couponPointNotice {
    if (_isInfluencerOnly) {
      return '인플루언서 상품 주문은 쿠폰/포인트 사용이 불가합니다.';
    }
    if (_hasInfluencerItems) {
      return '인플루언서 상품에는 쿠폰/포인트가 적용되지 않습니다.';
    }
    return '';
  }

  int _discountForCoupon(Coupon coupon) {
    final base = _baseAmountForCoupon(coupon);
    if (base <= 0 || base < coupon.minimum) return 0;
    if (coupon.maximum > 0) {
      final discount = (base * coupon.price / 100).floor();
      return discount > coupon.maximum ? coupon.maximum : discount;
    }
    return coupon.price > base ? base : coupon.price;
  }

  int get _couponDiscountRaw => _couponPointDisabled
      ? 0
      : _selectedCoupons.fold(0, (sum, c) => sum + _discountForCoupon(c));

  int get _couponDiscount {
    final raw = _couponDiscountRaw;
    if (raw <= _nonInfluencerAmount) return raw;
    return _nonInfluencerAmount;
  }

  int get _pointEligibleBaseAmount {
    final base = _nonInfluencerAmount - _couponDiscount;
    return base < 0 ? 0 : base;
  }

  int get _maxPointByRate {
    final eligibleBase = _pointEligibleBaseAmount;
    final nonInfTotal = _nonInfluencerAmount;
    if (eligibleBase <= 0 || nonInfTotal <= 0) return 0;

    var total = 0;
    for (final item in widget.cartItems) {
      if (_isInfluencerCartItem(item)) continue;
      final share = (eligibleBase * item.ctPrice / nonInfTotal).floor();
      final rate = _pointRateForItem(item);
      total += (share * rate / 100).floor();
    }
    return total < 0 ? 0 : total;
  }

  int get _maxPointByMinimumPayable {
    final maxByMinimum = _purchaseAmount - _couponDiscount - _minPayableAmount;
    return maxByMinimum < 0 ? 0 : maxByMinimum;
  }

  int get _maxUsablePoint {
    if (_couponPointDisabled) return 0;
    const maxPerOrder = 50000;
    final candidates = [
      _myPoint,
      _maxPointByRate,
      _maxPointByMinimumPayable,
      maxPerOrder,
    ];
    final v = candidates.reduce((a, b) => a < b ? a : b);
    return v < 0 ? 0 : v;
  }

  int get _maxUsablePointHundreds => (_maxUsablePoint ~/ 100) * 100;

  int get _pointDiscount {
    final capped =
        _usedPoint > _maxUsablePointHundreds ? _maxUsablePointHundreds : _usedPoint;
    return (capped ~/ 100) * 100;
  }

  int get _finalAmount {
    final amount = _purchaseAmount +
        widget.shippingCost -
        _couponDiscount -
        _pointDiscount;
    return amount < 0 ? 0 : amount;
  }

  int get _expectedPoint => (_finalAmount * 0.01).floor();

  void _onPointChanged() {
    if (_syncingPoint) return;
    final raw = _pointController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final value = int.tryParse(raw) ?? 0;
    final capped =
        value > _maxUsablePointHundreds ? _maxUsablePointHundreds : value;
    // 1224 입력 → 1200 처럼 100점 단위로 자동 절삭 (단, 0~99는 그대로 입력 유지)
    final safe = capped >= 100 ? (capped ~/ 100) * 100 : capped;

    if (raw != safe.toString()) {
      _syncingPoint = true;
      _pointController.value = TextEditingValue(
        text: safe == 0 ? '' : '$safe',
        selection:
            TextSelection.collapsed(offset: safe == 0 ? 0 : '$safe'.length),
      );
      _syncingPoint = false;
    }

    if (safe != _usedPoint) {
      setState(() {
        _usedPoint = safe;
      });
    }
  }

  /// [preserveDeliveryMemo]: 배송지 변경 시 주소북 adMemo가 비어 있으면
  /// 결제 화면에서 고른 배송요청사항(드롭다운)을 유지한다.
  void _applyAddressMode({bool preserveDeliveryMemo = false}) {
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
    final addressMemo = _safe(ad?['adMemo']);
    if (addressMemo.isNotEmpty || !preserveDeliveryMemo) {
      _memoController.text = addressMemo;
    }
  }

  Future<void> _openDeliveryAddressChangePopup() async {
    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DeliveryAddressChangePopup(
        initiallySelectedAddress: _defaultAddress,
      ),
    );
    if (!mounted) return;
    if (result is Map<String, dynamic>) {
      setState(() {
        _defaultAddress = result;
        _applyAddressMode(preserveDeliveryMemo: true);
      });
    }
  }

  /// 배송요청사항 드롭다운 선택값 → 주문 `od_memo`
  String get _deliveryRequestMemo => _memoController.text.trim();

  String _safe(dynamic value) => (value ?? '').toString().trim();

  String _formatPostalCodeDisplay(String postalCode) {
    final t = postalCode.replaceAll(RegExp(r'[^0-9]'), '');
    if (t.length == 5) {
      return '${t.substring(0, 3)}-${t.substring(3)}';
    }
    return postalCode.trim();
  }

  String _formatPhoneDisplay(String raw) {
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 11) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 7)}-${digits.substring(7)}';
    }
    if (digits.length == 10) {
      return '${digits.substring(0, 3)}-${digits.substring(3, 6)}-${digits.substring(6)}';
    }
    return raw;
  }

  String _fullDeliveryAddressText() {
    return [
      _addressController.text.trim(),
      _detailAddressController.text.trim(),
    ].where((e) => e.isNotEmpty).join(' ');
  }

  /// 운영 쇼핑몰 `www/shop/orderform.sub.payment.php` 의 `od_settle_case` 값과 동일.
  String get _paymentMethodLabel {
    switch (_paymentMethodIndex) {
      case 1:
        return '계좌이체';
      case 2:
        return '가상계좌';
      default:
        return '신용카드';
    }
  }

  /// KCP PayPlus hidden `pay_method` (영카트 `www/shop/orderform.sub.php` forderform_check 분기와 동일).
  String get _kcpPayMethodBits {
    switch (_paymentMethodIndex) {
      case 1:
        return '010000000000';
      case 2:
        return '001000000000';
      default:
        return '100000000000';
    }
  }

  String _kcpMobileUserAgent() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1';
    }
    return 'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Mobile Safari/537.36';
  }

  String _kcpDesktopUserAgent() {
    return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36';
  }

  String _kcpRequestUserAgent() => kIsWeb ? _kcpDesktopUserAgent() : _kcpMobileUserAgent();

  bool _validateBeforePay() {
    if (_receiverController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _zipController.text.trim().isEmpty ||
        _addressController.text.trim().isEmpty) {
      return false;
    }
    if (_finalAmount < _minPayableAmount) {
      return false;
    }
    return true;
  }

  int _pointRateForItem(CartItem item) {
    final influencer = item.ctMbInf.trim().isNotEmpty;
    if (influencer) return 0;
    if (item.ctKind.toLowerCase() == 'prescription') return 100;
    final rate = item.pointUsageRate;
    if (rate <= 0) return 0;
    if (rate > 100) return 100;
    return rate;
  }

  int _baseAmountForCoupon(Coupon coupon) {
    bool isEligibleItem(CartItem item) => !_isInfluencerCartItem(item);

    switch (coupon.method) {
      case 0:
        if (coupon.target.trim().isEmpty) return _nonInfluencerAmount;
        return widget.cartItems
            .where((item) =>
                isEligibleItem(item) && item.itId == coupon.target.trim())
            .fold<int>(0, (sum, item) => sum + item.ctPrice);
      case 1:
        if (coupon.target.trim().isEmpty) return _nonInfluencerAmount;
        final target = coupon.target.trim().toLowerCase();
        return widget.cartItems.where((item) {
          if (!isEligibleItem(item)) return false;
          final source =
              '${item.productType ?? ''} ${item.itSubject ?? ''} ${item.itName}'
                  .toLowerCase();
          return source.contains(target);
        }).fold<int>(0, (sum, item) => sum + item.ctPrice);
      case 2:
        return _nonInfluencerAmount;
      case 3:
        return widget.shippingCost;
      default:
        return _purchaseAmount;
    }
  }

  Map<String, String> _splitZipForApi(String raw) {
    var t = raw.replaceAll(RegExp(r'\s'), '');
    if (t.isEmpty) return {'zip1': '', 'zip2': ''};
    if (t.contains('-')) {
      final i = t.indexOf('-');
      return {'zip1': t.substring(0, i), 'zip2': t.substring(i + 1)};
    }
    if (t.length == 5) {
      return {'zip1': t.substring(0, 3), 'zip2': t.substring(3)};
    }
    return {'zip1': t, 'zip2': ''};
  }

  Future<void> _maybeSaveDefaultAddress(String mbId) async {
    if (_hasSavedAddress || !_saveAsDefault) return;
    final zipParts = _splitZipForApi(_zipController.text.trim());
    final subject = _addressNameController.text.trim().isNotEmpty
        ? _addressNameController.text.trim()
        : _addressLabelChip;
    await AddressService.addAddress({
      'mbId': mbId,
      'adSubject': subject,
      'adDefault': 1,
      'ad_default': 1,
      'adName': _receiverController.text.trim(),
      'adTel': _phoneController.text.trim(),
      'adHp': _phoneController.text.trim(),
      'adZip1': zipParts['zip1'] ?? '',
      'adZip2': zipParts['zip2'] ?? '',
      'adAddr1': _addressController.text.trim(),
      'adAddr2': _detailAddressController.text.trim(),
      'adAddr3': '',
      'adJibeon': '',
      'adMemo': _deliveryRequestMemo,
    });
  }

  Future<void> _requestKcpPayment() async {
    if (_submitting) return;
    if (!_validateBeforePay()) return;

    final user = await AuthService.getUser();
    if (user == null || user.id.trim().isEmpty) return;

    final cartIds = widget.cartItems.map((e) => e.ctId).toList();
    if (cartIds.isEmpty) return;

    setState(() {
      _submitting = true;
    });

    try {
      await _maybeSaveDefaultAddress(user.id);
      final response = await ApiClient.post(
        ApiEndpoints.kcpPayRequest,
        {
          'mb_id': user.id,
          'cart_ids': cartIds,
          'payment_method': _paymentMethodLabel,
          'pay_method': _kcpPayMethodBits,
          'escrow_use': _useEscrow,
          'shipping_cost': widget.shippingCost,
          'coupon_discount': _couponDiscount,
          'used_point': _pointDiscount,
          'final_amount': _finalAmount,
          'goods_name': widget.cartItems.length == 1
              ? widget.cartItems.first.itName
              : '${widget.cartItems.first.itName} 외 ${widget.cartItems.length - 1}건',
          'orderer': {
            'name': user.name,
            'email': user.email,
            'tel': user.phone ?? _phoneController.text.trim(),
            'hp': user.phone ?? _phoneController.text.trim(),
          },
          // 배송요청사항 → bomiora_shop_order.od_memo
          'od_memo': _deliveryRequestMemo,
          'receiver': {
            'name': _receiverController.text.trim(),
            'tel': _phoneController.text.trim(),
            'hp': _phoneController.text.trim(),
            'zip': _zipController.text.trim(),
            'addr1': _addressController.text.trim(),
            'addr2': _detailAddressController.text.trim(),
            'addr3': '',
            'memo': _deliveryRequestMemo,
          },
          // 앱: SmartPay(모바일 거래등록). 웹: PC payplus_web.
          'user_agent': kIsWeb
              ? 'Windows'
              : (defaultTargetPlatform == TargetPlatform.iOS
                  ? 'iPhone'
                  : 'Android'),
          'is_mobile': !kIsWeb,
        },
        additionalHeaders: <String, String>{
          'User-Agent': _kcpRequestUserAgent(),
        },
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode != 200 || data['success'] != true) {
        throw Exception((data['message'] ?? '결제 요청에 실패했습니다.').toString());
      }

      if (!mounted) return;
      final html = (data['html'] ?? '').toString();
      final token = (data['token'] ?? '').toString();
      if (html.isEmpty || token.isEmpty) {
        throw Exception('KCP 결제 요청 응답이 올바르지 않습니다.');
      }

      dynamic result;
      if (kIsWeb) {
        result = await Navigator.of(context).push<Map<String, dynamic>>(
          PageRouteBuilder(
            opaque: false,
            barrierDismissible: false,
            barrierColor: const Color(0x99000000),
            pageBuilder: (context, animation, secondaryAnimation) {
              return KcpPayWebViewScreen(
                html: html,
                token: token,
                usePcLayout: true,
              );
            },
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          ),
        );
      } else {
        result = await Navigator.pushNamed(
          context,
          '/kcp-pay',
          arguments: {
            'html': html,
            'token': token,
          },
        );
      }

      if (!mounted || result == null) return;
      final resultMap =
          result is Map<String, dynamic> ? result : <String, dynamic>{};
      final success = resultMap['success'] == true;
      final message = (resultMap['message'] ?? '').toString();
      final errorCode = (resultMap['error_code'] ?? '').toString().trim();
      var orderId = (resultMap['order_id'] ?? '').toString().trim();

      if (success) {
        // 가상계좌 등에서 order_id 누락 시 결과 API로 한 번 더 보정
        if (orderId.isEmpty && token.isNotEmpty) {
          try {
            final retry =
                await ApiClient.get(ApiEndpoints.kcpPayResult(token));
            if (retry.statusCode == 200) {
              final retryData =
                  jsonDecode(retry.body) as Map<String, dynamic>;
              orderId = (retryData['order_id'] ?? '').toString().trim();
            }
          } catch (_) {}
        }

        if (!mounted) return;
        if (orderId.isNotEmpty) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/payment-complete',
            (route) => route.isFirst,
            arguments: {'orderId': orderId},
          );
        } else {
          // 성공인데 주문번호가 없으면 주문내역으로 (메인으로 떨어지지 않게)
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/order',
            (route) => route.isFirst,
          );
        }
      } else {
        final code = _resolvePaymentErrorCode(errorCode, message);
        // [3001] 사용자 취소(또는 앱 내부 USER_CANCELLED)는 실패 안내 팝업/스낵바 없이
        // 현재 결제 페이지로 자연스럽게 복귀합니다.
        if (code == '3001' || code == 'USER_CANCELLED') {
          return;
        }

        await _showPaymentFailureGuideDialog(code, message);
      }
    } catch (e) {
      if (!mounted) return;
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  String _resolvePaymentErrorCode(String rawCode, String message) {
    final code = rawCode.trim();
    if (code.isNotEmpty) return code;

    final match = RegExp(r'\[([A-Za-z0-9_]+)\]').firstMatch(message);
    if (match != null) {
      return (match.group(1) ?? '').trim();
    }
    if (message.contains('NO_CODE')) return 'NO_CODE';
    return 'UNKNOWN';
  }

  String _paymentErrorGuideText(String code) {
    switch (code) {
      case '3017':
        return '카드 인증 팝업이 차단된 상태입니다.\n\n'
            '- 브라우저 팝업 차단 해제\n'
            '- 결제창 다시열기 후 재시도\n'
            '- 동일하면 Edge/웨일 등 다른 브라우저로 시도';
      case '3014':
        return 'KCP 사이트코드/도메인 등록 정보 불일치입니다.\n\n'
            '- SITE_CD, JS_URL(운영/테스트) 일치 확인\n'
            '- KCP 관리자에 결제 호출/리턴/공통통보 URL 등록 확인';
      case 'NO_CODE':
        return 'KCP 응답코드를 받지 못했습니다.\n\n'
            '- 네트워크/CSP/브리지 로그 확인\n'
            '- 백엔드 승인 브리지 응답(stderr 포함) 점검';
      case 'USER_CANCELLED':
        return '사용자가 결제창을 닫아 결제가 취소되었습니다.\n'
            '현재 페이지에서 결제하기 버튼으로 다시 진행할 수 있습니다.';
      default:
        return '결제가 완료되지 않았습니다.\n'
            '잠시 후 다시 시도하거나 주문내역에서 상태를 확인해 주세요.';
    }
  }

  Future<void> _showPaymentFailureGuideDialog(
    String code,
    String message,
  ) async {
    if (!mounted) return;
    final titleCode = code.isEmpty ? 'UNKNOWN' : code;
    final guide = _paymentErrorGuideText(titleCode);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: Text('결제 실패 안내 [$titleCode]'),
          content: SingleChildScrollView(
            child: Text(
              '$guide\n\n원인 메시지:\n${message.isEmpty ? '(없음)' : message}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('확인'),
            ),
          ],
        );
      },
    );
  }

  String _couponPickerLine(Coupon c) {
    final sub = c.subject.trim();
    final disc = c.discountText.trim();
    if (sub.isEmpty && disc.isEmpty) return '쿠폰 #${c.no}';
    if (sub.isEmpty) return '$disc (#${c.no})';
    if (disc.isEmpty) return sub;
    return '$sub ($disc)';
  }

  List<String> _uniqueCouponPickerLines(List<Coupon> candidates) {
    final seen = <String>{};
    final out = <String>[];
    for (final c in candidates) {
      var line = _couponPickerLine(c);
      var n = 0;
      while (seen.contains(line)) {
        n += 1;
        line = '${_couponPickerLine(c)} ·$n';
      }
      seen.add(line);
      out.add(line);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: HealthAppBar(
          title: widget.showPrescriptionBookingProgress
              ? '진료예약 중 _ 03 주문/결제'
              : '주문/결제',
          centerTitle: false,
          bottom: widget.showPrescriptionBookingProgress
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(
                    PrescriptionBookingProgressBar.preferredHeight,
                  ),
                  child: ValueListenableBuilder<double>(
                    valueListenable: _scrollProgress,
                    builder: (context, progress, _) {
                      return PrescriptionBookingProgressBar(
                        currentStep: PrescriptionBookingSteps.payment,
                        stepProgress: progress,
                      );
                    },
                  ),
                )
              : null,
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _handleBookingScrollNotification,
                      child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        bottom: healthDp(context, 16),
                      ),
                      child: DefaultTextStyle.merge(
                        style:
                            const TextStyle(fontFamily: 'Gmarket Sans TTF'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: healthDp(context, 20)),
                            _buildDeliverySection(context),
                            SizedBox(height: healthDp(context, 20)),
                            _buildOrderListSection(context),
                            SizedBox(height: healthDp(context, 20)),
                            _buildCouponPointTotalSection(context),
                            SizedBox(height: healthDp(context, 20)),
                            _buildPaymentMethodHeaderSection(context),
                            SizedBox(height: healthDp(context, 20)),
                          ],
                        ),
                      ),
                    ),
                    ),
                  ),
                  _buildPaymentBottomBar(context),
                ],
              ),
      ),
    );
  }

  Widget _buildPaymentBottomBar(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          healthDp(context, 27),
          healthDp(context, 10),
          healthDp(context, 27),
          healthDp(context, 16),
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: healthDp(context, 8),
              offset: Offset(0, -healthDp(context, 2)),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: healthDp(context, 40),
          child: ElevatedButton(
            onPressed: _submitting ? null : _requestKcpPayment,
            style: ElevatedButton.styleFrom(
              minimumSize: Size(double.infinity, healthDp(context, 40)),
              maximumSize: Size(double.infinity, healthDp(context, 40)),
              padding: EdgeInsets.zero,
              backgroundColor: _pink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(healthDp(context, 10)),
              ),
            ),
            child: _submitting
                ? SizedBox(
                    width: healthDp(context, 18),
                    height: healthDp(context, 18),
                    child: CircularProgressIndicator(
                      strokeWidth: healthDp(context, 2),
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    '결제하기',
                    style: TextStyle(
                      fontSize: healthSp(context, 14),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _addressChangeButton(BuildContext context) => InkWell(
        onTap: _openDeliveryAddressChangePopup,
        borderRadius: BorderRadius.circular(healthDp(context, 9999)),
        child: Container(
          width: healthDp(context, 94),
          height: healthDp(context, 30),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 1, color: Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(healthDp(context, 9999)),
            ),
          ),
          child: Text(
            '배송지 변경',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );

  Widget _sectionCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 14),
        vertical: healthDp(context, 20),
      ),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: Color(0x7FD2D2D2)),
          borderRadius: BorderRadius.circular(healthDp(context, 15)),
        ),
      ),
      child: child,
    );
  }

  Widget _requiredLabel(BuildContext context, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          text,
          style: TextStyle(
            color: _muted,
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          '*',
          style: TextStyle(
            color: _pink,
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _addressLabelChipBtn(BuildContext context, String label) {
    final selected = (!_showCustomAddressName && _addressLabelChip == label) ||
        (_showCustomAddressName && label == '직접입력');
    return InkWell(
      onTap: () {
        setState(() {
          if (label == '직접입력') {
            _showCustomAddressName = true;
            _addressLabelChip = '직접입력';
            if (_addressNameController.text == '집' ||
                _addressNameController.text == '회사') {
              _addressNameController.clear();
            }
          } else {
            _showCustomAddressName = false;
            _addressLabelChip = label;
            _addressNameController.text = label;
          }
        });
      },
      borderRadius: BorderRadius.circular(healthDp(context, 15)),
      child: Container(
        height: healthDp(context, _kDeliveryFieldHeight),
        padding: EdgeInsets.symmetric(horizontal: healthDp(context, 14)),
        decoration: ShapeDecoration(
          color: selected ? const Color(0x0CFF5A8D) : Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: 1,
              color: selected ? _pink : _border,
            ),
            borderRadius: BorderRadius.circular(healthDp(context, 15)),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _pink : const Color(0xFF898383),
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  /// 배송지 폼 입력칸 공통 높이 (375 기준) — 주소칸·드롭다운과 동일 셸 사용
  static const double _kDeliveryFieldHeight = 45;
  static const Color _kDeliveryFieldFill = Color(0xFFF8FAFC);

  /// 높이 45 고정 박스 (테두리·배경). TextField Outline은 높이 무시하므로 사용하지 않음.
  Widget _deliveryFieldBox({
    required Widget child,
    Color? fillColor,
    Color? borderColor,
    VoidCallback? onTap,
  }) {
    final h = healthDp(context, _kDeliveryFieldHeight);
    final r = healthDp(context, 10);
    final box = Container(
      width: double.infinity,
      height: h,
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: fillColor ?? _kDeliveryFieldFill,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(width: 1, color: borderColor ?? _border),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(r),
      child: box,
    );
  }

  Widget _deliveryTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return _deliveryFieldBox(
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(
          fontSize: healthSp(context, 12),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
          height: 1.2,
          color: const Color(0xFF1A1A1E),
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isCollapsed: true,
          hintText: hint,
          hintStyle: TextStyle(
            color: _muted,
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildDeliverySection(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 27)),
      child: _hasSavedAddress
          ? _buildDeliveryFilledCard(context)
          : _buildDeliveryEmptyForm(context),
    );
  }

  Widget _buildDeliveryFilledCard(BuildContext context) {
    final name = _receiverController.text.trim();
    final label = _addressNameController.text.trim();
    final title = label.isEmpty ? name : '$name ($label)';
    final phone = _formatPhoneDisplay(_phoneController.text.trim());
    final fullAddress = _fullDeliveryAddressText();
    final memo = _memoController.text.trim();
    final memoItems = [
      ..._deliveryMemoPresets,
      if (memo.isNotEmpty && !_deliveryMemoPresets.contains(memo)) memo,
    ];

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title.isEmpty ? '배송지' : title,
                  style: TextStyle(
                    color: const Color(0xFF333333),
                    fontSize: healthSp(context, 16),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    height: 1.75,
                  ),
                ),
              ),
              _addressChangeButton(context),
            ],
          ),
          SizedBox(height: healthDp(context, 5)),
          if (phone.isNotEmpty)
            Text(
              phone,
              style: TextStyle(
                color: const Color(0xFF1A1A1E),
                fontSize: healthSp(context, 12),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          if (fullAddress.isNotEmpty) ...[
            SizedBox(height: healthDp(context, 4)),
            Text(
              fullAddress,
              style: TextStyle(
                color: const Color(0xFF1A1A1E),
                fontSize: healthSp(context, 12),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          SizedBox(height: healthDp(context, 10)),
          Text(
            '배송 요청 사항',
            style: TextStyle(
              color: _muted,
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: healthDp(context, 2)),
          DropdownBtn(
            buttonHeight: healthDp(context, _kDeliveryFieldHeight),
            items: memoItems,
            value: memo,
            emptyText: '배송메모를 선택해주세요',
            emptyTextColor: _muted,
            valueTextColor: const Color(0xFF1A1A1E),
            borderColor: _border,
            itemFontSizeBase: 12,
            itemTextAlign: TextAlign.left,
            onChanged: (value) {
              setState(() => _memoController.text = value);
            },
          ),
          SizedBox(height: healthDp(context, 5)),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '※ 영업일 기준 오후 2시 이전 처방완료 시 당일 발송',
              style: TextStyle(
                color: _muted,
                fontSize: healthSp(context, 10),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
                letterSpacing: -0.40,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryEmptyForm(BuildContext context) {
    final memo = _memoController.text.trim();
    final memoItems = [
      ..._deliveryMemoPresets,
      if (memo.isNotEmpty && !_deliveryMemoPresets.contains(memo)) memo,
    ];
    final addressDisplay = [
      if (_zipController.text.trim().isNotEmpty) '(${_zipController.text.trim()})',
      _addressController.text.trim(),
      _detailAddressController.text.trim(),
    ].where((e) => e.isNotEmpty).join(' ');

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '배송지',
            style: TextStyle(
              color: const Color(0xFF1A1A1E),
              fontSize: healthSp(context, 16),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
              letterSpacing: -1.44,
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          Text(
            '배송지명 (선택)',
            style: TextStyle(
              color: _muted,
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: healthDp(context, 2)),
          Row(
            children: [
              _addressLabelChipBtn(context, '집'),
              SizedBox(width: healthDp(context, 8)),
              _addressLabelChipBtn(context, '회사'),
              SizedBox(width: healthDp(context, 8)),
              _addressLabelChipBtn(context, '직접입력'),
            ],
          ),
          if (_showCustomAddressName) ...[
            SizedBox(height: healthDp(context, 2)),
            _deliveryTextField(
              controller: _addressNameController,
              hint: '배송지명을 입력해 주세요.',
            ),
          ],
          SizedBox(height: healthDp(context, 10)),
          _requiredLabel(context, '받으시는 분'),
          SizedBox(height: healthDp(context, 2)),
          _deliveryTextField(
            controller: _receiverController,
            hint: '수령인의 이름을 입력해 주세요.',
          ),
          SizedBox(height: healthDp(context, 10)),
          _requiredLabel(context, '연락처'),
          SizedBox(height: healthDp(context, 2)),
          _deliveryTextField(
            controller: _phoneController,
            hint: '‘-’없이 기입해주세요.',
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          SizedBox(height: healthDp(context, 10)),
          _requiredLabel(context, '배송지 주소'),
          SizedBox(height: healthDp(context, 2)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _deliveryFieldBox(
                  onTap: _openAddressSearch,
                  child: Text(
                    addressDisplay.isEmpty ? '주소를 검색해 주세요' : addressDisplay,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: addressDisplay.isEmpty
                          ? _muted
                          : const Color(0xFF1A1A1E),
                      fontSize: healthSp(context, 12),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              SizedBox(width: healthDp(context, 10)),
              Material(
                color: _pink,
                borderRadius: BorderRadius.circular(healthDp(context, 10)),
                child: InkWell(
                  onTap: _openAddressSearch,
                  borderRadius: BorderRadius.circular(healthDp(context, 10)),
                  child: SizedBox(
                    height: healthDp(context, _kDeliveryFieldHeight),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: healthDp(context, 10),
                      ),
                      child: Center(
                        child: Text(
                          '주소 검색',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: healthSp(context, 12),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_addressController.text.trim().isNotEmpty) ...[
            SizedBox(height: healthDp(context, 10)),
            _deliveryTextField(
              controller: _detailAddressController,
              hint: '상세주소를 입력해 주세요.',
            ),
          ],
          SizedBox(height: healthDp(context, 10)),
          Text(
            '배송 요청 사항',
            style: TextStyle(
              color: _muted,
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: healthDp(context, 2)),
          DropdownBtn(
            buttonHeight: healthDp(context, _kDeliveryFieldHeight),
            items: memoItems,
            value: memo,
            emptyText: '배송메모를 선택해주세요',
            emptyTextColor: _muted,
            valueTextColor: const Color(0xFF1A1A1E),
            borderColor: _border,
            itemFontSizeBase: 12,
            itemTextAlign: TextAlign.left,
            onChanged: (value) {
              setState(() => _memoController.text = value);
            },
          ),
          SizedBox(height: healthDp(context, 10)),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '※ 영업일 기준 오후 2시 이전 처방완료 시 당일 발송',
              style: TextStyle(
                color: _muted,
                fontSize: healthSp(context, 10),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
                letterSpacing: -0.40,
              ),
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          InkWell(
            onTap: () => setState(() => _saveAsDefault = !_saveAsDefault),
            child: Row(
              children: [
                Container(
                  width: healthDp(context, 20),
                  height: healthDp(context, 20),
                  decoration: ShapeDecoration(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      side: const BorderSide(width: 1, color: _border),
                      borderRadius: BorderRadius.circular(healthDp(context, 4)),
                    ),
                  ),
                  child: _saveAsDefault
                      ? Icon(Icons.check,
                          size: healthDp(context, 14), color: _pink)
                      : null,
                ),
                SizedBox(width: healthDp(context, 5)),
                Text(
                  '기본 배송지로 설정',
                  style: TextStyle(
                    color: const Color(0xFF1A1A1E),
                    fontSize: healthSp(context, 12),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderListSection(BuildContext context) {
    // 비대면: 예약시간 + 본품/추가상품 그룹 카드
    if (widget.showPrescriptionBookingProgress) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: healthDp(context, 27)),
        child: _sectionCard(
          child: PaymentProductCard(
            cartItems: widget.cartItems,
            reservationDate: widget.reservationDate,
            reservationTime: widget.reservationTime,
          ),
        ),
      );
    }

    // 일반상품: 업체별 묶음배송 카드 (CartGroupGeneralCard)
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 27)),
      child: PaymentGeneralProductCard(cartItems: widget.cartItems),
    );
  }

  /// 쿠폰/포인트 + 결제금액 내역 + 총 결제비용
  Widget _buildCouponPointTotalSection(BuildContext context) {
    final showCoupon = !_couponPointDisabled && _applicableCoupons.isNotEmpty;
    final showPoint = !_couponPointDisabled && _myPoint > 0;
    final showCouponPoint = showCoupon || showPoint;

    // 쿠폰 카드 안쪽(14)과 맞춰 결제금액·수단은 약 41(≈35~)로 맞춤
    final amountPad = healthDp(context, 41);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showCouponPoint)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: healthDp(context, 27)),
            child: _sectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showCoupon) ...[
                    Row(
                      children: [
                        Text(
                          '쿠폰 선택',
                          style: TextStyle(
                            color: const Color(0xFF1A1A1E),
                            fontSize: healthSp(context, 16),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                            letterSpacing: -1.44,
                          ),
                        ),
                        SizedBox(width: healthDp(context, 5)),
                        Container(
                          constraints: BoxConstraints(
                            minWidth: healthDp(context, 18),
                            minHeight: healthDp(context, 18),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: healthDp(context, 5),
                            vertical: healthDp(context, 2),
                          ),
                          alignment: Alignment.center,
                          decoration: ShapeDecoration(
                            color: const Color(0x19FF5A8D),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(healthDp(context, 50)),
                            ),
                          ),
                          child: Text(
                            '${_applicableCoupons.length}',
                            style: TextStyle(
                              color: _pink,
                              fontSize: healthSp(context, 10),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                              height: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: healthDp(context, 2)),
                    _couponDropdown(context),
                    if (_selectedCoupons.isNotEmpty) ...[
                      SizedBox(height: healthDp(context, 10)),
                      ..._selectedCoupons
                          .map((c) => _selectedCouponRow(context, c)),
                    ],
                  ],
                  if (showCoupon && showPoint)
                    SizedBox(height: healthDp(context, 20)),
                  if (showPoint) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '포인트',
                          style: TextStyle(
                            color: const Color(0xFF1A1A1E),
                            fontSize: healthSp(context, 16),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                            letterSpacing: -1.44,
                          ),
                        ),
                        Text(
                          '보유 ${PointService.formatPoint(_myPoint)}점',
                          style: TextStyle(
                            color: _muted,
                            fontSize: healthSp(context, 14),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: healthDp(context, 2)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Container(
                            height: healthDp(context, 45),
                            alignment: Alignment.centerLeft,
                            padding: EdgeInsets.symmetric(
                              horizontal: healthDp(context, 10),
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              border: Border.all(color: _border),
                              borderRadius:
                                  BorderRadius.circular(healthDp(context, 10)),
                            ),
                            child: TextField(
                              controller: _pointController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              style: TextStyle(
                                fontSize: healthSp(context, 12),
                                fontFamily: 'Gmarket Sans TTF',
                                height: 1,
                                color: const Color(0xFF1A1A1E),
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                hintText:
                                    '${_usedPoint > 0 ? PointService.formatPoint(_usedPoint) : '0'} 포인트',
                                hintStyle: TextStyle(
                                  color: _muted,
                                  fontSize: healthSp(context, 12),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w300,
                                  height: 1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: healthDp(context, 10)),
                        InkWell(
                          onTap: () {
                            final max = _maxUsablePointHundreds;
                            setState(() {
                              _usedPoint = max;
                              _pointController.text = max > 0 ? '$max' : '';
                            });
                          },
                          borderRadius:
                              BorderRadius.circular(healthDp(context, 10)),
                          child: Container(
                            height: healthDp(context, 45),
                            padding: EdgeInsets.symmetric(
                              horizontal: healthDp(context, 10),
                              vertical: healthDp(context, 5),
                            ),
                            alignment: Alignment.center,
                            decoration: ShapeDecoration(
                              color: _pink,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  healthDp(context, 10),
                                ),
                              ),
                            ),
                            child: Text(
                              '전액사용',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: healthSp(context, 12),
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w500,
                                height: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: healthDp(context, 10)),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        '※ 포인트는 100점 단위로 사용 가능합니다.',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: _muted,
                          fontSize: healthSp(context, 10),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                          letterSpacing: -0.40,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        if (showCouponPoint) SizedBox(height: healthDp(context, 20)),
        if (_couponPointNotice.isNotEmpty) ...[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: amountPad),
            child: Text(
              _couponPointNotice,
              style: TextStyle(
                color: _muted,
                fontSize: healthSp(context, 11),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
          SizedBox(height: healthDp(context, 20)),
        ],
        Padding(
          padding: EdgeInsets.symmetric(horizontal: amountPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '결제 금액',
                style: TextStyle(
                  color: const Color(0xFF1A1A1E),
                  fontSize: healthSp(context, 16),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                  letterSpacing: -1.44,
                ),
              ),
              SizedBox(height: healthDp(context, 10)),
              _paymentAmountRow(
                context,
                '구매금액',
                '${PriceFormatter.format(_purchaseAmount)} 원',
              ),
              if (_couponDiscount > 0) ...[
                SizedBox(height: healthDp(context, 16)),
                _paymentAmountRow(
                  context,
                  '쿠폰할인',
                  '-${PriceFormatter.format(_couponDiscount)} 원',
                  valueColor: _pink,
                ),
              ],
              if (_pointDiscount > 0) ...[
                SizedBox(height: healthDp(context, 16)),
                _paymentAmountRow(
                  context,
                  '포인트할인',
                  '-${PriceFormatter.format(_pointDiscount)} 원',
                  valueColor: _pink,
                ),
              ],
              if (widget.shippingCost > 0) ...[
                SizedBox(height: healthDp(context, 16)),
                _paymentAmountRow(
                  context,
                  '배송비',
                  '${PriceFormatter.format(widget.shippingCost)} 원',
                ),
              ],
              SizedBox(height: healthDp(context, 16)),
              Container(
                width: double.infinity,
                height: healthDp(context, 1),
                color: _border,
              ),
              SizedBox(height: healthDp(context, 16)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '총 결제비용',
                    style: TextStyle(
                      color: const Color(0xFF1A1A1E),
                      fontSize: healthSp(context, 16),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1.44,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${PriceFormatter.format(_finalAmount)}원',
                        style: TextStyle(
                          color: _pink,
                          fontSize: healthSp(context, 20),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w700,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: healthDp(context, 4)),
                      Text(
                        '예상 적립 포인트 : ${PointService.formatPoint(_expectedPoint)} 점',
                        style: TextStyle(
                          color: _muted,
                          fontSize: healthSp(context, 10),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                          height: 1.5,
                          letterSpacing: -0.40,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _paymentAmountRow(
    BuildContext context,
    String label,
    String value, {
    Color valueColor = const Color(0xFF1A1A1E),
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: _muted,
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: healthSp(context, 14),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentMethodHeaderSection(BuildContext context) {
    final showEscrow =
        _paymentMethodIndex == 1 || _paymentMethodIndex == 2;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 41)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '결제 수단',
            style: TextStyle(
              color: const Color(0xFF1A1A1E),
              fontSize: healthSp(context, 16),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
              letterSpacing: -1.44,
            ),
          ),
          SizedBox(height: healthDp(context, 2)),
          Row(
            children: [
              Expanded(child: _methodButton(context, '신용카드', 0)),
              SizedBox(width: healthDp(context, 10)),
              Expanded(child: _methodButton(context, '계좌이체', 1)),
              SizedBox(width: healthDp(context, 10)),
              Expanded(child: _methodButton(context, '가상계좌', 2)),
            ],
          ),
          if (showEscrow) ...[
            SizedBox(height: healthDp(context, 20)),
            _escrowCombinedCard(context),
          ],
          SizedBox(height: healthDp(context, 10)),
          Align(
            alignment: Alignment.centerRight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '※ 할부 결제는 일반카드 결제만 가능합니다.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: healthSp(context, 10),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                    letterSpacing: -0.40,
                  ),
                ),
                SizedBox(height: healthDp(context, 5)),
                Text(
                  '※ 최소 결제금액은 3,000원 입니다.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: healthSp(context, 10),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                    letterSpacing: -0.40,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddressSearch() async {
    final selected = await showDaumPostcodeSearchDialog(context);
    if (!mounted || selected == null) return;

    final postalCode = (selected['postalCode'] ?? '').toString().trim();
    final roadAddress = (selected['roadAddress'] ?? '').toString().trim();
    final jibunAddress = (selected['jibunAddress'] ?? '').toString().trim();
    final extraAddress = (selected['extraAddress'] ?? '').toString().trim();
    final baseAddress = roadAddress.isNotEmpty ? roadAddress : jibunAddress;

    setState(() {
      _zipController.text = _formatPostalCodeDisplay(postalCode);
      _addressController.text = baseAddress;
      if (_detailAddressController.text.trim().isEmpty &&
          extraAddress.isNotEmpty) {
        _detailAddressController.text = extraAddress;
      }
    });
  }

  bool get _hasCategoryCoupon =>
      _selectedCoupons.any((coupon) => coupon.method == 1);
  bool get _hasNonCategoryCoupon =>
      _selectedCoupons.any((coupon) => coupon.method != 1);

  bool _isCouponMethodDisabled(int method) {
    if (method == 1) {
      return _hasNonCategoryCoupon;
    }
    if (_hasCategoryCoupon) return true;
    return _selectedCoupons.any((coupon) => coupon.method != method);
  }

  List<Coupon> _availableCouponsForUnifiedPicker() {
    if (_couponPointDisabled) return const [];
    return _applicableCoupons.where((coupon) {
      if (_selectedCoupons.any((selected) => selected.no == coupon.no)) {
        return false;
      }
      if (_isCouponMethodDisabled(coupon.method)) return false;
      if (coupon.method == 1) {
        final categoryCount =
            _selectedCoupons.where((c) => c.method == 1).length;
        if (categoryCount >= 2) return false;
      }
      return true;
    }).toList();
  }

  void _onUnifiedCouponChosen(String label) {
    final candidates = _availableCouponsForUnifiedPicker();
    final lines = _uniqueCouponPickerLines(candidates);
    final index = lines.indexOf(label);
    if (index < 0 || index >= candidates.length) return;
    final picked = candidates[index];
    final method = picked.method;

    setState(() {
      if (method == 1) {
        _selectedCoupons.removeWhere((coupon) => coupon.method != 1);
        final categoryCount =
            _selectedCoupons.where((coupon) => coupon.method == 1).length;
        if (categoryCount < 2) {
          _selectedCoupons.add(picked);
        }
      } else {
        _selectedCoupons.removeWhere(
            (coupon) => coupon.method == 1 || coupon.method != method);
        _selectedCoupons.removeWhere((coupon) => coupon.method == method);
        _selectedCoupons.add(picked);
      }

      if (_usedPoint > _maxUsablePoint) {
        _usedPoint = _maxUsablePoint;
        _pointController.text = _usedPoint == 0 ? '' : '$_usedPoint';
      }
    });
  }

  Widget _couponDropdown(BuildContext context) {
    final candidates = _availableCouponsForUnifiedPicker();
    final lines = _uniqueCouponPickerLines(candidates);
    if (lines.isEmpty) return const SizedBox.shrink();

    return DropdownBtn(
      buttonHeight: healthDp(context, 45),
      enabled: true,
      items: lines,
      value: '',
      emptyText: '쿠폰 선택 안함',
      emptyTextColor: _muted,
      valueTextColor: const Color(0xFF1A1A1E),
      borderColor: _border,
      itemFontSizeBase: 12,
      itemTextAlign: TextAlign.left,
      onChanged: _onUnifiedCouponChosen,
    );
  }

  Widget _selectedCouponRow(BuildContext context, Coupon coupon) {
    final typeLabel = _couponTypeLabel(coupon);
    final safeSubject = coupon.subject.trim();
    final safeTarget = coupon.target.trim();
    final safeDiscount = coupon.discountText.trim();
    final name = safeSubject.isNotEmpty
        ? safeSubject
        : (safeTarget.isNotEmpty ? safeTarget : '쿠폰명 없음');
    final line = safeDiscount.isNotEmpty ? '$name ($safeDiscount)' : name;

    return Padding(
      padding: EdgeInsets.only(bottom: healthDp(context, 10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeLabel,
                  style: TextStyle(
                    color: _figmaPink,
                    fontSize: healthSp(context, 12),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  line,
                  style: TextStyle(
                    color: _figmaDark,
                    fontSize: healthSp(context, 12),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              setState(() {
                _selectedCoupons.removeWhere((c) => c.no == coupon.no);
                if (_usedPoint > _maxUsablePointHundreds) {
                  _usedPoint = _maxUsablePointHundreds;
                  _pointController.text =
                      _usedPoint == 0 ? '' : '$_usedPoint';
                }
              });
            },
            child: Text(
              '삭제',
              style: TextStyle(
                color: _figmaBrown,
                fontSize: healthSp(context, 10),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
                decoration: TextDecoration.underline,
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
      case 2:
        return '[주문할인 쿠폰]';
      case 3:
        return '[배송비 쿠폰]';
      default:
        return '[쿠폰]';
    }
  }

  String _paymentMethodIconAsset(int index) {
    switch (index) {
      case 0:
        return AppAssets.payCredit;
      case 1:
      case 2:
        return AppAssets.payCash;
      default:
        return AppAssets.payCredit;
    }
  }

  Widget _methodButton(BuildContext context, String label, int index) {
    final selected = _paymentMethodIndex == index;
    final iconAsset = _paymentMethodIconAsset(index);
    final iconSz = healthDp(context, 24);
    return InkWell(
      onTap: () => setState(() => _paymentMethodIndex = index),
      borderRadius: BorderRadius.circular(healthDp(context, 12)),
      child: Container(
        constraints: BoxConstraints(minHeight: healthDp(context, 65)),
        padding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 11),
          vertical: healthDp(context, 10),
        ),
        decoration: ShapeDecoration(
          color: selected ? const Color(0x0CFF5C8F) : Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: healthDp(context, 1.11),
              color: selected ? const Color(0xFFFF5C8F) : _border,
            ),
            borderRadius: BorderRadius.circular(healthDp(context, 12)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              iconAsset,
              width: iconSz,
              height: iconSz,
              colorFilter: const ColorFilter.mode(
                Color(0xFF1A1A1E),
                BlendMode.srcIn,
              ),
            ),
            SizedBox(height: healthDp(context, 5)),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF1A1A1E),
                fontSize: healthSp(context, 12),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _escrowCombinedCard(BuildContext context) {
    final on = _useEscrow;
    final radius = healthDp(context, 12);
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(width: 1, color: const Color(0x7FD2D2D2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _useEscrow = !_useEscrow),
            borderRadius: BorderRadius.circular(radius),
            child: Padding(
              padding: EdgeInsets.all(healthDp(context, 10)),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '에스크로 결제 사용',
                          style: TextStyle(
                            color: const Color(0xFF1A1A1A),
                            fontSize: healthSp(context, 12),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: healthDp(context, 3)),
                        Text(
                          '구매자 안전결제로 진행합니다',
                          style: TextStyle(
                            color: const Color(0xFF898989),
                            fontSize: healthSp(context, 10),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    width: healthDp(context, 35),
                    padding: EdgeInsets.all(healthDp(context, 2)),
                    decoration: BoxDecoration(
                      color: on ? _pink : const Color(0xFFD2D2D2),
                      borderRadius: BorderRadius.circular(healthDp(context, 12)),
                    ),
                    child: Row(
                      mainAxisAlignment: on
                          ? MainAxisAlignment.end
                          : MainAxisAlignment.start,
                      children: [
                        Container(
                          width: healthDp(context, 15),
                          height: healthDp(context, 15),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(healthDp(context, 50)),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x19000000),
                                blurRadius: 2,
                                offset: Offset(0, 1),
                                spreadRadius: -1,
                              ),
                              BoxShadow(
                                color: Color(0x19000000),
                                blurRadius: 3,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (on) ...[
            Container(
              width: double.infinity,
              height: 1,
              color: const Color(0xFFE8E8E8),
            ),
            ClipRRect(
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(radius),
                bottomRight: Radius.circular(radius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFF7F7F7),
                    padding: EdgeInsets.all(healthDp(context, 10)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(healthDp(context, 6)),
                          child: Image.asset(
                            AppAssets.escrow,
                            width: healthDp(context, 56),
                            height: healthDp(context, 56),
                            fit: BoxFit.contain,
                          ),
                        ),
                        SizedBox(width: healthDp(context, 10)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '구매안전 (에스크로) 서비스',
                                style: TextStyle(
                                  color: const Color(0xFF1A1A1E),
                                  fontSize: healthSp(context, 10),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              SizedBox(height: healthDp(context, 5)),
                              Text(
                                '고객님은 안전거래를 위해 현금 등으로 결제시 저희 쇼핑몰에 가입한 KCP의 구매안전서비스를 이용하실 수 있습니다. 계좌이체 또는 가상계좌 등 현금 거래에만 해당되며, 신용카드 거래에는 해당되지 않습니다.',
                                style: TextStyle(
                                  color: _muted,
                                  fontSize: healthSp(context, 8),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w300,
                                  height: 1.88,
                                  letterSpacing: -0.24,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    color: const Color(0xFFF7F7F7),
                    padding: EdgeInsets.symmetric(
                      horizontal: healthDp(context, 10),
                      vertical: healthDp(context, 6),
                    ),
                    child: Text(
                      '2006.4.1 제정, 2013.11.29 개정 전자상거래 등에서의 소비자 보호에 관한 법률',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: const Color(0xFFAAAAAA),
                        fontSize: healthSp(context, 8),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                        letterSpacing: -0.32,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
