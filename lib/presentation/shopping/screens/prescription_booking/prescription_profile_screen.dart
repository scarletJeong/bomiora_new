import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/health_profile_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../user/healthprofile/models/health_profile_model.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import 'prescription_time_screen.dart';

/// 프로필 작성 화면 (5개 서브 페이지)
class PrescriptionProfileScreen extends StatefulWidget {
  final String productId;
  final String productName;
  final Map<String, dynamic>? selectedOptions;
  
  const PrescriptionProfileScreen({
    super.key,
    required this.productId,
    required this.productName,
    this.selectedOptions,
  });

  @override
  State<PrescriptionProfileScreen> createState() => _PrescriptionProfileScreenState();
}

class _PrescriptionProfileScreenState extends State<PrescriptionProfileScreen> {
  final PageController _pageController = PageController();
  
  UserModel? _currentUser;
  HealthProfileModel? _existingProfile;
  int _currentPage = 0; // 0~4 (5개 서브 페이지)
  bool _isLoading = false;
  
  // 폼 데이터
  final Map<String, dynamic> _formData = {};
  
  @override
  void initState() {
    super.initState();
    _loadUserAndProfile();
  }
  
  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
  
  Future<void> _loadUserAndProfile() async {
    setState(() => _isLoading = true);
    
    try {
      final user = await AuthService.getUser();
      if (!mounted) return;
      
      setState(() => _currentUser = user);
      
      if (user != null) {
        final profile = await HealthProfileService.getHealthProfile(user.id);
        if (!mounted) return;
        
        if (profile != null) {
          setState(() => _existingProfile = profile);
          _loadExistingData(profile);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('데이터 로드 실패: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  void _loadExistingData(HealthProfileModel profile) {
    setState(() {
      _formData['birthDate'] = profile.answer1;
      // 성별 변환: "여성" -> "F", "남성" -> "M"
      if (profile.answer2 == '여성' || profile.answer2 == 'F') {
        _formData['gender'] = 'F';
      } else if (profile.answer2 == '남성' || profile.answer2 == 'M') {
        _formData['gender'] = 'M';
      }
      _formData['height'] = profile.answer4;
      _formData['currentWeight'] = profile.answer5;
      _formData['targetWeight'] = profile.answer3;
      _formData['dietPeriod'] = profile.answer6;
      _formData['mealsPerDay'] = profile.answer7;
      _formData['mealTimes'] = profile.answer71;
      _formData['eatingHabits'] = profile.answer8?.split('|') ?? [];
      _formData['foodPreference'] = profile.answer9?.split('|') ?? [];
      _formData['exerciseFrequency'] = profile.answer10;
      _formData['diseases'] = profile.answer11?.split('|') ?? [];
      _formData['medications'] = profile.answer12?.split('|') ?? [];
      _formData['dietExperience'] = profile.answer13;
      _formData['dietMedicine'] = profile.answer13Medicine;
      _formData['dietPeriodMonths'] = profile.answer13Period;
      _formData['dietDosage'] = profile.answer13Dosage;
      _formData['dietSideEffect'] = profile.answer13Sideeffect;
    });
  }
  
  void _nextPage() {
    if (_currentPage < 4) {
      if (_validateCurrentPage()) {
        setState(() => _currentPage++);
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      _goToTimeSelection();
    }
  }
  
  void _previousPage() {
    if (_currentPage > 0) {
      setState(() => _currentPage--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }
  
  bool _validateCurrentPage() {
    switch (_currentPage) {
      case 0: // 기본 정보
        if (_formData['birthDate'] == null || _formData['gender'] == null ||
            _formData['height'] == null || _formData['currentWeight'] == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('모든 항목을 입력해주세요')),
          );
          return false;
        }
        return true;
      case 1: // 다이어트 목표
        if (_formData['targetWeight'] == null || _formData['dietPeriod'] == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('모든 항목을 입력해주세요')),
          );
          return false;
        }
        return true;
      case 2: // 식습관
        if (_formData['mealsPerDay'] == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('하루 끼니를 선택해주세요')),
          );
          return false;
        }
        return true;
      case 3: // 운동 및 건강
        if (_formData['exerciseFrequency'] == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('운동 습관을 선택해주세요')),
          );
          return false;
        }
        return true;
      case 4: // 다이어트 경험
        if (_formData['dietExperience'] == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('다이어트약 복용 경험을 선택해주세요')),
          );
          return false;
        }
        if (_formData['dietExperience'] == '있음') {
          if (_formData['dietMedicine'] == null || _formData['dietPeriodMonths'] == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('다이어트약 정보를 입력해주세요')),
            );
            return false;
          }
        }
        return true;
      default:
        return true;
    }
  }
  
  void _goToTimeSelection() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PrescriptionTimeScreen(
          productId: widget.productId,
          productName: widget.productName,
          selectedOptions: widget.selectedOptions,
          formData: _formData,
          existingProfile: _existingProfile,
        ),
      ),
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
    
    final progress = ((_currentPage + 1) / 5 * 100).toInt();
    
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
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      '02 프로필작성',
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFFFF3787),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Row(
                      children: List.generate(4, (index) {
                        final stepIndex = index + 1;
                        final isActive = stepIndex == 2; // 프로필작성은 2번
                        return Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isActive ? const Color(0xFFFF3787) : Colors.grey[300],
                              ),
                              child: Center(
                                child: Text(
                                  '$stepIndex',
                                  style: TextStyle(
                                    color: isActive ? Colors.white : Colors.grey[600],
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: (_currentPage + 1) / 5,
                          backgroundColor: Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF3787)),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$progress%',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF3787),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // 페이지 컨텐츠
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (index) => setState(() => _currentPage = index),
              children: [
                _buildPage1BasicInfo(),
                _buildPage2DietGoal(),
                _buildPage3EatingHabits(),
                _buildPage4ExerciseHealth(),
                _buildPage5DietExperience(),
              ],
            ),
          ),
          // 하단 버튼
          _buildBottomButtons(),
        ],
      ),
    );
  }
  
  /// 페이지 1: 기본 정보
  Widget _buildPage1BasicInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '기본 정보',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '개인 기본 정보를 입력해주세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          
          // 생년월일
          const Text(
            '생년월일',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildTextField(
                  hint: '년',
                  example: '1999',
                  maxLength: 4,
                  keyboardType: TextInputType.number,
                  initialValue: _formData['birthDate']?.substring(0, 4),
                  onChanged: (value) {
                    _formData['birthYear'] = value;
                    _updateBirthDate();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                  hint: '월',
                  example: '09',
                  maxLength: 2,
                  keyboardType: TextInputType.number,
                  initialValue: _formData['birthDate']?.substring(4, 6),
                  onChanged: (value) {
                    _formData['birthMonth'] = value;
                    _updateBirthDate();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                  hint: '일',
                  example: '09',
                  maxLength: 2,
                  keyboardType: TextInputType.number,
                  initialValue: _formData['birthDate']?.substring(6, 8),
                  onChanged: (value) {
                    _formData['birthDay'] = value;
                    _updateBirthDate();
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // 성별
          const Text(
            '성별',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildRadioButton(
                  label: '남성',
                  value: 'M',
                  groupValue: _formData['gender'],
                  onChanged: (value) => setState(() => _formData['gender'] = value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRadioButton(
                  label: '여성',
                  value: 'F',
                  groupValue: _formData['gender'],
                  onChanged: (value) => setState(() => _formData['gender'] = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // 키
          const Text(
            '키 (cm)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '예: 170',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          _buildTextField(
            hint: '155',
            maxLength: 3,
            keyboardType: TextInputType.number,
            initialValue: _formData['height'],
            onChanged: (value) => _formData['height'] = value,
          ),
          const SizedBox(height: 24),
          
          // 현재 몸무게
          const Text(
            '현재 몸무게 (kg)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '예: 70',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          _buildTextField(
            hint: '55',
            maxLength: 3,
            keyboardType: TextInputType.number,
            initialValue: _formData['currentWeight'],
            onChanged: (value) => _formData['currentWeight'] = value,
          ),
        ],
      ),
    );
  }
  
  void _updateBirthDate() {
    final year = _formData['birthYear'] ?? '';
    final month = _formData['birthMonth'] ?? '';
    final day = _formData['birthDay'] ?? '';
    
    if (year.length == 4 && month.length == 2 && day.length == 2) {
      _formData['birthDate'] = '$year$month$day';
    }
  }
  
  /// 페이지 2: 다이어트 목표
  Widget _buildPage2DietGoal() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '다이어트 목표',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '다이어트 목표를 설정해주세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          
          // 목표 감량 체중
          const Text(
            '목표 감량 체중 (kg)',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '예: 10',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          _buildTextField(
            hint: '50',
            maxLength: 3,
            keyboardType: TextInputType.number,
            initialValue: _formData['targetWeight'],
            onChanged: (value) => _formData['targetWeight'] = value,
          ),
          const SizedBox(height: 24),
          
          // 다이어트 예상 기간
          const Text(
            '다이어트 예상 기간',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildOptionGrid([
            '3일 이내',
            '5일 이내',
            '1주 이내',
            '2주 이내',
            '3주 이내',
            '4주 이내',
            '5주 이내',
            '6주 이내',
            '10주 이내',
            '10주 이상',
          ], _formData['dietPeriod'], (value) {
            setState(() => _formData['dietPeriod'] = value);
          }),
        ],
      ),
    );
  }
  
  /// 페이지 3: 식습관
  Widget _buildPage3EatingHabits() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '식습관',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '현재 식습관에 대해 알려주세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          
          // 하루 끼니
          const Text(
            '하루 끼니',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildOptionGrid([
            '하루 1식',
            '하루 2식',
            '하루 3식',
            '하루 3식 이상',
          ], _formData['mealsPerDay'], (value) {
            setState(() => _formData['mealsPerDay'] = value);
          }),
          const SizedBox(height: 24),
          
          // 식사 시간
          const Text(
            '식사 시간',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildMealTimeField('1식', 0)),
              const SizedBox(width: 8),
              Expanded(child: _buildMealTimeField('2식', 1)),
              const SizedBox(width: 8),
              Expanded(child: _buildMealTimeField('3식', 2)),
              const SizedBox(width: 8),
              Expanded(child: _buildMealTimeField('기타', 3)),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '*해당되는 입력란에만 입력하세요.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          
          // 식습관
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '식습관',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  '*중복선택가능',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMultiSelectGrid([
            '과식 주3회 이상',
            '단 음식(구조식) 주 3회 이상',
            '야식 주 3회 이상',
            '카페인음료 1일3잔 이상',
          ], _formData['eatingHabits'] ?? [], (values) {
            setState(() => _formData['eatingHabits'] = values);
          }),
          const SizedBox(height: 24),
          
          // 자주먹는 음식
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '자주먹는 음식',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  '*중복선택가능',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMultiSelectGrid([
            '한식',
            '양식',
            '중식',
            '샐러드/다이어트식단',
            '빵/떡',
            '육식',
            '해산물',
            '튀김',
            '과일',
            '유제품',
          ], _formData['foodPreference'] ?? [], (values) {
            setState(() => _formData['foodPreference'] = values);
          }),
        ],
      ),
    );
  }
  
  Widget _buildMealTimeField(String label, int index) {
    final times = _formData['mealTimes']?.split('|') ?? ['', '', '', ''];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        TextField(
          decoration: InputDecoration(
            hintText: '00:00',
            hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          style: const TextStyle(fontSize: 14),
          keyboardType: TextInputType.number,
          maxLength: 5,
          buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
          controller: TextEditingController(text: times[index]),
          onChanged: (value) {
            times[index] = value;
            _formData['mealTimes'] = times.join('|');
          },
        ),
      ],
    );
  }
  
  /// 페이지 4: 운동 및 건강
  Widget _buildPage4ExerciseHealth() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '운동 및 건강',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '운동 습관과 건강 상태를 알려주세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          
          // 운동 습관
          const Text(
            '운동 습관',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildOptionGrid([
            '일주일 1회 이하',
            '일주일 2~3회',
            '일주일 4회 이상',
          ], _formData['exerciseFrequency'], (value) {
            setState(() => _formData['exerciseFrequency'] = value);
          }),
          const SizedBox(height: 24),
          
          // 질병
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '질병',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  '*중복선택가능',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMultiSelectGrid([
            '간질환',
            '폐/간질',
            '심혈관',
            '당뇨',
            '소화계통',
            '호흡계통',
            '신경계통',
            '비뇨생식계통',
          ], _formData['diseases'] ?? [], (values) {
            setState(() => _formData['diseases'] = values);
          }),
          const SizedBox(height: 24),
          
          // 복용 중인 약
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                '복용 중인 약',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  '*중복선택가능',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildMultiSelectGrid([
            '혈압약',
            '갑상선약',
            '항생제',
            '당뇨약',
            '정신과약',
            '특이질환',
            '피부과약',
            '스테로이드제',
            '위산분비 억제제',
            '항히스타민제',
            '항혈전제',
            '소염진통제',
            '피임약',
            '없음',
            '기타',
          ], _formData['medications'] ?? [], (values) {
            setState(() => _formData['medications'] = values);
          }),
          if (_formData['medications'] != null && 
              (_formData['medications'] as List<dynamic>).any((m) => m == '기타')) ...[
            const SizedBox(height: 12),
            _buildTextField(
              hint: '기타 복용약을 입력해주세요',
              maxLength: 100,
              initialValue: _formData['medicationsEtc'],
              onChanged: (value) => _formData['medicationsEtc'] = value,
            ),
          ],
        ],
      ),
    );
  }
  
  /// 페이지 5: 다이어트 경험
  Widget _buildPage5DietExperience() {
    final hasExperience = _formData['dietExperience'] == '있음';
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '다이어트 경험',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '과거 다이어트 경험에 대해 알려주세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 32),
          
          // 기존 다이어트 복용약 여부
          const Text(
            '기존 다이어트 복용약 여부',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildRadioButton(
                  label: '있음',
                  value: '있음',
                  groupValue: _formData['dietExperience'],
                  onChanged: (value) => setState(() => _formData['dietExperience'] = value),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRadioButton(
                  label: '없음',
                  value: '없음',
                  groupValue: _formData['dietExperience'],
                  onChanged: (value) => setState(() => _formData['dietExperience'] = value),
                ),
              ),
            ],
          ),
          
          if (hasExperience) ...[
            const SizedBox(height: 24),
            
            // 복용한 다이어트약명
            const Text(
              '복용한 다이어트약명',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildTextField(
              hint: '다이어트약 이름',
              maxLength: 50,
              initialValue: _formData['dietMedicine'],
              onChanged: (value) => _formData['dietMedicine'] = value,
            ),
            const SizedBox(height: 24),
            
            // 다이어트약 복용 기간
            const Text(
              '다이어트약 복용 기간',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '예: 3개월 또는 11',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            _buildTextField(
              hint: '3개월',
              maxLength: 20,
              initialValue: _formData['dietPeriodMonths'],
              onChanged: (value) => _formData['dietPeriodMonths'] = value,
            ),
            const SizedBox(height: 24),
            
            // 다이어트약 복용 횟수
            const Text(
              '다이어트약 복용 횟수',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '예: 하루 3회',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            _buildTextField(
              hint: '하루 3회',
              maxLength: 20,
              initialValue: _formData['dietDosage'],
              onChanged: (value) => _formData['dietDosage'] = value,
            ),
            const SizedBox(height: 24),
            
            // 부작용
            const Text(
              '부작용(불편했던 점)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            _buildTextField(
              hint: '부작용을 입력해주세요',
              maxLines: 3,
              initialValue: _formData['dietSideEffect'],
              onChanged: (value) => _formData['dietSideEffect'] = value,
            ),
          ],
        ],
      ),
    );
  }
  
  /// 하단 버튼
  Widget _buildBottomButtons() {
    return Container(
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
      child: Row(
        children: [
          if (_currentPage > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousPage,
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
          if (_currentPage > 0) const SizedBox(width: 12),
          Expanded(
            flex: _currentPage > 0 ? 1 : 1,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3787),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: Text(
                '다음',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  /// 공통 텍스트 필드
  Widget _buildTextField({
    required String hint,
    String? example,
    int? maxLength,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? initialValue,
    required Function(String) onChanged,
  }) {
    return TextField(
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey[400]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFF3787), width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      style: const TextStyle(fontSize: 14),
      keyboardType: keyboardType,
      maxLength: maxLength,
      maxLines: maxLines,
      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
      controller: TextEditingController(text: initialValue),
      onChanged: onChanged,
    );
  }
  
  /// 라디오 버튼
  Widget _buildRadioButton({
    required String label,
    required String value,
    required String? groupValue,
    required Function(String?) onChanged,
  }) {
    final isSelected = value == groupValue;
    return InkWell(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFFFF3787) : Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFFFF3787),
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? const Color(0xFFFF3787) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// 옵션 그리드 (단일 선택)
  Widget _buildOptionGrid(
    List<String> options,
    String? selectedValue,
    Function(String) onSelect,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final option = options[index];
        final isSelected = option == selectedValue;
        
        return InkWell(
          onTap: () => onSelect(option),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFFF0F5) : Colors.white,
              border: Border.all(
                color: isSelected ? const Color(0xFFFF3787) : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFFFF3787) : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
  
  /// 옵션 그리드 (다중 선택)
  Widget _buildMultiSelectGrid(
    List<String> options,
    List<String> selectedValues,
    Function(List<String>) onSelect,
  ) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 2.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final option = options[index];
        final isSelected = selectedValues.contains(option);
        
        return InkWell(
          onTap: () {
            final newValues = List<String>.from(selectedValues);
            if (isSelected) {
              newValues.remove(option);
            } else {
              newValues.add(option);
            }
            onSelect(newValues);
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFFFF0F5) : Colors.white,
              border: Border.all(
                color: isSelected ? const Color(0xFFFF3787) : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFFFF3787) : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}

