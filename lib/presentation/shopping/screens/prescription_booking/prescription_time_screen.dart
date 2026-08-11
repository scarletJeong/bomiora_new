import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/navigation/app_navigator_key.dart';
import '../../../../core/network/api_client.dart';
import '../../../../data/models/cart/cart_item_model.dart';
import '../../../../data/models/shop_default/reservation_settings_model.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/health_profile_service.dart';
import '../../../../data/services/shop_default_service.dart';
import '../../../user/healthprofile/models/health_profile_model.dart';
import '../../../user/healthprofile/health_profile_payload.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/app_toast_overlay.dart';
import '../../../common/widgets/content_popup.dart';
import '../../screens/payment_screen.dart';
import '../../widgets/prescription_booking_progress_bar.dart';

/// 진료 시간 선택 + 연락처 확인 화면
class PrescriptionTimeScreen extends StatefulWidget {
  final String productId;
  final String productName;
  final dynamic selectedOptions; // List<Map<String, dynamic>> 또는 Map<String, dynamic>? (하위 호환성)
  final Map<String, dynamic> formData;
  final HealthProfileModel? existingProfile;
  final List<int>? cartCtIdsForCheckout;
  final List<CartItem>? checkoutCartItems;
  final int? checkoutShippingCost;

  const PrescriptionTimeScreen({
    super.key,
    required this.productId,
    required this.productName,
    this.selectedOptions,
    required this.formData,
    this.existingProfile,
    this.cartCtIdsForCheckout,
    this.checkoutCartItems,
    this.checkoutShippingCost,
  });

  @override
  State<PrescriptionTimeScreen> createState() => _PrescriptionTimeScreenState();
}

class _PrescriptionTimeScreenState extends State<PrescriptionTimeScreen> {
  DateTime? _selectedDate;
  String? _selectedTime;
  ReservationSettingsModel? _settings;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _agreedRefundPolicy = false;
  UserModel? _currentUser;
  Map<String, dynamic>? _reservationData;
  bool _confirmDialogOpen = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _contactSectionKey = GlobalKey();
  
  @override
  void initState() {
    super.initState();
    _nameController.addListener(_onContactChanged);
    _phoneController.addListener(_onContactChanged);
    _loadSettings();
    _loadUser();
  }

  double get _dateTimeStepProgress => prescriptionDateTimeMilestoneProgress(
        hasDate: _selectedDate != null,
        hasTime: _selectedTime != null,
        agreedPolicy: _agreedRefundPolicy,
        confirmDialogOpen: _confirmDialogOpen,
      );

  @override
  void dispose() {
    _nameController.removeListener(_onContactChanged);
    _phoneController.removeListener(_onContactChanged);
    _nameController.dispose();
    _phoneController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToContactSection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _contactSectionKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    });
  }

  void _onContactChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadUser() async {
    final user = await AuthService.getUser();
    if (!mounted) return;
    setState(() {
      _currentUser = user;
      if (_nameController.text.isEmpty) {
        _nameController.text = user?.name ?? '';
      }
      if (_phoneController.text.isEmpty) {
        final digits = (user?.phone ?? '').replaceAll(RegExp(r'\D'), '');
        _phoneController.text =
            digits.length > 11 ? digits.substring(0, 11) : digits;
      }
    });
  }
  
  Future<void> _loadSettings() async {
    final settings = await ShopDefaultService.getReservationSettings();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _isLoading = false;
    });
  }
  
  List<String> _generateTimeSlots(DateTime date) {
    if (_settings == null) return [];
    
    final daySettings = _settings!.getSettingsForDay(date.weekday);
    
    if (!daySettings.active || daySettings.startTime == null || daySettings.endTime == null) {
      return [];
    }
    
    final slots = <String>[];
    final relayTime = _settings!.relayTime;
    
    // 시작 시간 파싱 (HH:mm 형식)
    final startParts = daySettings.startTime!.split(':');
    int currentHour = int.parse(startParts[0]);
    int currentMinute = int.parse(startParts[1]);
    
    // 종료 시간 파싱
    final endParts = daySettings.endTime!.split(':');
    final endHour = int.parse(endParts[0]);
    final endMinute = int.parse(endParts[1]);
    
    // 점심시간 파싱
    int? lunchStartHour, lunchStartMinute, lunchEndHour, lunchEndMinute;
    if (_settings!.lunch.startTime != null && _settings!.lunch.endTime != null) {
      final lunchStartParts = _settings!.lunch.startTime!.split(':');
      lunchStartHour = int.parse(lunchStartParts[0]);
      lunchStartMinute = int.parse(lunchStartParts[1]);
      
      final lunchEndParts = _settings!.lunch.endTime!.split(':');
      lunchEndHour = int.parse(lunchEndParts[0]);
      lunchEndMinute = int.parse(lunchEndParts[1]);
    }
    
    // 오늘 날짜인 경우, 현재 시각 + 30분을 기준 시각으로 설정
    DateTime? minimumTime;
    final now = DateTime.now();
    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;
    
    if (isToday) {
      minimumTime = now.add(const Duration(minutes: 30));
    }
    
    while (currentHour < endHour || (currentHour == endHour && currentMinute < endMinute)) {
      final timeStr = '${currentHour.toString().padLeft(2, '0')}:${currentMinute.toString().padLeft(2, '0')}';
      
      // 점심시간 체크
      bool isLunchTime = false;
      if (lunchStartHour != null && lunchEndHour != null) {
        final currentTimeInMinutes = currentHour * 60 + currentMinute;
        final lunchStartInMinutes = lunchStartHour * 60 + lunchStartMinute!;
        final lunchEndInMinutes = lunchEndHour * 60 + lunchEndMinute!;
        
        if (currentTimeInMinutes >= lunchStartInMinutes && currentTimeInMinutes < lunchEndInMinutes) {
          isLunchTime = true;
        }
      }
      
      // 오늘 날짜인 경우, 최소 시간 이후만 추가
      bool isValid = true;
      if (isToday && minimumTime != null) {
        final slotTime = DateTime(date.year, date.month, date.day, currentHour, currentMinute);
        if (slotTime.isBefore(minimumTime)) {
          isValid = false;
        }
      }
      
      if (!isLunchTime && isValid) {
        slots.add(timeStr);
      }
      
      // 다음 슬롯으로 이동
      currentMinute += relayTime;
      if (currentMinute >= 60) {
        currentHour += currentMinute ~/ 60;
        currentMinute = currentMinute % 60;
      }
    }
    
    return slots;
  }
  
  void _nextStep() {
    if (_selectedDate == null || _selectedTime == null) return;
    if (_nameController.text.trim().isEmpty) return;
    if (!_agreedRefundPolicy || _isSubmitting) return;

    final phoneDigits =
        _phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (phoneDigits.length != 11) {
      AppToastOverlay.show(context, '연락처 11자리를 확인해 주세요.');
      return;
    }
    _submitBooking();
  }

  bool get _hasValidContact {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    return name.isNotEmpty && phone.isNotEmpty;
  }

  bool get _canProceed =>
      _selectedDate != null &&
      _selectedTime != null &&
      _hasValidContact &&
      _agreedRefundPolicy &&
      !_isSubmitting;

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

  String _formatDateForDialog(DateTime d) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    return '${d.month.toString().padLeft(2, '0')}월${d.day.toString().padLeft(2, '0')}일(${weekdays[d.weekday - 1]})';
  }

  String _formatTimeRange(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return time;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final end = DateTime(2000, 1, 1, h, m).add(const Duration(minutes: 30));
    final endText =
        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}';
    return '$time ~ $endText';
  }

  Future<void> _submitBooking() async {
    if (_currentUser == null || _selectedDate == null || _selectedTime == null) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      List<Map<String, dynamic>> optionsList = [];
      if (widget.selectedOptions is List) {
        optionsList =
            List<Map<String, dynamic>>.from(widget.selectedOptions as List);
      } else if (widget.selectedOptions is Map) {
        optionsList = [
          Map<String, dynamic>.from(widget.selectedOptions as Map)
        ];
      }

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
        answer8: HealthProfilePayload.formatListToString(
            widget.formData['eatingHabits']),
        answer9: HealthProfilePayload.formatListToString(
            widget.formData['foodPreference']),
        answer10: HealthProfilePayload.composeAnswer10FrequencyOnly(
          widget.formData['exerciseFrequency']?.toString(),
        ),
        answer102: HealthProfilePayload.composeAnswer10TypesOnly(
          widget.formData['exerciseTypes'],
        ),
        answer11: HealthProfilePayload.formatListToString(
            widget.formData['diseases']),
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

      final odId = DateTime.now().millisecondsSinceEpoch;
      _reservationData = {
        'mb_id': _currentUser!.id,
        'it_id': widget.productId,
        'od_id': odId,
        'options': optionsList,
        'option_id': optionsList.isNotEmpty ? optionsList[0]['id'] : null,
        'option_text': optionsList.isNotEmpty ? optionsList[0]['name'] : null,
        'option_price': optionsList.isNotEmpty ? optionsList[0]['price'] : null,
        'quantity': optionsList.isNotEmpty ? optionsList[0]['quantity'] : 1,
        'price': optionsList.isNotEmpty ? optionsList[0]['totalPrice'] : 0,
        'answer1': widget.formData['birthDate'] ?? '',
        'answer2': widget.formData['gender'] ?? '',
        'answer3': widget.formData['targetWeight'] ?? '',
        'answer4': widget.formData['height'] ?? '',
        'answer5': widget.formData['currentWeight'] ?? '',
        'answer6': widget.formData['dietPeriod'] ?? '',
        'answer7': widget.formData['mealsPerDay'] ?? '',
        'answer71': widget.formData['mealTimes'] ?? '|||',
        'answer8': HealthProfilePayload.formatListToString(
            widget.formData['eatingHabits']),
        'answer9': HealthProfilePayload.formatListToString(
            widget.formData['foodPreference']),
        'answer10': HealthProfilePayload.composeAnswer10(
          widget.formData['exerciseFrequency']?.toString(),
          widget.formData['exerciseTypes'],
        ),
        'answer11': HealthProfilePayload.formatListToString(
            widget.formData['diseases']),
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
        'reservationDate': _selectedDate!.toIso8601String(),
        'reservationTime': _selectedTime!,
        'reservationName': _nameController.text.trim(),
        'reservationTel': _phoneController.text.trim(),
        'doctorName': '',
      };

      if (!mounted) return;
      await _showCompletionDialog();
    } catch (_) {
      // ignored
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showCompletionDialog() async {
    final phoneDisplay = _formatPhoneForDialog(_phoneController.text);
    final dateText = _formatDateForDialog(_selectedDate!);
    final timeText = _formatTimeRange(_selectedTime!);

    setState(() => _confirmDialogOpen = true);
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final r20 = healthDp(ctx, 20);
        final r15 = healthDp(ctx, 15);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(horizontal: healthDp(ctx, 24)),
          child: Container(
            width: healthDp(ctx, 300),
            clipBehavior: Clip.antiAlias,
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(r20),
              ),
              shadows: [
                BoxShadow(
                  color: const Color(0x19000000),
                  blurRadius: healthDp(ctx, 8.14),
                  offset: Offset.zero,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(r20, r20, r20, healthDp(ctx, 20)),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: healthDp(ctx, 260),
                        child: Text(
                          '예약 정보를 \n한번 더 확인해주세요',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF1A1A1E),
                            fontSize: healthSp(ctx, 20),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                      SizedBox(height: healthDp(ctx, 20)),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: healthDp(ctx, 10),
                                vertical: healthDp(ctx, 14),
                              ),
                              decoration: ShapeDecoration(
                                color: const Color(0xFFF7F7F7),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(r15),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '진료 날짜 ',
                                    style: TextStyle(
                                      color: const Color(0xFF898686),
                                      fontSize: healthSp(ctx, 10),
                                      fontFamily: 'Gmarket Sans TTF',
                                      fontWeight: FontWeight.w500,
                                      height: 1,
                                    ),
                                  ),
                                  SizedBox(height: healthDp(ctx, 10)),
                                  Text(
                                    dateText,
                                    style: TextStyle(
                                      color: const Color(0xFF1A1A1E),
                                      fontSize: healthSp(ctx, 14),
                                      fontFamily: 'Gmarket Sans TTF',
                                      fontWeight: FontWeight.w700,
                                      height: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: healthDp(ctx, 10)),
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: healthDp(ctx, 10),
                                vertical: healthDp(ctx, 14),
                              ),
                              decoration: ShapeDecoration(
                                color: const Color(0xFFF7F7F7),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(r15),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '예약 시간',
                                    style: TextStyle(
                                      color: const Color(0xFF898686),
                                      fontSize: healthSp(ctx, 10),
                                      fontFamily: 'Gmarket Sans TTF',
                                      fontWeight: FontWeight.w500,
                                      height: 1,
                                    ),
                                  ),
                                  SizedBox(height: healthDp(ctx, 10)),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      timeText,
                                      maxLines: 1,
                                      softWrap: false,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: const Color(0xFFFF5A8D),
                                        fontSize: healthSp(ctx, 14),
                                        fontFamily: 'Gmarket Sans TTF',
                                        fontWeight: FontWeight.w700,
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: healthDp(ctx, 10)),
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: healthDp(ctx, 10),
                          vertical: healthDp(ctx, 14),
                        ),
                        decoration: ShapeDecoration(
                          color: const Color(0xFFF7F7F7),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(r15),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '연락처',
                              style: TextStyle(
                                color: const Color(0xFF898686),
                                fontSize: healthSp(ctx, 10),
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w500,
                                height: 1,
                              ),
                            ),
                            SizedBox(height: healthDp(ctx, 8)),
                            Text(
                              phoneDisplay,
                              style: TextStyle(
                                color: const Color(0xFF1A1A1E),
                                fontSize: healthSp(ctx, 14),
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w700,
                                height: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: healthDp(ctx, 20)),
                      Text(
                        '기입하신 연락처가 맞으신가요?',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFF1A1A1E),
                          fontSize: healthSp(ctx, 12),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                          height: 1,
                        ),
                      ),
                      SizedBox(height: healthDp(ctx, 10)),
                      SizedBox(
                        width: healthDp(ctx, 260),
                        child: Text(
                          '연락처를 잘못 입력하시면\n전화 처방이 어려울 수 있으며,\n이로 인한 책임은 고객님께 있음을 안내드립니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF898686),
                            fontSize: healthSp(ctx, 10),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w300,
                            letterSpacing: -0.40,
                            height: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: double.infinity,
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
                                  height: 1,
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
                                  height: 1,
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

    if (mounted) setState(() => _confirmDialogOpen = false);
    if (confirmed != true) return;
    await _submitReservationToCart();
  }

  Future<void> _submitReservationToCart() async {
    if (_reservationData == null) return;
    try {
      if (mounted) setState(() => _isSubmitting = true);

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
              showPrescriptionBookingProgress: true,
              reservationDate: _selectedDate,
              reservationTime: _selectedTime,
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
          }
        } catch (_) {}
      });
    } catch (_) {
      // ignored
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showRefundPolicyPopup() async {
    final confirmed = await ContentPopup.show(
      context,
      title: '의료법 및 교환환불 안내',
      subtitle:
          '본 상품은 처방 및 건강 관련 상품으로 교환 및 환불 기준과 절차가 일반 다른 상품과 다르게 적용될 수 있습니다.',
      body: '''
의료법 시행규칙 제 14조에 따라 진료를 받는 환자의 성명, 연락처, 주소, 주민등록번호 등의 인적사항은 진료 기록부에 의무 기록 기재사항입니다. 주민등록번호는 환자의 신상정보/본인확인을 위해 담당 한의사만 볼 수 있는 정보이니 개인정보 노출 우려는 없습니다.

구매 전 교환·환불 조건, 상담 절차 및 처리 기준을 반드시 확인해 주시기 바랍니다.

· 처방 및 건강 관련 상품의 특성상 단순 변심에 의한 교환·환불이 제한될 수 있습니다.
· 상품 수령 후 개봉·복용이 시작된 경우 교환 및 환불이 불가할 수 있습니다.
· 배송 중 파손·오배송 등 판매자 귀책 사유가 확인된 경우 교환 또는 환불이 가능합니다.
· 교환·환불 문의는 고객센터 또는 마이페이지 주문내역을 통해 접수해 주세요.
· 상담 예약 후 취소·변경은 안내드린 절차에 따라 처리됩니다.
· 자세한 기준은 관련 법령 및 서비스 이용약관을 따릅니다.''',
      titleFontSize: 16,
      subtitleFontSize: 12,
      bodyFontSize: 10,
      confirmFontSize: 12,
    );
    if (confirmed && mounted) {
      setState(() => _agreedRefundPolicy = true);
    }
  }

  Widget _buildInlineContactField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final filled = controller.text.trim().isNotEmpty;
    const pink = Color(0xFFFF5A8D);
    final borderColor =
        filled ? const Color(0x66FF5A8D) : const Color(0xFFE8E8E8);
    final iconBg =
        filled ? const Color(0x19FF5A8D) : const Color(0xFFF0F0F0);
    final iconColor = filled ? pink : const Color(0xFFC4C4C4);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 16),
        vertical: healthDp(context, 12),
      ),
      decoration: ShapeDecoration(
        color: const Color(0xFFFAFAFA),
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1.11),
            color: borderColor,
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 14)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: healthDp(context, 32),
            height: healthDp(context, 32),
            decoration: BoxDecoration(
              color: iconBg,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: healthDp(context, 15),
              color: iconColor,
            ),
          ),
          SizedBox(width: healthDp(context, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: const Color(0xFF898686),
                    fontSize: healthSp(context, 10),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
                SizedBox(height: healthDp(context, 1)),
                TextField(
                  controller: controller,
                  keyboardType: keyboardType,
                  inputFormatters: inputFormatters,
                  style: TextStyle(
                    color: const Color(0xFF1A1A1E),
                    fontSize: healthSp(context, 13),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: hint,
                    hintStyle: TextStyle(
                      color: const Color(0xFFC4C4C4),
                      fontSize: healthSp(context, 13),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (filled)
            InkWell(
              onTap: () => controller.clear(),
              borderRadius: BorderRadius.circular(healthDp(context, 12)),
              child: Padding(
                padding: EdgeInsets.all(healthDp(context, 4)),
                child: Text(
                  '×',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFFC4C4C4),
                    fontSize: healthSp(context, 18),
                    fontWeight: FontWeight.w500,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return Column(
      key: _contactSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '3. 전화받으실 성함/연락처를 확인해주세요.',
          style: TextStyle(
            color: Colors.black,
            fontSize: healthSp(context, 14),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: healthDp(context, 10)),
        Column(
          children: [
            _buildInlineContactField(
              label: '성함',
              hint: '이름을 입력해주세요',
              controller: _nameController,
              icon: Icons.person_outline,
            ),
            SizedBox(height: healthDp(context, 10)),
            _buildInlineContactField(
              label: '연락처',
              hint: '연락 가능한 번호를 입력해주세요',
              controller: _phoneController,
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
            ),
            SizedBox(height: healthDp(context, 20)),
            InkWell(
              onTap: () => setState(() {
                _agreedRefundPolicy = !_agreedRefundPolicy;
              }),
              borderRadius: BorderRadius.circular(healthDp(context, 8)),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: healthDp(context, 14),
                  vertical: healthDp(context, 5),
                ),
                decoration: ShapeDecoration(
                  color: const Color(0x7FF1F1F1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(healthDp(context, 8)),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: healthDp(context, 20),
                      height: healthDp(context, 20),
                      decoration: ShapeDecoration(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            width: healthDp(context, 1),
                            color: const Color(0xFFD2D2D2),
                          ),
                          borderRadius:
                              BorderRadius.circular(healthDp(context, 4)),
                        ),
                      ),
                      child: _agreedRefundPolicy
                          ? Icon(
                              Icons.check,
                              size: healthDp(context, 14),
                              color: const Color(0xFFFF5A8D),
                            )
                          : null,
                    ),
                    SizedBox(width: healthDp(context, 5)),
                    Expanded(
                      child: Text(
                        '의료법 및 교환환불 안내사항을 확인하였으며, 이에 동의합니다.',
                        style: TextStyle(
                          color: const Color(0xFF1A1A1E),
                          fontSize: healthSp(context, 9.5),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: healthDp(context, 10)),
            InkWell(
              onTap: _showRefundPolicyPopup,
              child: Text(
                '의료법 및 교환환불 안내보기 >',
                style: TextStyle(
                  color: const Color(0xFF898686),
                  fontSize: healthSp(context, 9),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w300,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const MobileAppLayoutWrapper(
        appBar: null,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    
    // 예약 가능한 날짜 생성 (오늘부터 7일)
    final availableDates = List.generate(7, (index) {
      final date = DateTime.now().add(Duration(days: index));
      return date;
    });
    
    // 선택된 날짜의 예약 가능한 시간
    final availableTimes =
        _selectedDate != null ? _generateTimeSlots(_selectedDate!) : <String>[];
    final hasSelectedDateTime = _selectedDate != null && _selectedTime != null;
    
    return MobileAppLayoutWrapper(
      appBar: HealthAppBar(
        title: '진료 예약 중 _ 02 날짜/시간',
        centerTitle: false,
        bottom: PrescriptionBookingProgressBar.asAppBarBottom(
          currentStep: PrescriptionBookingSteps.dateTime,
          stepProgress: _dateTimeStepProgress,
        ),
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
              controller: _scrollController,
              padding: EdgeInsets.fromLTRB(
                healthDp(context, 27),
                healthDp(context, 20),
                healthDp(context, 27),
                healthDp(context, 20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1. 가능한 날짜를 선택해주세요',
                    style: TextStyle(
                      fontSize: healthSp(context, 14),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 12)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: availableDates.take(7).map((date) {
                      final isSelected = _selectedDate != null &&
                          _selectedDate!.year == date.year &&
                          _selectedDate!.month == date.month &&
                          _selectedDate!.day == date.day;
                      final isToday = DateUtils.isSameDay(date, DateTime.now());
                      final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
                      final weekday = weekdays[date.weekday - 1];
                      return InkWell(
                        onTap: () => setState(() {
                          _selectedDate = date;
                          _selectedTime = null;
                        }),
                        borderRadius: BorderRadius.circular(healthDp(context, 18.33)),
                        child: Container(
                          width: healthDp(context, 40),
                          height: healthDp(context, 54.17),
                          decoration: ShapeDecoration(
                            color: isSelected
                                ? const Color(0x0CFF5A8D)
                                : Colors.white,
                            shape: RoundedRectangleBorder(
                              side: BorderSide(
                                width: isSelected
                                    ? healthDp(context, 1)
                                    : healthDp(context, 0.5),
                                color: isSelected
                                    ? const Color(0xFFFF5A8D)
                                    : const Color(0xFFD2D2D2),
                              ),
                              borderRadius: BorderRadius.circular(healthDp(context, 18.33)),
                            ),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                          child: Column(
                              mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isToday)
                                Text(
                                  '오늘',
                                  style: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFFFF5A8D)
                                        : const Color(0xFF1A1A1A),
                                    fontSize: healthSp(context, 10),
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w300,
                                  ),
                                ),
                              if (isToday) SizedBox(height: healthDp(context, 2)),
                              Text(
                                '${date.day}',
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFFFF5A8D)
                                      : const Color(0xFF1A1A1A),
                                  fontSize: healthSp(context, 12),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                                SizedBox(height: healthDp(context, 4)),
                              Text(
                                weekday,
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFFFF5A8D)
                                      : const Color(0xFF1A1A1A),
                                  fontSize: healthSp(context, 10),
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_selectedDate != null) ...[
                  SizedBox(height: healthDp(context, 32)),
                  Text(
                    '2. 시간을 선택해주세요',
                    style: TextStyle(
                        color: Colors.black,
                      fontSize: healthSp(context, 14),
                        fontWeight: FontWeight.w500,
                      fontFamily: 'Gmarket Sans TTF',
                    ),
                  ),
                  SizedBox(height: healthDp(context, 12)),
                    if (availableTimes.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(healthDp(context, 16)),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                          borderRadius:
                              BorderRadius.circular(healthDp(context, 10)),
                      ),
                      child: Center(
                        child: Text(
                          '예약 가능한 시간이 없습니다',
                          style: TextStyle(
                            fontSize: healthSp(context, 14),
                            color: Colors.grey,
                            fontFamily: 'Gmarket Sans TTF',
                          ),
                        ),
                      ),
                    )
                  else
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        mainAxisExtent: healthDp(context, 42),
                        crossAxisSpacing: healthDp(context, 10),
                        mainAxisSpacing: healthDp(context, 10),
                      ),
                      itemCount: availableTimes.length,
                      itemBuilder: (context, index) {
                        final time = availableTimes[index];
                        final isSelected = _selectedTime == time;
                        return InkWell(
                          onTap: () {
                            setState(() => _selectedTime = time);
                            _scrollToContactSection();
                          },
                          borderRadius:
                              BorderRadius.circular(healthDp(context, 10)),
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(
                              horizontal: healthDp(context, 5),
                              vertical: healthDp(context, 10),
                            ),
                            decoration: ShapeDecoration(
                              color: isSelected
                                  ? const Color(0x0CFF5A8D)
                                  : Colors.white,
                              shape: RoundedRectangleBorder(
                                side: BorderSide(
                                  width: healthDp(context, 1),
                                  color: isSelected
                                      ? const Color(0xFFFF5A8D)
                                      : const Color(0xFFD2D2D2),
                                ),
                                  borderRadius: BorderRadius.circular(
                                    healthDp(context, 10),
                                  ),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  time,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isSelected
                                        ? const Color(0xFFFF5A8D)
                                        : const Color(0xFF1A1A1A),
                                    fontSize: healthSp(context, 12),
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                  if (hasSelectedDateTime) ...[
                  SizedBox(height: healthDp(context, 30)),
                    _buildContactSection(),
                  ],
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
            child: Row(
              children: [
                SizedBox(
                  width: healthDp(context, 72),
                  height: healthDp(context, 40),
                  child: FilledButton.tonal(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      minimumSize: Size(
                        healthDp(context, 72),
                        healthDp(context, 40),
                      ),
                      maximumSize: Size(
                        healthDp(context, 72),
                        healthDp(context, 40),
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
                    height: healthDp(context, 40),
                    child: ElevatedButton(
                      onPressed: _canProceed ? _nextStep : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: Size(
                          double.infinity,
                          healthDp(context, 40),
                        ),
                        maximumSize: Size(
                          double.infinity,
                          healthDp(context, 40),
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
                      child: _isSubmitting
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
          ),
        ],
        ),
      ),
    );
  }
}
