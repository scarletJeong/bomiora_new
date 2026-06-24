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
import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../core/utils/web_kcp_popup.dart';
import '../../../data/models/cart/cart_item_model.dart';
import '../../../data/models/coupon/coupon_model.dart';
import '../../../data/services/address_service.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/coupon_service.dart';
import '../../../data/services/point_service.dart';
import '../../user/delivery/widgets/delivery_address_change_popup_ver2.dart';
import '../../health/health_common/health_responsive_scale.dart';

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
  static const _figmaPink = Color(0xFFFF5B8C);
  static const _figmaBrown = Color(0xFF584045);
  static const _figmaDark = Color(0xFF1A1B1F);
  static const _figmaBorder = Color(0xFFE3E2E7);
  static const _figmaRoseBorder = Color(0xFFE0BEC4);
  static const _figmaSectionBg = Color(0xFFF4F3F8);

  static const _deliveryMemoPresets = <String>[
    '문 앞에 놓아주세요',
    '경비실에 맡겨주세요',
    '직접 받겠습니다',
    '배송 전 연락바랍니다',
    '부재 시 연락주세요',
  ];

  double _fieldH(BuildContext context) => healthDp(context, 40);

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
  bool _useAllPoints = false;
  bool _useEscrow = false;
  String? _lastWebKcpLaunchUrl;
  Object? _lastWebKcpPopup;

  int _paymentMethodIndex = 0; // 0 card, 1 bank transfer, 2 virtual account
  int _myPoint = 0;
  int _usedPoint = 0;
  static const int _minPayableAmount = 3000;

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
  bool get _isInfluencerOnly =>
      widget.cartItems.isNotEmpty &&
      widget.cartItems.every((item) => item.ctMbInf.trim().isNotEmpty);
  bool get _couponPointDisabled => _purchaseAmount <= 0 || _isInfluencerOnly;

  int _discountForCoupon(Coupon coupon) {
    final base = _baseAmountForCoupon(coupon);
    if (base <= 0 || base < coupon.minimum) return 0;
    if (coupon.maximum > 0) {
      final discount = (base * coupon.price / 100).floor();
      return discount > coupon.maximum ? coupon.maximum : discount;
    }
    return coupon.price > base ? base : coupon.price;
  }

  int get _couponDiscount => _couponPointDisabled
      ? 0
      : _selectedCoupons.fold(0, (sum, c) => sum + _discountForCoupon(c));

  int get _pointEligibleBaseAmount {
    final base = _purchaseAmount - _couponDiscount;
    return base < 0 ? 0 : base;
  }

  int get _maxPointByRate {
    final eligibleBase = _pointEligibleBaseAmount;
    if (eligibleBase <= 0 || _purchaseAmount <= 0) return 0;

    var total = 0;
    for (final item in widget.cartItems) {
      final share = (eligibleBase * item.ctPrice / _purchaseAmount).floor();
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
    final candidates = [
      _myPoint,
      _maxPointByRate,
      _maxPointByMinimumPayable,
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
        _useAllPoints = _usedPoint > 0 && _usedPoint == _maxUsablePointHundreds;
      });
    }
  }

  void _applyAddressMode() {
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
  }

  Future<void> _openDeliveryAddressChangePopup() async {
    final result = await showDialog<dynamic>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const DeliveryAddressChangePopup(),
    );
    if (!mounted) return;
    if (result is Map<String, dynamic>) {
      setState(() {
        _defaultAddress = result;
        _applyAddressMode();
      });
    }
  }

  String _safe(dynamic value) => (value ?? '').toString().trim();

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
    switch (coupon.method) {
      case 0:
        if (coupon.target.trim().isEmpty) return _purchaseAmount;
        return widget.cartItems
            .where((item) => item.itId == coupon.target.trim())
            .fold<int>(0, (sum, item) => sum + item.ctPrice);
      case 1:
        // 카테고리 정보가 API에 없는 경우 기존 텍스트 매칭 방식 유지
        if (coupon.target.trim().isEmpty) return _purchaseAmount;
        final target = coupon.target.trim().toLowerCase();
        return widget.cartItems.where((item) {
          final source =
              '${item.productType ?? ''} ${item.itSubject ?? ''} ${item.itName}'
                  .toLowerCase();
          return source.contains(target);
        }).fold<int>(0, (sum, item) => sum + item.ctPrice);
      case 2:
        return _purchaseAmount;
      case 3:
        return widget.shippingCost;
      default:
        return _purchaseAmount;
    }
  }

  Future<void> _requestKcpPayment() async {
    if (_submitting) return;
    if (!_validateBeforePay()) return;

    final webPendingPopup = kIsWeb ? openPendingKcpPopup() : null;
    if (kIsWeb && webPendingPopup == null) return;

    final user = await AuthService.getUser();
    if (user == null || user.id.trim().isEmpty) return;

    final cartIds = widget.cartItems.map((e) => e.ctId).toList();
    if (cartIds.isEmpty) return;

    setState(() {
      _submitting = true;
    });

    try {
      if (kIsWeb) {
        _lastWebKcpPopup = webPendingPopup;
      }
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
          'receiver': {
            'name': _receiverController.text.trim(),
            'tel': _phoneController.text.trim(),
            'hp': _phoneController.text.trim(),
            'zip': _zipController.text.trim(),
            'addr1': _addressController.text.trim(),
            'addr2': _detailAddressController.text.trim(),
            'addr3': '',
            'memo': _memoController.text.trim(),
          },
        },
        additionalHeaders: kIsWeb
            ? null
            : <String, String>{'User-Agent': _kcpMobileUserAgent()},
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
        final launchUrl =
            '${ApiClient.baseUrl}/api/kcp-pay/launch/${Uri.encodeComponent(token)}';
        _lastWebKcpLaunchUrl = launchUrl;
        // 1) 먼저 HTML을 Blob URL로 로드(서버 메모리 스토어 분산/재시작으로 launch 404가 나는 케이스 회피)
        // 2) 실패 시 launch URL로 폴백
        var opened = loadKcpHtmlToPopup(webPendingPopup, html);
        if (!opened) {
          // data: URL로 팝업 top-frame 이동은 Chrome에서 차단됨 → 백엔드 launch URL 폴백
          opened = loadKcpUrlToPopup(webPendingPopup, launchUrl);
        }
        if (!opened) {
          final directOpened = openKcpUrlInNewTab(launchUrl);
          if (!directOpened) {
            throw Exception('팝업이 차단되었습니다. 팝업 허용 후 다시 시도해 주세요.');
          }
        }
        if (!mounted) return;
        result = await _pollKcpPayResult(token, webPopup: webPendingPopup);
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
      final orderId = (resultMap['order_id'] ?? '').toString();

      if (success) {
        if (orderId.isNotEmpty) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            '/payment-complete',
            (route) => route.isFirst,
            arguments: {'orderId': orderId},
          );
        } else {
          Navigator.pushNamedAndRemoveUntil(
            context,
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
        if (kIsWeb && message.contains('3017')) {
          _showWebPopupBlockedDialog();
        }
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

  void _reopenWebKcpLaunch() {
    if (!kIsWeb) return;
    final url = (_lastWebKcpLaunchUrl ?? '').trim();
    if (url.isEmpty) return;
    openKcpUrlInNewTab(url);
  }

  Future<void> _showWebPopupBlockedDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          title: const Text('팝업 차단 감지 (3017)'),
          content: const Text(
            '결제창은 열렸지만 카드사 인증 팝업이 차단된 상태입니다.\n\n'
            '확장 프로그램/브라우저 팝업 차단을 해제한 뒤,\n'
            '"결제창 다시열기" 또는 아래 버튼으로 재시도해 주세요.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('닫기'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _reopenWebKcpLaunch();
              },
              child: const Text('결제창 다시열기'),
            ),
          ],
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _pollKcpPayResult(
    String token, {
    Object? webPopup,
  }) async {
    const maxTry = 150; // 약 5분
    var popupClosedSeen = false;
    var popupClosedGraceLeft = 6; // 팝업 닫힘 감지 후 약 12초(6*2s) 동안 결과를 추가 확인
    for (var i = 0; i < maxTry; i += 1) {
      if (!mounted) return null;
      if (kIsWeb && webPopup != null && isKcpPopupClosed(webPopup)) {
        // 가상계좌/승인 완료 직후 팝업이 먼저 닫히는 경우가 있어,
        // 즉시 취소 처리하지 않고 잠깐 결과를 더 확인한다.
        popupClosedSeen = true;
      }
      try {
        final response = await ApiClient.get(ApiEndpoints.kcpPayResult(token));
        if (response.statusCode == 404) {
          if (popupClosedSeen) {
            popupClosedGraceLeft -= 1;
            if (popupClosedGraceLeft <= 0) {
              return {
                'success': false,
                'error_code': 'USER_CANCELLED',
                'message': '사용자가 결제를 취소했습니다. 결제하기 버튼으로 다시 시도해 주세요.',
              };
            }
          }
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }

        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final status = (data['status'] ?? '').toString();
        if (status == 'pending') {
          // 가상계좌는 "입금 전"이어도 발급(결제 프로세스 완료)이면 완료 화면으로 이동해야 함.
          // 백엔드가 status=pending으로 내려도 res_cd=0000(성공) + order_id가 있으면 성공으로 처리.
          final resCd = (data['res_cd'] ?? '').toString().trim();
          final orderId = (data['order_id'] ?? '').toString().trim();
          if (resCd == '0000' && orderId.isNotEmpty) {
            return {
              'success': true,
              'error_code': data['error_code'],
              'status': status,
              'order_id': orderId,
              'message': (data['message'] ?? '가상계좌 발급이 완료되었습니다.').toString(),
            };
          }
          if (popupClosedSeen) {
            popupClosedGraceLeft -= 1;
            if (popupClosedGraceLeft <= 0) {
              return {
                'success': false,
                'error_code': 'USER_CANCELLED',
                'status': status,
                'order_id': data['order_id'],
                'message': '결제창이 닫혀 결제가 완료되지 않았습니다. 결제하기 버튼으로 다시 시도해 주세요.',
              };
            }
          }
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }

        return {
          'success': data['success'] == true,
          'error_code': data['error_code'],
          'status': status,
          'order_id': data['order_id'],
          'message': (data['message'] ?? '').toString(),
        };
      } catch (_) {
        if (popupClosedSeen) {
          popupClosedGraceLeft -= 1;
          if (popupClosedGraceLeft <= 0) {
            return {
              'success': false,
              'error_code': 'USER_CANCELLED',
              'message': '결제창이 닫혀 결제가 완료되지 않았습니다. 결제하기 버튼으로 다시 시도해 주세요.',
            };
          }
        }
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    return {
      'success': false,
      'error_code': 'NO_CODE',
      'message': '결제 결과 확인 시간이 초과되었습니다. 주문내역에서 상태를 확인해 주세요.',
    };
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
              onPressed: () {
                // 웹: 결제 새창이 남아있다면 닫고, 결제 화면에 그대로 복귀
                if (kIsWeb) {
                  closeKcpPopup(_lastWebKcpPopup);
                }
                Navigator.pop(context);
              },
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

  String _itemImageUrl(CartItem item) {
    final normalized =
        ImageUrlHelper.normalizeThumbnailUrl(item.imageUrl, item.itId);
    final fallback = normalized ??
        '${ImageUrlHelper.imageBaseUrl}/data/item/${item.itId}/no_img.png';
    final isAlreadyProxyUrl = fallback.contains('/api/proxy/image?url=');
    if (kIsWeb &&
        (Uri.base.host == 'localhost' || Uri.base.host == '127.0.0.1') &&
        fallback.startsWith('http') &&
        !isAlreadyProxyUrl) {
      return '${ApiClient.baseUrl}/api/proxy/image?url=${Uri.encodeComponent(fallback)}';
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: const HealthAppBar(title: '주문/결제', centerTitle: false),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
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
                            _buildOrderListSection(context),
                            _sectionGap(context),
                            _buildDeliverySection(context),
                            _sectionGap(context),
                            _buildCouponSection(context),
                            _buildPointSection(context),
                            _sectionGap(context),
                            _buildPaymentAmountSection(context),
                            _sectionGap(context),
                            _buildPaymentMethodHeaderSection(context),
                            if (_paymentMethodIndex == 1 ||
                                _paymentMethodIndex == 2) ...[
                              SizedBox(height: healthDp(context, 10)),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: healthDp(context, 27)),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _escrowToggle(
                                          context,
                                          '에스크로 사용',
                                          _useEscrow, () {
                                        setState(() => _useEscrow = true);
                                      }),
                                    ),
                                    SizedBox(width: healthDp(context, 10)),
                                    Expanded(
                                      child: _escrowToggle(
                                          context,
                                          '에스크로 미사용',
                                          !_useEscrow, () {
                                        setState(() => _useEscrow = false);
                                      }),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: healthDp(context, 10)),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: healthDp(context, 27)),
                                child: _escrowNotice(context),
                              ),
                              SizedBox(height: healthDp(context, 4)),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: healthDp(context, 27)),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '2006.4.1 제정, 2013.11.29 개정 전자상거래 등에서의 소비자 보호에 관한 법률',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: healthSp(context, 6.82),
                                      fontFamily: 'Gmarket Sans TTF',
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
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

  Widget _sectionGap(BuildContext context) => Container(
        width: double.infinity,
        height: healthDp(context, 8),
        color: _figmaSectionBg,
      );

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

  Widget _sectionTitleLarge(BuildContext context, String text) => Text(
        text,
        style: TextStyle(
          color: _figmaPink,
          fontSize: healthSp(context, 15),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        ),
      );

  Widget _addressChangeButton(BuildContext context) => InkWell(
        onTap: _openDeliveryAddressChangePopup,
        borderRadius: BorderRadius.circular(healthDp(context, 8)),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 12),
            vertical: healthDp(context, 4),
          ),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 1, color: _figmaRoseBorder),
              borderRadius: BorderRadius.circular(healthDp(context, 8)),
            ),
          ),
          child: Text(
            '변경',
            style: TextStyle(
              color: Colors.black,
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
              letterSpacing: 0.26,
            ),
          ),
        ),
      );

  Widget _buildDeliverySection(BuildContext context) {
    final addressLabel = _addressNameController.text.trim().isNotEmpty
        ? _addressNameController.text.trim()
        : '배송지';
    final fullAddress = _fullDeliveryAddressText();
    final phone = _formatPhoneDisplay(_phoneController.text.trim());
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 27),
        vertical: healthDp(context, 20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _sectionTitleLarge(context, '배송지'),
              _addressChangeButton(context),
            ],
          ),
          SizedBox(height: healthDp(context, 16)),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(healthDp(context, 16)),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                side: const BorderSide(width: 1, color: _figmaBorder),
                borderRadius: BorderRadius.circular(healthDp(context, 12)),
              ),
              shadows: const [
                BoxShadow(
                  color: Color(0x0C000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: healthDp(context, 6),
                        vertical: healthDp(context, 2),
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0x19FF5B8C),
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 4)),
                      ),
                      child: Text(
                        addressLabel,
                        style: TextStyle(
                          color: _figmaPink,
                          fontSize: healthSp(context, 12),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(width: healthDp(context, 8)),
                    Expanded(
                      child: Text(
                        _receiverController.text.trim().isEmpty
                            ? '수령인 없음'
                            : _receiverController.text.trim(),
                        style: TextStyle(
                          color: _figmaDark,
                          fontSize: healthSp(context, 14),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: healthDp(context, 4)),
                Text(
                  fullAddress.isEmpty ? '주소를 선택해 주세요' : fullAddress,
                  style: TextStyle(
                    color: _figmaBrown,
                    fontSize: healthSp(context, 12),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
                if (phone.isNotEmpty) ...[
                  SizedBox(height: healthDp(context, 4)),
                  Text(
                    phone,
                    style: TextStyle(
                      color: const Color(0xB2584045),
                      fontSize: healthSp(context, 14),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(top: healthDp(context, 10)),
                  padding: EdgeInsets.only(top: healthDp(context, 10)),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(width: 1, color: _figmaSectionBg),
                    ),
                  ),
                  child: Builder(
                    builder: (context) {
                      final memo = _memoController.text.trim();
                      final memoItems = [
                        ..._deliveryMemoPresets,
                        if (memo.isNotEmpty &&
                            !_deliveryMemoPresets.contains(memo))
                          memo,
                      ];
                      return DropdownBtn(
                        buttonHeight: healthDp(context, 40),
                        items: memoItems,
                        value: memo,
                        emptyText: '배송 요청 사항을 선택해 주세요',
                        emptyTextColor: _figmaDark,
                        valueTextColor: _figmaDark,
                        borderColor: _figmaBorder,
                        itemFontSizeBase: 12,
                        itemTextAlign: TextAlign.left,
                        onChanged: (value) {
                          setState(() => _memoController.text = value);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: healthDp(context, 8)),
          Text(
            '※ 영업일 기준 오후 2시 이전 처방완료 시 당일 발송',
            style: TextStyle(
              color: _figmaDark,
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderListSection(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 27),
        vertical: healthDp(context, 20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitleLarge(context, '결제 예정 목록'),
          SizedBox(height: healthDp(context, 16)),
          ...widget.cartItems.map((e) => _orderCard(context, e)),
        ],
      ),
    );
  }

  Widget _buildCouponSection(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 27),
        vertical: healthDp(context, 20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitleLarge(context, '쿠폰'),
          SizedBox(height: healthDp(context, 16)),
          if (_couponPointDisabled)
            Text(
              '인플루언서 상품 주문은 쿠폰/포인트 사용이 불가합니다.',
              style: TextStyle(
                color: _figmaBrown,
                fontSize: healthSp(context, 13),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w400,
              ),
            )
          else ...[
            _couponDropdown(context),
            SizedBox(height: healthDp(context, 5)),
            ..._selectedCoupons.map((c) => _selectedCouponRow(context, c)),
          ],
        ],
      ),
    );
  }

  Widget _buildPointSection(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        healthDp(context, 27),
        healthDp(context, 0),
        healthDp(context, 27),
        healthDp(context, 20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitleLarge(context, '포인트'),
          SizedBox(height: healthDp(context, 16)),
          if (_couponPointDisabled)
            Text(
              '인플루언서 상품 주문은 쿠폰/포인트 사용이 불가합니다.',
              style: TextStyle(
                color: _figmaBrown,
                fontSize: healthSp(context, 13),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w400,
              ),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Container(
                    height: healthDp(context, 34),
                    padding: EdgeInsets.symmetric(
                      horizontal: healthDp(context, 12),
                    ),
                    decoration: ShapeDecoration(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(
                            width: 1, color: _figmaBorder),
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 8)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _pointController,
                            enabled: !_couponPointDisabled,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: _figmaDark,
                              fontSize: healthSp(context, 14),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              isCollapsed: true,
                              border: InputBorder.none,
                              hintText: '0',
                              hintStyle: TextStyle(
                                color: _figmaBrown,
                                fontSize: healthSp(context, 14),
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          '점',
                          style: TextStyle(
                            color: _figmaBrown,
                            fontSize: healthSp(context, 12),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: healthDp(context, 8)),
                InkWell(
                  onTap: _couponPointDisabled
                      ? null
                      : () {
                          setState(() {
                            _useAllPoints = true;
                            _usedPoint = _maxUsablePointHundreds;
                            _pointController.text = _usedPoint == 0
                                ? ''
                                : '$_usedPoint';
                          });
                        },
                  borderRadius:
                      BorderRadius.circular(healthDp(context, 8)),
                  child: Container(
                    height: healthDp(context, 34),
                    padding: EdgeInsets.symmetric(
                      horizontal: healthDp(context, 12),
                    ),
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        side:
                            const BorderSide(width: 1, color: _figmaPink),
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 8)),
                      ),
                    ),
                    child: Text(
                      '모두 사용',
                      style: TextStyle(
                        color: _figmaPink,
                        fontSize: healthSp(context, 12),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.26,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: healthDp(context, 8)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '보유 포인트',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: healthSp(context, 12),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
                Text(
                  '${PointService.formatPoint(_myPoint)} 점',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            SizedBox(height: healthDp(context, 8)),
            Text(
              '* 포인트는 100점 단위로 사용 가능합니다.',
              style: TextStyle(
                color: const Color(0x99584045),
                fontSize: healthSp(context, 11),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentAmountSection(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 27),
        vertical: healthDp(context, 20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitleLarge(context, '결제 금액'),
          SizedBox(height: healthDp(context, 16)),
          _amountRow(context, '구매금액',
              '${PriceFormatter.format(_purchaseAmount)} 원'),
          if (_couponDiscount > 0)
            _amountRow(
              context,
              '쿠폰할인',
              _discountAmountText(_couponDiscount),
              valueColor: _figmaPink,
            ),
          if (_pointDiscount > 0)
            _amountRow(
              context,
              '포인트할인',
              _discountAmountText(_pointDiscount),
              valueColor: _figmaPink,
            ),
          _amountRow(context, '배송비',
              '${PriceFormatter.format(widget.shippingCost)} 원'),
          Container(
            width: double.infinity,
            padding: EdgeInsets.only(top: healthDp(context, 16)),
            margin: EdgeInsets.only(top: healthDp(context, 8)),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(width: 1, color: _figmaBorder)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '총 결제비용',
                  style: TextStyle(
                    color: _figmaPink,
                    fontSize: healthSp(context, 16),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${PriceFormatter.format(_finalAmount)}원',
                  style: TextStyle(
                    color: _figmaDark,
                    fontSize: healthSp(context, 16),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: healthDp(context, 5)),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                '예상 적립 포인트: ${PointService.formatPoint(_expectedPoint)} 점',
                style: TextStyle(
                  color: const Color(0xFF1A1A1E),
                  fontSize: healthSp(context, 10),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodHeaderSection(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 27),
        vertical: healthDp(context, 20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitleLarge(context, '결제 수단'),
          SizedBox(height: healthDp(context, 16)),
          Row(
            children: [
              Expanded(child: _methodButton(context, '신용카드', 0)),
              SizedBox(width: healthDp(context, 12)),
              Expanded(child: _methodButton(context, '계좌이체', 1)),
              SizedBox(width: healthDp(context, 12)),
              Expanded(child: _methodButton(context, '가상계좌', 2)),
            ],
          ),
          SizedBox(height: healthDp(context, 16)),
          Text(
            '※ 최소 결제금액은 3,000원입니다.',
            style: TextStyle(
              color: const Color(0xFF1A1A1E),
              fontSize: healthSp(context, 10),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
            ),
          ),
          SizedBox(height: healthDp(context, 5)),
          Text(
            '※ 할부 결제는 일반카드 결제만 가능합니다.',
            style: TextStyle(
              color: const Color(0xFF1A1A1E),
              fontSize: healthSp(context, 10),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountRow(
    BuildContext context,
    String left,
    String right, {
    Color? valueColor,
  }) {
    final color = valueColor ?? _figmaBrown;
    return Padding(
      padding: EdgeInsets.only(bottom: healthDp(context, 8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            left,
            style: TextStyle(
              color: Colors.black,
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
            ),
          ),
          Text(
            right,
            style: TextStyle(
              color: color,
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ),
    );
  }

  Widget _title(BuildContext context, String text) => Text(
        text,
        style: TextStyle(
          color: _pink,
          fontSize: healthSp(context, 14),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        ),
      );

  String _formatPostalCodeDisplay(String postalCode) {
    final t = postalCode.replaceAll(RegExp(r'[^0-9]'), '');
    if (t.length == 5) {
      return '${t.substring(0, 3)}-${t.substring(3)}';
    }
    return postalCode.trim();
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

  Widget _zipSearchRow(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: healthDp(context, 10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabelWithPinkAsterisk(context, '우편번호*'),
          SizedBox(height: healthDp(context, 6)),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: _fieldH(context),
                  child: TextField(
                    controller: _zipController,
                    readOnly: true,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: healthDp(context, 10),
                        vertical: healthDp(context, 10),
                      ),
                      hintText: '\'주소 검색\' 클릭',
                      hintStyle: TextStyle(
                        color: _muted,
                        fontSize: healthSp(context, 12),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 10)),
                        borderSide: const BorderSide(color: _border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 10)),
                        borderSide: const BorderSide(color: _border),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: healthDp(context, 8)),
              SizedBox(
                height: _fieldH(context),
                child: OutlinedButton(
                  onPressed: _openAddressSearch,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _pink,
                    side: BorderSide(color: _pink, width: healthDp(context, 1)),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 10)),
                    ),
                    minimumSize: Size(0, _fieldH(context)),
                    fixedSize: Size.fromHeight(_fieldH(context)),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.symmetric(
                      horizontal: healthDp(context, 12),
                      vertical: 0,
                    ),
                  ),
                  child: Text(
                    '주소 검색',
                    style: TextStyle(
                      fontSize: healthSp(context, 12),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 라벨이 `*`로 끝나면 별만 핑크(웹 등에서 TextSpan 색 병합 이슈 회피용 WidgetSpan).
  Widget _fieldLabelWithPinkAsterisk(BuildContext context, String label) {
    final baseStyle = TextStyle(
      color: _ink,
      fontSize: healthSp(context, 12),
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: FontWeight.w500,
    );
    if (!label.endsWith('*')) {
      return Text(label, style: baseStyle);
    }
    final body = label.substring(0, label.length - 1);
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          TextSpan(text: body),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Text(
              '*',
              style: baseStyle.copyWith(color: const Color(0xFFFF5A8D)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footnoteWithPinkLeadingAsterisk(
      BuildContext context, String afterStar) {
    final baseStyle = TextStyle(
      color: Colors.black,
      fontSize: healthSp(context, 8),
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: FontWeight.w300,
    );
    return Text.rich(
      TextSpan(
        style: baseStyle,
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Text(
              '*',
              style: baseStyle.copyWith(color: const Color(0xFFFF5A8D)),
            ),
          ),
          TextSpan(text: afterStar),
        ],
      ),
    );
  }

  Widget _inputField(
    BuildContext context,
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: healthDp(context, 10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabelWithPinkAsterisk(context, label),
          SizedBox(height: healthDp(context, 6)),
          SizedBox(
            height: _fieldH(context),
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: healthDp(context, 10),
                  vertical: healthDp(context, 10),
                ),
                hintText: hint,
                hintStyle: TextStyle(
                  color: _muted,
                  fontSize: healthSp(context, 12),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w300,
                ),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(healthDp(context, 10)),
                  borderSide: const BorderSide(color: _border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(healthDp(context, 10)),
                  borderSide: const BorderSide(color: _border),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 주문 카드 - 결제 예정 목록 카드드
  Widget _orderCard(BuildContext context, CartItem item) {
    final reservationLine = _buildReservationLine(context, item);
    final thumb = healthDp(context, 80);

    return Container(
      margin: EdgeInsets.only(bottom: healthDp(context, 16)),
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 8)),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: _figmaBorder),
          borderRadius: BorderRadius.circular(healthDp(context, 12)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(healthDp(context, 8)),
            child: Image.network(
              _itemImageUrl(item),
              width: thumb,
              height: thumb,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: thumb,
                height: thumb,
                color: Colors.grey.shade200,
              ),
            ),
          ),
          SizedBox(width: healthDp(context, 16)),
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: healthDp(context, 4)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.itName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF1A1A1E),
                      fontSize: healthSp(context, 14),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 4)),
                  _buildOrderMetaColumn(context, item),
                  if (reservationLine != null) ...[
                    SizedBox(height: healthDp(context, 6)),
                    reservationLine,
                  ],
                  SizedBox(height: healthDp(context, 6)),
                  Text(
                    '${PriceFormatter.format(item.ctPrice)}원',
                    style: TextStyle(
                      color: const Color(0xFF1A1A1E),
                      fontSize: healthSp(context, 12),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle _orderMetaTextStyle(BuildContext context) => TextStyle(
        color: const Color(0xFF898383),
        fontSize: healthSp(context, 10),
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: FontWeight.w500,
        letterSpacing: healthSp(context, -0.90),
      );

  Widget _buildOrderMetaColumn(BuildContext context, CartItem item) {
    final optionParts = item.ctOption
        .split(' / ')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final metaStyle = _orderMetaTextStyle(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (optionParts.isNotEmpty)
          Text(optionParts.join(' | '), style: metaStyle),
        if (optionParts.isNotEmpty) SizedBox(height: healthDp(context, 4)),
        Text('수량: ${item.ctQty}', style: metaStyle),
      ],
    );
  }

  Widget? _buildReservationLine(BuildContext context, CartItem item) {
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
        Text(
          '진료 예약시간 :',
          style: TextStyle(
            color: const Color(0xFF1A1A1A),
            fontSize: healthSp(context, 10),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
            letterSpacing: -0.81,
          ),
        ),
        SizedBox(width: healthDp(context, 2)),
        Expanded(
          child: Text(
            reservationText,
            style: TextStyle(
              color: const Color(0xFFFF5A8D),
              fontSize: healthSp(context, 10),
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

  List<Coupon> _availableCouponsByMethod(int method) {
    if (_couponPointDisabled) return const [];
    return _applicableCoupons
        .where((coupon) => coupon.method == method)
        .where((coupon) =>
            !_selectedCoupons.any((selected) => selected.no == coupon.no))
        .toList();
  }

  void _onCouponChosenByMethod(int method, String label) {
    final candidates = _availableCouponsByMethod(method);
    final lines = _uniqueCouponPickerLines(candidates);
    final index = lines.indexOf(label);
    if (index < 0 || index >= candidates.length) return;
    final picked = candidates[index];

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
    const displayOrder = [1, 0, 2, 3];
    final sections = <Widget>[];
    for (final method in displayOrder) {
      final candidates = _availableCouponsByMethod(method);
      final lines = _uniqueCouponPickerLines(candidates);
      if (lines.isEmpty) continue;
      if (_isCouponMethodDisabled(method)) continue;

      final selectedByMethod =
          _selectedCoupons.where((coupon) => coupon.method == method).length;
      final canAdd = method != 1 || selectedByMethod < 2;
      if (!canAdd) continue;

      if (sections.isNotEmpty) {
        sections.add(SizedBox(height: healthDp(context, 8)));
      }
      sections.add(_couponMethodSection(context, method));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  Widget _couponMethodSection(BuildContext context, int method) {
    final candidates = _availableCouponsByMethod(method);
    final lines = _uniqueCouponPickerLines(candidates);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _couponMethodTitle(method),
          style: TextStyle(
            color: Colors.black,
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
            letterSpacing: 0.26,
          ),
        ),
        SizedBox(height: healthDp(context, 5)),
        DropdownBtn(
          buttonHeight: healthDp(context, 40),
          enabled: true,
          items: lines,
          value: '',
          emptyText: '쿠폰 선택',
          emptyTextColor: _figmaBrown,
          valueTextColor: _figmaDark,
          borderColor: _figmaRoseBorder,
          itemFontSizeBase: 12,
          itemTextAlign: TextAlign.left,
          onChanged: (label) => _onCouponChosenByMethod(method, label),
        ),
      ],
    );
  }

  String _couponMethodTitle(int method) {
    switch (method) {
      case 0:
        return '상품쿠폰';
      case 1:
        return '카테고리쿠폰';
      case 2:
        return '주문할인쿠폰';
      case 3:
        return '배송비쿠폰';
      default:
        return '쿠폰';
    }
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

  String _discountAmountText(int amount) {
    if (amount <= 0) {
      return '${PriceFormatter.format(amount)} 원';
    }
    return '-${PriceFormatter.format(amount)} 원';
  }

  Widget _summaryRow(BuildContext context, String left, String right) {
    return Padding(
      padding: EdgeInsets.only(bottom: healthDp(context, 6)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            left,
            style: TextStyle(
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
              color: _ink,
            ),
          ),
          Text(
            right,
            style: TextStyle(
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _strongRow(BuildContext context, String left, String right) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          left,
          style: TextStyle(
            color: _pink,
            fontSize: healthSp(context, 14),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          right,
          style: TextStyle(
            color: _ink,
            fontSize: healthSp(context, 16),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
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
        padding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 12),
          vertical: healthDp(context, 16),
        ),
        decoration: ShapeDecoration(
          color: selected ? const Color(0x0CFF5B8C) : Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: healthDp(context, selected ? 2 : 1),
              color: selected ? _figmaPink : _figmaBorder,
            ),
            borderRadius: BorderRadius.circular(healthDp(context, 12)),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: healthDp(context, 48),
              height: healthDp(context, 48),
              decoration: ShapeDecoration(
                color: selected ? _figmaPink : Colors.white,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    width: healthDp(context, selected ? 0 : 1),
                    color: _figmaBorder,
                  ),
                  borderRadius: BorderRadius.circular(healthDp(context, 9999)),
                ),
              ),
              child: Center(
                child: SvgPicture.asset(
                  iconAsset,
                  width: iconSz,
                  height: iconSz,
                  colorFilter: ColorFilter.mode(
                    selected ? Colors.white : _figmaBrown,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ),
            SizedBox(height: healthDp(context, 8)),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? _figmaPink : _figmaBrown,
                fontSize: healthSp(context, 12),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: selected ? FontWeight.w500 : FontWeight.w300,
                letterSpacing: 0.26,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _escrowToggle(
      BuildContext context, String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(healthDp(context, 8)),
      child: Container(
        height: healthDp(context, 36),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0x0CFF5A8D) : Colors.white,
          border: Border.all(color: selected ? _pink : _border),
          borderRadius: BorderRadius.circular(healthDp(context, 8)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _pink : _ink,
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _escrowNotice(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 10)),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: const Color(0xFFF1F1F1),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: healthDp(context, 74),
            height: healthDp(context, 74),
            child: Image.asset(
              AppAssets.escrow,
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
                    color: Colors.black,
                    fontSize: healthSp(context, 10),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: healthDp(context, 5)),
                Text(
                  '고객님은 안전거래를 위해 현금 등으로 결제시 저희 쇼핑몰에 가입한 KCP의 구매안전서비스를 이용하실 수 있습니다.\n계좌이체 또는 가상계좌 등 현금 거래에만 해당(에스크로 결제를 선택했을경우에만 해당)되며, 신용카드로 구매하는 거래에는 해당되지 않습니다.',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: healthSp(context, 8),
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
