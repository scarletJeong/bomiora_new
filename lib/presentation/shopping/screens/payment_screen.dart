import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../health/health_common/widgets/health_app_bar.dart';
import '../../common/widgets/dropdown_btn.dart';
import '../../common/widgets/delivery_memo_dropdown.dart';
import '../../common/widgets/app_toast_overlay.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../../core/utils/kcp_pay_session_store.dart';
import '../../../core/utils/web_kcp_popup.dart';
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
import '../../../data/services/cart_service.dart';
import '../../../data/services/coupon_service.dart';
import '../../../data/services/delivery_service.dart';
import '../../../data/services/point_service.dart';
import '../../user/delivery/widgets/delivery_address_change_popup_ver2.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../widgets/payment_product_card.dart';
import '../widgets/prescription_booking_progress_bar.dart';
import 'kcp_pay_webview_screen.dart';

part 'payment_coupon.dart';
part 'payment_point.dart';
part 'payment_delivery.dart';
part 'payment_checkout.dart';
part 'payment_sections.dart';

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

const _pink = Color(0xFFFF5A8D);
const _muted = Color(0xFF898686);
const _border = Color(0xFFD2D2D2);
const _figmaBrown = Color(0xFF584045);
const _figmaDark = Color(0xFF1A1B1F);
const int _minPayableAmount = 3000;
const double _kDeliveryFieldHeight = 45;
const Color _kDeliveryFieldFill = Color(0xFFF8FAFC);

class _PaymentScreenState extends State<PaymentScreen> {
  final TextEditingController _pointController = TextEditingController();

  final TextEditingController _addressNameController = TextEditingController();

  final TextEditingController _receiverController = TextEditingController();

  final TextEditingController _phoneController = TextEditingController();

  final TextEditingController _zipController = TextEditingController();

  final TextEditingController _addressController = TextEditingController();

  final TextEditingController _detailAddressController =
      TextEditingController();

  String _deliveryMemo = '';

  bool _deliveryMemoCustomSelected = false;

  bool _loading = true;

  bool _submitting = false;

  bool _syncingPoint = false;

  bool _useEscrow = false;

  final ValueNotifier<double> _scrollProgress = ValueNotifier(0);

  int _paymentMethodIndex = 0; // 0 card, 1 bank transfer, 2 virtual account

  int _myPoint = 0;

  int _usedPoint = 0;

  int _baseShipping = 0;

  int _extraShipping = 0;

  double _pointRate = 1;

  int _shippingQuoteGen = 0;

  List<Coupon> _loadedCoupons = [];

  List<Coupon> _applicableCoupons = [];

  List<Coupon> _selectedCoupons = [];

  Map<String, dynamic>? _defaultAddress;


  /// 기본 배송지 없을 때: 배송지명 칩 (집/회사/직접입력)
  String _addressLabelChip = '집';

  bool _saveAsDefault = false;

  bool _showCustomAddressName = false;


  void _setState(VoidCallback fn) => setState(fn);

  @override
  void initState() {
    super.initState();
    // 진입 shippingCost는 임시값. 주소·장바구니 견적(_loadShippingQuote)이 정본이다.
    _baseShipping = widget.shippingCost < 0 ? 0 : widget.shippingCost;
    _pointController.addListener(_onPointChanged);
    prefetchKcpPayScripts();
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
    _scrollProgress.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final user = await AuthService.getUser();
      if (user == null || user.id.isEmpty) {
        if (!mounted) return;
        setState(() => _loading = false);
        return;
      }

      if (widget.prefetch != null) {
        await _applyPrefetch(user, widget.prefetch!);
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
      await _finishCheckoutLoad(
        user: user,
        address: defaultAddress.isEmpty ? null : defaultAddress,
        point: point,
        coupons: coupons,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      AppToastOverlay.show(context, '주문 정보를 불러오지 못했습니다.');
    }
  }

  Future<void> _applyPrefetch(UserModel user, PaymentPrefetchData prefetch) async {
    if (!mounted) return;
    final defaultAddress = prefetch.addresses.firstWhere(
      (e) => e['adDefault'] == 1,
      orElse: () => prefetch.addresses.isNotEmpty
          ? prefetch.addresses.first
          : <String, dynamic>{},
    );
    await _finishCheckoutLoad(
      user: user,
      address: defaultAddress.isEmpty ? null : defaultAddress,
      point: prefetch.point,
      coupons: prefetch.coupons,
    );
  }


  /// 배송비 견적이 끝난 뒤에 쿠폰 목록과 총액을 연다.
  /// 견적 전에 화면을 열면 3만원 이하 배송비·배송비 쿠폰이 빠진다.
  Future<void> _finishCheckoutLoad({
    required UserModel user,
    required Map<String, dynamic>? address,
    required int point,
    required List<Coupon> coupons,
  }) async {
    if (!mounted) return;
    setState(() {
      _defaultAddress = address;
      _myPoint = point;
      _loadedCoupons = coupons;
      _applyAddressMode(refreshShipping: false);
      if (address == null) {
        _saveAsDefault = true;
        if (_receiverController.text.trim().isEmpty) {
          _receiverController.text = user.name;
        }
        if (_phoneController.text.trim().isEmpty &&
            (user.phone ?? '').trim().isNotEmpty) {
          _phoneController.text =
              (user.phone ?? '').replaceAll(RegExp(r'[^0-9]'), '');
        }
        _addressNameController.text = _addressLabelChip;
      }
    });
    await _loadShippingQuote(retryIfZero: true);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.white,
      appBar: HealthAppBar(
        title: widget.showPrescriptionBookingProgress
            ? '진료예약 중 _ 03 주문/결제'
            : '주문/결제',
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
      child: _loading
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
                        style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
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
}
