import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/health_profile_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../user/healthprofile/models/health_profile_model.dart';
import '../../../user/healthprofile/health_profile_payload.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/content_popup.dart';
import '../../../../core/network/api_client.dart';
import '../../../../data/models/cart/cart_item_model.dart';
import '../../../../core/navigation/app_navigator_key.dart';
import '../../screens/payment_screen.dart';

/// 연락처 입력 화면 (개인정보)
class PrescriptionContactScreen extends StatefulWidget {
  final String productId;
  final String productName;
  final dynamic selectedOptions; // List<Map<String, dynamic>> 또는 Map<String, dynamic>? (하위 호환성)
  final Map<String, dynamic> formData;
  final HealthProfileModel? existingProfile;
  final DateTime selectedDate;
  final String selectedTime;
  final List<int>? cartCtIdsForCheckout;
  final List<CartItem>? checkoutCartItems;
  final int? checkoutShippingCost;

  const PrescriptionContactScreen({
    super.key,
    required this.productId,
    required this.productName,
    this.selectedOptions,
    required this.formData,
    this.existingProfile,
    required this.selectedDate,
    required this.selectedTime,
    this.cartCtIdsForCheckout,
    this.checkoutCartItems,
    this.checkoutShippingCost,
  });

  @override
  State<PrescriptionContactScreen> createState() => _PrescriptionContactScreenState();
}

class _PrescriptionContactScreenState extends State<PrescriptionContactScreen> {
  UserModel? _currentUser;
  bool _isLoading = false;
  bool _agreedRefundPolicy = false;
  Map<String, dynamic>? _reservationData; // 장바구니 데이터 임시 저장
  
  @override
  void initState() {
    super.initState();
    _loadUser();
  }
  
  Future<void> _loadUser() async {
    final user = await AuthService.getUser();
    if (!mounted) return;
    setState(() => _currentUser = user);
  }
  
  Future<void> _submitBooking() async {
    if (_currentUser == null) {
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      // 옵션 정보 처리 (리스트 또는 단일 Map)
      List<Map<String, dynamic>> optionsList = [];
      if (widget.selectedOptions is List) {
        optionsList = List<Map<String, dynamic>>.from(widget.selectedOptions as List);
      } else if (widget.selectedOptions is Map) {
        optionsList = [Map<String, dynamic>.from(widget.selectedOptions as Map)];
      }
      
      // 1. 건강 프로필 저장
      final profile = HealthProfileModel(
        pfNo: widget.existingProfile?.pfNo,
        mbId: _currentUser!.id,
        answer1: widget.formData['birthDate'] ?? '',
        answer2: widget.formData['gender'] ?? '',
        answer3: widget.formData['targetWeight'] ?? '',
        answer4: widget.formData['height'] ?? '',
        answer5: widget.formData['currentWeight'] ?? '',
        answer6: widget.formData['dietPeriod'] ?? '',
        answer7: widget.formData['mealsPerDay'] ?? '',
        answer71: widget.formData['mealTimes'] ?? '|||',
        answer8: HealthProfilePayload.formatListToString(widget.formData['eatingHabits']),
        answer9: HealthProfilePayload.formatListToString(widget.formData['foodPreference']),
        answer10: HealthProfilePayload.composeAnswer10FrequencyOnly(
          widget.formData['exerciseFrequency']?.toString(),
        ),
        answer102: HealthProfilePayload.composeAnswer10TypesOnly(
          widget.formData['exerciseTypes'],
        ),
        answer11: HealthProfilePayload.formatListToString(widget.formData['diseases']),
        answer12: HealthProfilePayload.formatAnswer12(
          widget.formData['medications'],
          widget.formData['medicationsEtc']?.toString(),
        ),
        answer13: HealthProfilePayload.encodeAnswer13ForApi(
          widget.formData['dietExperience']?.toString(),
        ),
        answer13Medicine: widget.formData['dietMedicine'] ?? '',
        answer13Period: widget.formData['dietPeriodMonths'] ?? '',
        answer13Dosage: widget.formData['dietDosage'] ?? '',
        answer13Sideeffect: widget.formData['dietSideEffect'] ?? '',
        pfWdatetime: widget.existingProfile?.pfWdatetime ?? DateTime.now(),
        pfMdatetime: DateTime.now(),
        pfIp: '0.0.0.0',
        pfMemo: '',
      );
      
      await HealthProfileService.saveHealthProfile(profile);
      
      // 2. 예약 정보 준비 (여러 옵션을 리스트로 저장)
      final odId = DateTime.now().millisecondsSinceEpoch;
      
      // 여러 옵션을 리스트로 저장 (각 옵션마다 장바구니에 추가할 때 사용)
      _reservationData = {
        'mb_id': _currentUser!.id,
        'it_id': widget.productId,
        'od_id': odId,
        'options': optionsList, // 여러 옵션 리스트
        // 첫 번째 옵션 정보 (하위 호환성)
        'option_id': optionsList.isNotEmpty ? optionsList[0]['id'] : null,
        'option_text': optionsList.isNotEmpty ? optionsList[0]['name'] : null,
        'option_price': optionsList.isNotEmpty ? optionsList[0]['price'] : null,
        'quantity': optionsList.isNotEmpty ? optionsList[0]['quantity'] : 1,
        'price': optionsList.isNotEmpty ? optionsList[0]['totalPrice'] : 0,
        // 건강 프로필
        'answer1': widget.formData['birthDate'] ?? '',
        'answer2': widget.formData['gender'] ?? '',
        'answer3': widget.formData['targetWeight'] ?? '',
        'answer4': widget.formData['height'] ?? '',
        'answer5': widget.formData['currentWeight'] ?? '',
        'answer6': widget.formData['dietPeriod'] ?? '',
        'answer7': widget.formData['mealsPerDay'] ?? '',
        'answer71': widget.formData['mealTimes'] ?? '|||',
        'answer8': HealthProfilePayload.formatListToString(widget.formData['eatingHabits']),
        'answer9': HealthProfilePayload.formatListToString(widget.formData['foodPreference']),
        'answer10': HealthProfilePayload.composeAnswer10(
          widget.formData['exerciseFrequency']?.toString(),
          widget.formData['exerciseTypes'],
        ),
        'answer11': HealthProfilePayload.formatListToString(widget.formData['diseases']),
        'answer12': HealthProfilePayload.formatAnswer12(
          widget.formData['medications'],
          widget.formData['medicationsEtc']?.toString(),
        ),
          'answer13': HealthProfilePayload.encodeAnswer13ForApi(
          widget.formData['dietExperience']?.toString(),
        ),
        'answer13Period': widget.formData['dietPeriodMonths'] ?? '',
        'answer13Dosage': widget.formData['dietDosage'] ?? '',
        'answer13Medicine': widget.formData['dietMedicine'] ?? '',
        'answer13Sideeffect': widget.formData['dietSideEffect'] ?? '',
        'pfMemo': '',
        // 예약 정보
        'reservationDate': widget.selectedDate.toIso8601String(),
        'reservationTime': widget.selectedTime,
        'reservationName': _currentUser!.name,
        'reservationTel': _currentUser!.phone,
        'doctorName': '',
      };
      
      if (!mounted) return;
      
      // 3. 연락처 확인 다이얼로그 표시
      _showCompletionDialog();
      
    } catch (e) {
      // ignored
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _showNavigationFallback() {}

  String _formatPhoneForDialog(String? raw) {
    final digits = (raw ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11) {
      return '${digits.substring(0, 3)} - ${digits.substring(3, 7)} - ${digits.substring(7)}';
    }
    if (digits.length == 10) {
      return '${digits.substring(0, 3)} - ${digits.substring(3, 6)} - ${digits.substring(6)}';
    }
    if (raw != null && raw.trim().isNotEmpty) return raw.trim();
    return '010 - 0000 - 0000';
  }

  Future<void> _showCompletionDialog() async {
    final phoneDisplay = _formatPhoneForDialog(_currentUser?.phone);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: healthDp(ctx, 24)),
          child: Container(
            width: healthDp(ctx, 300),
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(healthDp(ctx, 20)),
              ),
              shadows: [
                BoxShadow(
                  color: const Color(0x19000000),
                  blurRadius: healthDp(ctx, 8.14),
                  offset: Offset.zero,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    top: healthDp(ctx, 20),
                    left: healthDp(ctx, 20),
                    right: healthDp(ctx, 20),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: healthDp(ctx, 260),
                        child: Text(
                          '연락처를 한번 더\n확인해주세요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF1A1A1A),
                            fontSize: healthSp(ctx, 20),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(height: healthDp(ctx, 10)),
                      Text(
                        '아래 가입하신 연락처가 맞으신가요?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFF1A1A1A),
                          fontSize: healthSp(ctx, 12),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                          height: 1,
                        ),
                      ),
                      SizedBox(height: healthDp(ctx, 10)),
                      Text(
                        phoneDisplay,
                        style: TextStyle(
                          color: const Color(0xFFFF5A8D),
                          fontSize: healthSp(ctx, 20),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: healthDp(ctx, 10)),
                      SizedBox(
                        width: healthDp(ctx, 260),
                        child: Text(
                          '연락처를 잘 못 입력하시면\n전화 처방이 어려울 수 있으며,\n이로 인한 책임은 고객님에게 있음을 안내드립니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF1A1A1A),
                            fontSize: healthSp(ctx, 11.70),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                            letterSpacing: -1.08,
                            height: 1.1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: healthDp(ctx, 20)),
                SizedBox(
                  width: healthDp(ctx, 300),
                  height: healthDp(ctx, 50),
                  child: Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: const Color(0xFFF7F7F7),
                          child: InkWell(
                            onTap: () => Navigator.of(ctx).pop(false),
                            child: Center(
                              child: Text(
                                '취소',
                                style: TextStyle(
                                  color: const Color(0xFF898686),
                                  fontSize: healthSp(ctx, 16),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Material(
                          color: const Color(0xFFFF5A8D),
                          child: InkWell(
                            onTap: () => Navigator.of(ctx).pop(true),
                            child: Center(
                              child: Text(
                                '확인',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: healthSp(ctx, 16),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (confirmed != true) return;
    await _submitReservationToCart();
  }

  Future<void> _submitReservationToCart() async {
    if (_reservationData == null) return;
    try {
      if (mounted) {
        setState(() => _isLoading = true);
      }

      final optionsRaw = _reservationData!['options'] as List?;
      final optionsList = optionsRaw == null
          ? <Map<String, dynamic>>[]
          : optionsRaw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
      final requestData = Map<String, dynamic>.from(_reservationData!);
      if (optionsList.isNotEmpty) {
        requestData['items'] = optionsList
            .map(
              (option) => <String, dynamic>{
                'it_id': option['it_id'] ?? requestData['it_id'],
                'quantity': option['quantity'] ?? 1,
                'price': option['totalPrice'] ?? option['price'] ?? 0,
                'option_id': option['id'] ?? '',
                'option_text': option['name'] ?? '',
                'option_price': option['price'] ?? 0,
                'ct_kind':
                    option['ct_kind'] ?? requestData['ct_kind'] ?? 'prescription',
              },
            )
            .toList();
      }

      final cartCtIds = widget.cartCtIdsForCheckout;
      if (cartCtIds != null && cartCtIds.isNotEmpty) {
        requestData['cart_ct_ids'] = cartCtIds;
      }

      final response =
          await ApiClient.post('/api/cart/healthprofile', requestData);

      if (response.statusCode != 200 && response.statusCode != 201) {
        throw Exception('healthprofile 요청 실패 (status=${response.statusCode})');
      }

      Map<String, dynamic>? responseData;
      try {
        responseData = json.decode(response.body) as Map<String, dynamic>?;
      } catch (_) {}

      if (responseData != null && responseData['success'] == false) {
        return;
      }

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      final checkoutItems = widget.checkoutCartItems;
      if (checkoutItems != null && checkoutItems.isNotEmpty) {
        Navigator.of(context).popUntil(
          (route) => route.settings.name == '/cart' || route.isFirst,
        );
        if (!mounted) return;
        await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            settings: const RouteSettings(name: '/pay'),
            builder: (context) => PaymentScreen(
              cartItems: checkoutItems,
              shippingCost: widget.checkoutShippingCost ?? 0,
              sourceTitle: '처방상품 장바구니',
            ),
          ),
        );
        return;
      }

      Future.microtask(() {
        try {
          final navigator = appNavigatorKey.currentState;
          if (navigator != null) {
            navigator.pushNamedAndRemoveUntil(
              '/cart',
              (route) => false,
              arguments: {
                'backToProductId': widget.productId,
                'initialTabIndex': 0,
              },
            );
          } else {
            _showNavigationFallback();
          }
        } catch (e) {
          _showNavigationFallback();
        }
      });
    } catch (e) {
      // ignored
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  bool get _hasValidContact {
    final name = (_currentUser?.name ?? '').trim();
    final phone = (_currentUser?.phone ?? '').trim();
    return name.isNotEmpty && phone.isNotEmpty;
  }

  bool get _canProceed =>
      _hasValidContact && _agreedRefundPolicy && !_isLoading;

  Future<void> _showRefundPolicyPopup() async {
    final confirmed = await ContentPopup.show(
      context,
      title: '교환 및 환불 안내',
      subtitle:
          '본 상품은 처방 및 건강 관련 상품으로 교환 및 환불 기준과 절차가 일반 다른 상품과 다르게 적용될 수 있습니다.',
      body: '''
구매 전 교환·환불 조건, 상담 절차 및 처리 기준을 반드시 확인해 주시기 바랍니다.

· 처방 및 건강 관련 상품의 특성상 단순 변심에 의한 교환·환불이 제한될 수 있습니다.
· 상품 수령 후 개봉·복용이 시작된 경우 교환 및 환불이 불가할 수 있습니다.
· 배송 중 파손·오배송 등 판매자 귀책 사유가 확인된 경우 교환 또는 환불이 가능합니다.
· 교환·환불 문의는 고객센터 또는 마이페이지 주문내역을 통해 접수해 주세요.
· 상담 예약 후 취소·변경은 안내드린 절차에 따라 처리됩니다.
· 자세한 기준은 관련 법령 및 서비스 이용약관을 따릅니다.''',
    );
    if (confirmed && mounted) {
      setState(() => _agreedRefundPolicy = true);
    }
  }

  Widget _buildReadonlyLabelField({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.black,
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
          ),
        ),
        SizedBox(height: healthDp(context, 5)),
        Container(
          width: double.infinity,
          height: healthDp(context, 40),
          padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: healthDp(context, 1),
                color: const Color(0xFFD2D2D2),
              ),
              borderRadius: BorderRadius.circular(healthDp(context, 10)),
            ),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              color: Colors.black,
              fontSize: healthSp(context, 13),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: const HealthAppBar(
        title: '04 상담 고객 연락처', centerTitle: false,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context)
              .textTheme
              .apply(fontFamily: 'Gmarket Sans TTF'),
          primaryTextTheme: Theme.of(context)
              .primaryTextTheme
              .apply(fontFamily: 'Gmarket Sans TTF'),
        ),
        child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                healthDp(context, 27),
                healthDp(context, 30),
                healthDp(context, 27),
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: healthDp(context, 560),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(healthDp(context, 20)),
                        decoration: ShapeDecoration(
                          color: const Color(0xFFF7F7F7),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(healthDp(context, 10)),
                          ),
                        ),
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Text(
                            '전화받으실\n연락처를 입력해 주세요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: healthSp(context, 16),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(height: healthDp(context, 15)),
                        _buildReadonlyLabelField(
                          label: '성함',
                          value: _currentUser?.name ?? '',
                        ),
                        SizedBox(height: healthDp(context, 10)),
                        _buildReadonlyLabelField(
                          label: '연락처',
                          value: _currentUser?.phone ?? '',
                        ),
                        SizedBox(height: healthDp(context, 5)),
                        const Divider(color: Color(0xFFD2D2D2)),
                        SizedBox(height: healthDp(context, 5)),
                        Center(
                          child: Text(
                            '개인정보를 위한 의료법 시행규칙',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: healthSp(context, 12),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(height: healthDp(context, 4)),
                        Center(
                          child: Text(
                            '의료법 시행규칙 제 14조에 따라 진료를 받는 환자의\n성명, 연락처, 주소, 주민등록번호 등의 인적사항은\n진료 기록부에 의무 기록 기재사항입니다.\n주민등록번호는 환자의 신상정보/본인확인을 위해\n담당 한의사만 볼 수 있는 정보이니 개인정보 노출 우려는 없습니다.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: healthSp(context, 10),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                              height: 1.5,
                              letterSpacing: -1.08,
                            ),
                          ),
                        ),
                        SizedBox(height: healthDp(context, 12)),
                        Center(
                          child: Text(
                            '교환·환불 안내 확인 및 동의',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: healthSp(context, 12),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        SizedBox(height: healthDp(context, 4)),
                        Center(
                          child: Text(
                            '본 상품은 처방 및 건강 관련 상품으로 교환 및 환불 기준과 절차가\n일반 다른 상품과 다르게 적용될 수 있습니다.\n구매 전 교환환불 조건, 상담 절차 및 처리 기준을\n반드시 확인해 주시기 바랍니다.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: healthSp(context, 10),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                              height: 1.5,
                              letterSpacing: -1.08,
                            ),
                          ),
                        ),
                        SizedBox(height: healthDp(context, 12)),
                        InkWell(
                          onTap: () => setState(() {
                            _agreedRefundPolicy = !_agreedRefundPolicy;
                          }),
                          borderRadius:
                              BorderRadius.circular(healthDp(context, 20)),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: healthDp(context, 6),
                              vertical: healthDp(context, 5),
                            ),
                            decoration: ShapeDecoration(
                              color: const Color(0xFFE5E5E5),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(healthDp(context, 20)),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: healthDp(context, 16),
                                  height: healthDp(context, 16),
                                  decoration: ShapeDecoration(
                                    color: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      side: BorderSide(
                                        width: healthDp(context, 1),
                                        color: const Color(0xFFD2D2D2),
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        healthDp(context, 4),
                                      ),
                                    ),
                                  ),
                                  child: _agreedRefundPolicy
                                      ? Icon(
                                          Icons.check,
                                          size: healthDp(context, 12),
                                          color: const Color(0xFFFF5A8D),
                                        )
                                      : null,
                                ),
                                SizedBox(width: healthDp(context, 4)),
                                Expanded(
                                  child: Text(
                                    '교환환불 안내사항을 확인하였으며, 이에 동의합니다.',
                                    maxLines: 1,
                                    softWrap: false,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: healthSp(context, 12),
                                      fontFamily: 'Gmarket Sans TTF',
                                      fontWeight: FontWeight.w300,
                                      letterSpacing: -1.08,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: healthDp(context, 8)),
                        Center(
                          child: InkWell(
                            onTap: _showRefundPolicyPopup,
                            child: Text(
                              '교환환불 안내보기 >',
                              style: TextStyle(
                                color: const Color(0xFF898686),
                                fontSize: healthSp(context, 12),
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        ],
                      ),
                    ),
                  ),
                ),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              healthDp(context, 27),
              0,
              healthDp(context, 27),
              healthDp(context, 20),
            ),
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '결제를 완료하셔야 예약이 확정됩니다.',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: healthSp(context, 16),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: healthDp(context, 10)),
                Row(
                  children: [
                    SizedBox(
                      width: healthDp(context, 72),
                      height: healthDp(context, 34),
                      child: FilledButton.tonal(
                        onPressed: () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                          minimumSize: Size(
                            healthDp(context, 72),
                            healthDp(context, 34),
                          ),
                          maximumSize: Size(
                            healthDp(context, 72),
                            healthDp(context, 34),
                          ),
                          padding: EdgeInsets.zero,
                          backgroundColor: const Color(0x26D2D2D2),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(healthDp(context, 7)),
                          ),
                        ),
                        child: Text(
                          '이전',
                          style: TextStyle(
                            color: const Color(0xFF898686),
                            fontSize: healthSp(context, 14),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: healthDp(context, 10)),
                    Expanded(
                      child: SizedBox(
                        height: healthDp(context, 34),
                        child: ElevatedButton(
                          onPressed: _canProceed ? _submitBooking : null,
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(
                              double.infinity,
                              healthDp(context, 34),
                            ),
                            maximumSize: Size(
                              double.infinity,
                              healthDp(context, 34),
                            ),
                            padding: EdgeInsets.zero,
                            backgroundColor: const Color(0xFFFF5A8D),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                const Color(0xFFFF5A8D).withValues(alpha: 0.4),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(healthDp(context, 7)),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: healthDp(context, 18),
                                  height: healthDp(context, 18),
                                  child: CircularProgressIndicator(
                                    strokeWidth: healthDp(context, 2),
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  '다음',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: healthSp(context, 14),
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
          ),
        ],
        ),
      ),
    );
  }
}

