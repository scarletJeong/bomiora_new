import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/health_profile_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../user/healthprofile/models/health_profile_model.dart';
import '../../../user/healthprofile/health_profile_payload.dart';
import '../../../common/widgets/app_bar.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../../core/network/api_client.dart';
import '../../../../data/services/cart_service.dart';
import '../../../../core/navigation/app_navigator_key.dart';

/// 연락처 입력 화면 (개인정보)
class PrescriptionContactScreen extends StatefulWidget {
  final String productId;
  final String productName;
  final dynamic selectedOptions; // List<Map<String, dynamic>> 또는 Map<String, dynamic>? (하위 호환성)
  final Map<String, dynamic> formData;
  final HealthProfileModel? existingProfile;
  final DateTime selectedDate;
  final String selectedTime;
  final List<int>? tempCartCtIdsToClearOnSuccess;

  const PrescriptionContactScreen({
    super.key,
    required this.productId,
    required this.productName,
    this.selectedOptions,
    required this.formData,
    this.existingProfile,
    required this.selectedDate,
    required this.selectedTime,
    this.tempCartCtIdsToClearOnSuccess,
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
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            width: 300,
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              shadows: const [
                BoxShadow(
                  color: Color(0x19000000),
                  blurRadius: 8.14,
                  offset: Offset(0, 0),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 20, left: 20, right: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 260,
                        child: Text(
                          '연락처를 한번 더\n확인해주세요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 20,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        '아래 가입하신 연락처가 맞으신가요?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 12,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        phoneDisplay,
                        style: const TextStyle(
                          color: Color(0xFFFF5A8D),
                          fontSize: 20,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const SizedBox(
                        width: 260,
                        child: Text(
                          '연락처를 잘 못 입력하시면\n전화 처방이 어려울 수 있으며,\n이로 인한 책임은 고객님에게 있음을 안내드립니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 11.70,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                            height: 1.54,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 300,
                  height: 50,
                  child: Row(
                    children: [
                      Expanded(
                        child: Material(
                          color: const Color(0xFFF7F7F7),
                          child: InkWell(
                            onTap: () => Navigator.of(ctx).pop(false),
                            child: const Center(
                              child: Text(
                                '취소',
                                style: TextStyle(
                                  color: Color(0xFF898686),
                                  fontSize: 16,
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
                            child: const Center(
                              child: Text(
                                '확인',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
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

      final tempIds = widget.tempCartCtIdsToClearOnSuccess;
      if (tempIds != null && tempIds.isNotEmpty) {
        for (final ctId in tempIds) {
          try {
            await CartService.removeCartItem(ctId);
          } catch (_) {}
        }
      }

      if (!mounted) return;
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

  Widget _buildReadonlyLabelField({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 12,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 1, color: Color(0xFFD2D2D2)),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 13,
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
        title: '04 상담 고객 연락처',
        centerTitle: true,
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
              padding: const EdgeInsets.fromLTRB(27, 30, 27, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: ShapeDecoration(
                          color: const Color(0xFFF7F7F7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Center(
                          child: Text(
                            '전화받으실\n연락처를 입력해 주세요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 20,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 15),
                        _buildReadonlyLabelField(
                          label: '성함',
                          value: _currentUser?.name ?? '',
                        ),
                        const SizedBox(height: 10),
                        _buildReadonlyLabelField(
                          label: '연락처',
                          value: _currentUser?.phone ?? '',
                        ),
                        const SizedBox(height: 5),
                        const Divider(color: Color(0xFFD2D2D2)),
                        const SizedBox(height: 5),
                        const Center(
                          child: Text(
                            '개인정보를 위한 의료법 시행규칙',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Center(
                          child: Text(
                            '의료법 시행규칙 제 14조에 따라 진료를 받는 환자의\n성명, 연락처, 주소, 주민등록번호 등의 인적사항은\n진료 기록부에 의무 기록 기재사항입니다.\n주민등록번호는 환자의 신상정보/본인확인을 위해\n담당 한의사만 볼 수 있는 정보이니 개인정보 노출 우려는 없습니다.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Center(
                          child: Text(
                            '교환·환불 안내 확인 및 동의',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Center(
                          child: Text(
                            '본 상품은 처방 및 건강 관련 상품으로 교환 및 환불 기준과 절차가\n일반 다른 상품과 다르게 적용될 수 있습니다.\n구매 전 교환환불 조건, 상담 절차 및 처리 기준을\n반드시 확인해 주시기 바랍니다.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 10,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w300,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: () => setState(() {
                            _agreedRefundPolicy = !_agreedRefundPolicy;
                          }),
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: ShapeDecoration(
                              color: const Color(0xFFE5E5E5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                const boxW = 16.0;
                                const gap = 6.0;
                                final textMaxW = (constraints.maxWidth - boxW - gap)
                                    .clamp(80.0, constraints.maxWidth);
                                return Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: boxW,
                                        height: boxW,
                                        decoration: ShapeDecoration(
                                          color: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            side: const BorderSide(
                                              width: 1,
                                              color: Color(0xFFD2D2D2),
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ),
                                        child: _agreedRefundPolicy
                                            ? const Icon(
                                                Icons.check,
                                                size: 12,
                                                color: Color(0xFFFF5A8D),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: gap),
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: textMaxW,
                                        ),
                                        child: const Text(
                                          '교환환불 안내사항을 확인하였으며, 이에 동의합니다.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.black,
                                            fontSize: 12,
                                            fontFamily: 'Gmarket Sans TTF',
                                            fontWeight: FontWeight.w300,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Center(
                          child: Text(
                            '교환환불 안내보기 >',
                            style: TextStyle(
                              color: Color(0xFF898686),
                              fontSize: 12,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
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
            padding: const EdgeInsets.fromLTRB(27, 0, 27, 20),
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '결제를 완료하셔야 예약이 확정됩니다.',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 16,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    SizedBox(
                      width: 100,
                      height: 40,
                      child: FilledButton.tonal(
                        onPressed: () => Navigator.pop(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0x26D2D2D2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          '이전',
                          style: TextStyle(
                            color: Color(0xFF898686),
                            fontSize: 20,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  if (!_agreedRefundPolicy) {
                                    return;
                                  }
                                  _submitBooking();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5A8D),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            disabledBackgroundColor: Colors.grey[300],
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text(
                                  '다음',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
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

