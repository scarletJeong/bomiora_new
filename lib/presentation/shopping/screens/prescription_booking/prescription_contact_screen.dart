import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/health_profile_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../user/healthprofile/models/health_profile_model.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../../core/network/api_client.dart';
import '../../../../main.dart'; // navigatorKey import

/// 연락처 입력 화면 (개인정보)
class PrescriptionContactScreen extends StatefulWidget {
  final String productId;
  final String productName;
  final dynamic selectedOptions; // List<Map<String, dynamic>> 또는 Map<String, dynamic>? (하위 호환성)
  final Map<String, dynamic> formData;
  final HealthProfileModel? existingProfile;
  final DateTime selectedDate;
  final String selectedTime;
  
  const PrescriptionContactScreen({
    super.key,
    required this.productId,
    required this.productName,
    this.selectedOptions,
    required this.formData,
    this.existingProfile,
    required this.selectedDate,
    required this.selectedTime,
  });

  @override
  State<PrescriptionContactScreen> createState() => _PrescriptionContactScreenState();
}

class _PrescriptionContactScreenState extends State<PrescriptionContactScreen> {
  UserModel? _currentUser;
  bool _isLoading = false;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')),
      );
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
      print('========================================');
      print('📝 [건강프로필 수정] 전송할 데이터 확인');
      print('========================================');
      print('기본 정보:');
      print('  - 생년월일: ${widget.formData['birthDate']}');
      print('  - 성별: ${widget.formData['gender']}');
      print('  - 목표 체중: ${widget.formData['targetWeight']}kg');
      print('  - 키: ${widget.formData['height']}cm');
      print('  - 현재 체중: ${widget.formData['currentWeight']}kg');
      print('  - 다이어트 기간: ${widget.formData['dietPeriod']}');
      print('');
      print('식습관:');
      print('  - 하루 식사 횟수: ${widget.formData['mealsPerDay']}');
      print('  - 식사 시간: ${widget.formData['mealTimes']}');
      print('  - 식습관: ${widget.formData['eatingHabits']}');
      print('  - 자주 먹는 음식: ${widget.formData['foodPreference']}');
      print('');
      print('운동/건강:');
      print('  - 운동 빈도: ${widget.formData['exerciseFrequency']}');
      print('  - 질병: ${widget.formData['diseases']}');
      print('  - 복용 중인 약: ${widget.formData['medications']}');
      if (widget.formData['medications'] != null && 
          (widget.formData['medications'] as List).any((m) => m == '기타')) {
        print('  - 복용약(기타): ${widget.formData['medicationsEtc']}');
      }
      print('');
      print('다이어트 경험:');
      print('  - 다이어트약 복용 경험: ${widget.formData['dietExperience']}');
      if (widget.formData['dietExperience'] == '있음') {
        print('  - 약 이름: ${widget.formData['dietMedicine']}');
        print('  - 복용 기간: ${widget.formData['dietPeriodMonths']}');
        print('  - 복용 횟수: ${widget.formData['dietDosage']}');
        print('  - 부작용: ${widget.formData['dietSideEffect']}');
      }
      print('');
      print('예약 정보:');
      print('  - 날짜: ${widget.selectedDate}');
      print('  - 시간: ${widget.selectedTime}');
      print('');
      // 옵션 정보 처리 (리스트 또는 단일 Map)
      List<Map<String, dynamic>> optionsList = [];
      if (widget.selectedOptions is List) {
        optionsList = List<Map<String, dynamic>>.from(widget.selectedOptions as List);
      } else if (widget.selectedOptions is Map) {
        optionsList = [Map<String, dynamic>.from(widget.selectedOptions as Map)];
      }
      
      print('옵션 정보:');
      for (int i = 0; i < optionsList.length; i++) {
        final option = optionsList[i];
        print('  옵션 ${i + 1}:');
        print('    - 옵션 ID: ${option['id']}');
        print('    - 옵션명: ${option['name']}');
        print('    - 옵션가: ${option['price']}원');
        print('    - 수량: ${option['quantity']}');
        print('    - 총 가격: ${option['totalPrice']}원');
      }
      print('========================================');
      
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
        answer8: (widget.formData['eatingHabits'] as List?)?.join('|') ?? '',
        answer9: (widget.formData['foodPreference'] as List?)?.join('|') ?? '',
        answer10: widget.formData['exerciseFrequency'] ?? '',
        answer11: (widget.formData['diseases'] as List?)?.join('|') ?? '',
        answer12: (widget.formData['medications'] as List?)?.join('|') ?? '',
        answer13: widget.formData['dietExperience'] ?? '없음',
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
        'answer8': (widget.formData['eatingHabits'] as List?)?.join('|') ?? '',
        'answer9': (widget.formData['foodPreference'] as List?)?.join('|') ?? '',
        'answer10': widget.formData['exerciseFrequency'] ?? '',
        'answer11': (widget.formData['diseases'] as List?)?.join('|') ?? '',
        'answer12': (widget.formData['medications'] as List?)?.join('|') ?? '',
        'answer13': widget.formData['dietExperience'] ?? '없음',
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('예약 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  /// 네비게이션 실패 시 대체 방법 (SnackBar 표시)
  void _showNavigationFallback() {
    // mounted 체크 후 SnackBar 표시 시도
    if (!mounted) return;
    
    try {
      // 현재 context를 안전하게 가져오기
      BuildContext? currentContext;
      try {
        if (mounted) {
          currentContext = context;
        }
      } catch (e) {
        print('⚠️ [context 접근 오류 in fallback]: $e');
        return;
      }
      
      if (currentContext != null && mounted) {
        try {
          ScaffoldMessenger.of(currentContext).showSnackBar(
            const SnackBar(
              content: Text('장바구니에 추가되었습니다. 장바구니로 이동하세요.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } catch (e) {
          print('⚠️ [SnackBar 표시 오류]: $e');
        }
      }
    } catch (e) {
      print('⚠️ [SnackBar 표시 전체 오류]: $e');
      // SnackBar도 실패하면 로그만 출력
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Material(
              color: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '연락처를 한번 더 확인해주세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '아래 기입하신 연락처가 맞으신가요?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[300]!, width: 1),
                      ),
                    ),
                    child: Text(
                      _currentUser?.phone ?? '010-0000-0000',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '연락처를 잘못입력하시면 전화 처방이 어려울 수 있으며,\n이로 인한 책임은 고객님에게 있음을 안내드립니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(color: Colors.grey[400]!),
                          ),
                          child: const Text(
                            '수정',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (_reservationData == null) return;
                            
                            // 1. 먼저 다이얼로그 닫기
                            Navigator.of(context).pop();
                            
                            try {
                              // 2. 로딩 표시
                              if (mounted) {
                                setState(() => _isLoading = true);
                              }
                              
                              // 3. 여러 옵션을 각각 장바구니에 추가
                              final optionsList = _reservationData!['options'] as List<Map<String, dynamic>>? ?? [];
                              
                              if (optionsList.isEmpty) {
                                print('📦 [장바구니 추가 요청] 데이터: $_reservationData');
                                final response = await ApiClient.post(
                                  '/api/cart/healthprofile', 
                                  _reservationData!
                                );
                                print('✅ [장바구니 추가 완료] 응답: $response');
                              } else {
                                // 각 옵션마다 별도로 장바구니에 추가
                                int successCount = 0;
                                int failCount = 0;
                                
                                for (int i = 0; i < optionsList.length; i++) {
                                  if (!mounted) break;
                                  
                                  final option = optionsList[i];
                                  final optionData = Map<String, dynamic>.from(_reservationData!);
                                  
                                  optionData['option_id'] = option['id'];
                                  optionData['option_text'] = option['name'];
                                  optionData['option_price'] = option['price'];
                                  optionData['quantity'] = option['quantity'];
                                  optionData['price'] = option['totalPrice'];
                                  
                                  print('📦 [장바구니 추가 요청 ${i + 1}/${optionsList.length}] 옵션: ${option['name']}');
                                  
                                  try {
                                    final response = await ApiClient.post(
                                      '/api/cart/healthprofile', 
                                      optionData
                                    );
                                    
                                    if (response.statusCode == 200 || response.statusCode == 201) {
                                      try {
                                        final responseData = json.decode(response.body) as Map<String, dynamic>?;
                                        if (responseData != null && responseData['success'] == true) {
                                          print('✅ [장바구니 추가 완료 ${i + 1}/${optionsList.length}]');
                                          successCount++;
                                        } else {
                                          failCount++;
                                        }
                                      } catch (e) {
                                        successCount++;
                                      }
                                    } else {
                                      failCount++;
                                    }
                                  } catch (e) {
                                    print('❌ [장바구니 추가 실패 ${i + 1}/${optionsList.length}]: $e');
                                    failCount++;
                                  }
                                }
                                
                                print('📊 [장바구니 추가 결과] 성공: $successCount, 실패: $failCount');
                                
                                if (failCount > 0 && mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('일부 옵션이 추가되지 않았습니다. ($failCount개 실패)'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              }
                              
                              // 4. 잠시 대기
                              await Future.delayed(const Duration(milliseconds: 500));
                              
                              // 5. 장바구니로 이동
                              if (!mounted) return;
                              
                              // 웹/모바일 공통: named route로 장바구니 화면 이동
                              // 웹에서는 URL이 /cart 로 갱신됨
                              Future.microtask(() {
                                try {
                                  final navigator = navigatorKey.currentState;
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
                                    print('⚠️ [네비게이션] Navigator가 null입니다');
                                  }
                                } catch (e) {
                                  print('⚠️ [네비게이션 오류]: $e');
                                  _showNavigationFallback();
                                }
                              });
                              
                            } catch (e) {
                              print('❌ [전체 오류]: $e');
                              // 웹 환경에서는 context 사용하지 않음 (오류 방지)
                              if (mounted) {
                                try {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('장바구니에 추가되었습니다. 메뉴에서 확인하세요.'),
                                      backgroundColor: Colors.green,
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                                } catch (e2) {
                                  print('⚠️ [SnackBar 표시 오류]: $e2');
                                }
                              }
                            } finally {
                              if (mounted) {
                                setState(() => _isLoading = false);
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF3787),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            '다음',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          ),
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        title: const Text(
          '처방예약하기',
          style: TextStyle(
            fontSize: 18,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      child: Column(
        children: [
          // 진행률 표시
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  '04 개인정보',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFFFF3787),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Row(
                  children: List.generate(4, (index) {
                    final stepIndex = index + 1;
                    final isActive = stepIndex == 4; // 개인정보는 4번
                    final isCompleted = stepIndex < 4; // 3번까지 완료
                    return Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive ? const Color(0xFFFF3787) : 
                                   isCompleted ? const Color(0xFFFF3787) : Colors.grey[300],
                          ),
                          child: Center(
                            child: Text(
                              '$stepIndex',
                              style: TextStyle(
                                color: (isActive || isCompleted) ? Colors.white : Colors.grey[600],
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        if (index < 3) const SizedBox(width: 8),
                      ],
                    );
                  }),
                ),
              ],
            ),
          ),
          // 페이지 컨텐츠
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 예약 정보
                  const Text(
                    '예약 정보',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      () {
                        final weekdays = ['월', '화', '수', '목', '금', '토', '일'];
                        final weekday = weekdays[widget.selectedDate.weekday - 1];
                        return '${widget.selectedDate.year}.${widget.selectedDate.month}.${widget.selectedDate.day}($weekday)  ${widget.selectedTime}';
                      }(),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // 연락처 입력
                  const Text(
                    '전화상담 받으실 연락처를 입력해 주세요',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // 성함
                  const Text(
                    '성함',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    decoration: InputDecoration(
                      hintText: '홍길동',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                    controller: TextEditingController(text: _currentUser?.name ?? ''),
                    readOnly: true,
                  ),
                  const SizedBox(height: 16),
                  
                  // 연락처
                  const Text(
                    '연락처',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: '010',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          controller: TextEditingController(
                            text: () {
                              final phone = _currentUser?.phone?.replaceAll('-', '') ?? '';
                              return phone.length >= 3 ? phone.substring(0, 3) : '010';
                            }(),
                          ),
                          readOnly: true,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('-', style: TextStyle(fontSize: 18)),
                      ),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: '1000',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          controller: TextEditingController(
                            text: () {
                              final phone = _currentUser?.phone?.replaceAll('-', '') ?? '';
                              return phone.length >= 7 ? phone.substring(3, 7) : '';
                            }(),
                          ),
                          readOnly: true,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text('-', style: TextStyle(fontSize: 18)),
                      ),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: '5678',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          controller: TextEditingController(
                            text: () {
                              final phone = _currentUser?.phone?.replaceAll('-', '') ?? '';
                              return phone.length >= 11 ? phone.substring(7, 11) : '';
                            }(),
                          ),
                          readOnly: true,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // 개인정보 취급 동의 (작은 글씨, 상자 없이)
                  Center(
                    child: Text(
                      '개인정보로 취급 및 의뢰해 동의합니다',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      '개인정보는 귀하의 정보를 안전하게 저장하기 위하여 관리합니다.\n수집된 개인정보는 더 나은 서비스 제공을 위해 사용될 수 있으며, 제3자에게 제공되지 않습니다.',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[500],
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 하단 버튼
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          side: BorderSide(color: Colors.grey[300]!),
                        ),
                        child: const Text(
                          '이전',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitBooking,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF3787),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          disabledBackgroundColor: Colors.grey[300],
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                '완료',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  '결제를 완료하셔야 예약이 확정됩니다.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

