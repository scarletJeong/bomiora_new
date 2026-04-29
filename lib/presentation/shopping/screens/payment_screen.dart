import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:convert';

import '../../common/widgets/app_bar.dart';
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

/// 서버에서 내려오는 KCP 결제 모듈(라이브러리) 미설치 등 메시지 — 스낵바로는 띄우지 않음.
bool _isKcpLibraryMissingServerMessage(String text) {
  final c = text.toLowerCase().replaceAll(RegExp(r'\s+'), '');
  return c.contains('kcp') &&
      c.contains('라이브러리') &&
      c.contains('찾을수없');
}

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
  static const double _fieldHeight = 40;

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
  bool _useDefaultAddress = true;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('배송지 필수 항목을 입력해 주세요.')),
      );
      return false;
    }
    if (_finalAmount < _minPayableAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('최소 결제 금액은 3,000원입니다.')),
      );
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
    if (kIsWeb && webPendingPopup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('팝업이 차단되었습니다. 팝업 허용 후 다시 시도해 주세요.')),
      );
      return;
    }

    final user = await AuthService.getUser();
    if (user == null || user.id.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 정보가 없습니다. 다시 로그인해 주세요.')),
      );
      return;
    }

    final cartIds = widget.cartItems.map((e) => e.ctId).toList();
    if (cartIds.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('결제할 장바구니 항목이 없습니다.')),
      );
      return;
    }

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('새 탭에서 결제를 진행해 주세요. 완료 후 결과를 자동 확인합니다.'),
            action: SnackBarAction(
              label: '결제창 다시열기',
              onPressed: _reopenWebKcpLaunch,
            ),
          ),
        );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message.isEmpty ? '결제가 완료되었습니다.' : message)),
        );
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
        if (!_isKcpLibraryMissingServerMessage(message)) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message.isEmpty ? '결제가 완료되지 않았습니다.' : message),
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      final errText = e.toString();
      if (!_isKcpLibraryMissingServerMessage(errText)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('결제 처리 중 오류가 발생했습니다: $e')),
        );
      }
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
    final opened = openKcpUrlInNewTab(url);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('결제창 재열기에 실패했습니다. 팝업 허용 상태를 확인해 주세요.')),
      );
    }
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
                            child:
                                _modeButton('신규배송지', !_useDefaultAddress, () {
                              setState(() {
                                _useDefaultAddress = false;
                                _applyAddressMode();
                              });
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _inputField(
                          '배송지명', _addressNameController, '배송지명을 입력해 주세요.'),
                      _inputField(
                          '수령인*', _receiverController, '수령인의 이름을 입력해 주세요.'),
                      _inputField(
                          '핸드폰 번호*', _phoneController, '\'-\'없이 기입해주세요.'),
                      _zipSearchRow(),
                      _inputField(
                          '주소*', _addressController, '\'주소 검색\'을 통하여 입력됩니다.'),
                      _inputField('상세 주소*', _detailAddressController,
                          '상세 주소를 입력해 주세요.'),
                      _inputField('배송 요청 사항', _memoController,
                          '배송 관련 요청 사항이 있으시면 입력해 주세요.'),
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
                      const Divider(
                          height: 1, thickness: 1.5, color: Color(0xFFD9D9D9)),
                      const SizedBox(height: 12),
                      _title('결제 예정 목록'),
                      const SizedBox(height: 10),
                      ...widget.cartItems.map(_orderCard),
                      const SizedBox(height: 20),
                      const Divider(
                          height: 1, thickness: 1.5, color: Color(0xFFD9D9D9)),
                      const SizedBox(height: 12),
                      _title('쿠폰 선택'),
                      const SizedBox(height: 8),
                      if (_couponPointDisabled)
                        const Text(
                          '인플루언서 상품 주문은 쿠폰/포인트 사용이 불가합니다.',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 11,
                            fontFamily: 'Gmarket Sans TTF',
                          ),
                        )
                      else
                        _couponDropdown(),
                      const SizedBox(height: 8),
                      ..._selectedCoupons.map((c) => _selectedCouponRow(c)),
                      const SizedBox(height: 20),
                      const Divider(
                          height: 1, thickness: 1.5, color: Color(0xFFD9D9D9)),
                      const SizedBox(height: 12),
                      _title('포인트'),
                      const SizedBox(height: 8),
                      _summaryRow(
                          '보유 포인트', '${PointService.formatPoint(_myPoint)} 점'),
                      _summaryRow('최대 사용 가능 포인트',
                          '${PointService.formatPoint(_maxUsablePointHundreds)} 점'),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 137.08,
                              child: Row(
                                children: [
                                  Text(
                                    '포인트 사용',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 12,
                                      fontFamily: 'Gmarket Sans TTF',
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    '(100점단위)',
                                    style: TextStyle(
                                      color: _muted,
                                      fontSize: 12,
                                      fontFamily: 'Gmarket Sans TTF',
                                      fontWeight: FontWeight.w300,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 80,
                              height: 32,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 10),
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
                                      enabled: !_couponPointDisabled,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
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
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: const VisualDensity(
                                  horizontal: -4, vertical: -4),
                              activeColor: _pink,
                              onChanged: _couponPointDisabled
                                  ? null
                                  : (checked) {
                                      final all = checked ?? false;
                                      setState(() {
                                        _useAllPoints = all;
                                        _usedPoint = all ? _maxUsablePointHundreds : 0;
                                        _pointController.text = _usedPoint == 0
                                            ? ''
                                            : '$_usedPoint';
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
                      const Divider(
                          height: 1, thickness: 1.5, color: Color(0xFFD9D9D9)),
                      const SizedBox(height: 12),
                      _title('결제 금액'),
                      const SizedBox(height: 8),
                      _summaryRow('구매금액',
                          '${PriceFormatter.format(_purchaseAmount)} 원'),
                      _summaryRow('쿠폰할인',
                          _discountAmountText(_couponDiscount)),
                      _summaryRow('포인트할인',
                          _discountAmountText(_pointDiscount)),
                      _summaryRow('배송비',
                          '${PriceFormatter.format(widget.shippingCost)} 원'),
                      const SizedBox(height: 6),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFD9D9D9),
                      ),
                      const SizedBox(height: 15),
                      _strongRow(
                          '총 결제비용', '${PriceFormatter.format(_finalAmount)}원'),
                      const SizedBox(height: 15),
                      const Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0xFFD9D9D9),
                      ),
                      const SizedBox(height: 10),
                      _summaryRow('예상 적립 포인트',
                          '${PointService.formatPoint(_expectedPoint)} 점'),
                      _footnoteWithPinkLeadingAsterisk(
                          '상품별 포인트 설정 기준 예상 적립'),
                      
                      const SizedBox(height: 20),
                      const Divider(
                          height: 1, thickness: 1.5, color: Color(0xFFD9D9D9)),
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
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '※ 할부 결제는 일반카드 결제만 가능합니다.',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              '※ 최소 결제금액은 3,000원입니다.',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_paymentMethodIndex == 1 ||
                          _paymentMethodIndex == 2) ...[
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
                        const SizedBox(height: 4),
                        const Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '2006.4.1 제정, 2013.11.29 개정 전자상거래 등에서의 소비자 보호에 관한 법률',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 6.82,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: _submitting ? null : _requestKcpPayment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _pink,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                )
                              : const Text('결제하기'),
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

  Widget _zipSearchRow() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabelWithPinkAsterisk('우편번호*'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: _fieldHeight,
                  child: TextField(
                    controller: _zipController,
                    readOnly: true,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 10),
                      hintText: '\'주소 검색\' 클릭',
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
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: _fieldHeight,
                child: OutlinedButton(
                  onPressed: _openAddressSearch,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _pink,
                    side: const BorderSide(color: _pink, width: 1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    minimumSize: const Size(0, _fieldHeight),
                    fixedSize: const Size.fromHeight(_fieldHeight),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  ),
                  child: const Text(
                    '주소 검색',
                    style: TextStyle(
                      fontSize: 12,
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
  Widget _fieldLabelWithPinkAsterisk(String label) {
    const baseStyle = TextStyle(
      color: _ink,
      fontSize: 12,
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

  Widget _footnoteWithPinkLeadingAsterisk(String afterStar) {
    const baseStyle = TextStyle(
      color: Colors.black,
      fontSize: 8,
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
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabelWithPinkAsterisk(label),
          const SizedBox(height: 6),
          SizedBox(
            height: _fieldHeight,
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
                      if (reservationLine != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          height: 0.5,
                          color: Color(0xFFD2D2D2),
                        ),
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
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('카테고리 쿠폰은 최대 2개까지 선택할 수 있습니다.')),
          );
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

  Widget _couponDropdown() {
    const displayOrder = [1, 0, 2, 3];
    return Column(
      children: [
        for (final method in displayOrder) ...[
          _couponMethodSection(method),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _couponMethodSection(int method) {
    final candidates = _availableCouponsByMethod(method);
    final lines = _uniqueCouponPickerLines(candidates);
    final disabled = _isCouponMethodDisabled(method);
    final selectedByMethod =
        _selectedCoupons.where((coupon) => coupon.method == method).length;
    final canAdd =
        !disabled && lines.isNotEmpty && (method != 1 || selectedByMethod < 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _couponMethodTitle(method),
          style: const TextStyle(
            color: _ink,
            fontSize: 12,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 6),
        DropdownBtn(
          buttonHeight: 44,
          enabled: canAdd,
          items: lines,
          value: '',
          emptyText: disabled
              ? '다른 종류 쿠폰 사용 중'
              : (lines.isEmpty ? '선택 가능한 쿠폰 없음' : '쿠폰 선택'),
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
              Padding(
                padding: const EdgeInsets.only(top: 1, right: 6),
                child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedCoupons.removeWhere((c) => c.no == coupon.no);
                    if (_usedPoint > _maxUsablePointHundreds) {
                      _usedPoint = _maxUsablePointHundreds;
                      _pointController.text = _usedPoint == 0 ? '' : '$_usedPoint';
                    }
                  });
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Color(0xFFEFEFEF),
                    borderRadius: BorderRadius.circular(6),
                  ),
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
              ),
            ],
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

  Widget _summaryRow(String left, String right) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            left,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
              color: _ink,
            ),
          ),
          Text(
            right,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
              color: _ink,
            ),
          ),
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

  Widget _methodButton(String label, int index) {
    final selected = _paymentMethodIndex == index;
    final iconAsset = _paymentMethodIconAsset(index);
    final iconColor = selected ? Colors.white : _ink;
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              iconAsset,
              width: 28,
              height: 28,
              colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : _ink,
                fontSize: 12,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: selected ? FontWeight.w700 : FontWeight.w300,
              ),
            ),
          ],
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
          SizedBox(
            width: 74,
            height: 74,
            child: Image.asset(
              AppAssets.escrow,
              fit: BoxFit.contain,
            ),
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
