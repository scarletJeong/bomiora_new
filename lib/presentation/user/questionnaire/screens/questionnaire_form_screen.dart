import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/questionnaire_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../models/health_profile_model.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';

class QuestionnaireFormScreen extends StatefulWidget {
  final HealthProfileModel? existingProfile;
  
  const QuestionnaireFormScreen({
    super.key,
    this.existingProfile,
  });

  @override
  State<QuestionnaireFormScreen> createState() => _QuestionnaireFormScreenState();
}

class _QuestionnaireFormScreenState extends State<QuestionnaireFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  
  UserModel? _currentUser;
  HealthProfileModel? _existingProfile; // 기존 문진표 정보 저장
  int _currentPage = 0;
  bool _isLoading = false;
  
  // 폼 데이터
  final Map<String, dynamic> _formData = {};
  
  // 문진표 섹션들
  late List<QuestionnaireSection> _sections;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _initializeSections();
  }

  void _loadUser() async {
    final user = await AuthService.getUser();
    setState(() {
      _currentUser = user;
    });
    // 사용자 로드 후 기존 문진표 확인
    if (user != null) {
      _checkExistingProfile();
    }
  }

  void _checkExistingProfile() async {
    try {
      print('=== 문진표 확인 시작 ===');
      print('사용자 ID (mb_id): ${_currentUser!.id}');
      
      final existingProfile = await QuestionnaireService.getHealthProfile(_currentUser!.id);
      
      print('API 응답 결과: $existingProfile');
      
      if (existingProfile != null) {
        print('기존 문진표 발견!');
        print('문진표 번호: ${existingProfile.pfNo}');
        print('생년월일: ${existingProfile.answer1}');
        print('성별: ${existingProfile.answer2}');
        
        // 기존 문진표 정보 저장
        setState(() {
          _existingProfile = existingProfile;
        });
        
        _loadExistingData(existingProfile);
      } else {
        print('기존 문진표 없음 - 새로 작성');
      }
    } catch (e) {
      print('기존 문진표 확인 중 오류: $e');
    }
  }

  void _initializeSections() {
    _sections = [
      QuestionnaireSection(
        title: '기본 정보',
        description: '개인 기본 정보를 입력해주세요',
        questions: [
          QuestionnaireQuestion(
            id: 'answer_1',
            question: '생년월일',
            type: 'text',
            hint: 'YYYY-MM-DD 형식으로 입력 ',
          ),
          QuestionnaireQuestion(
            id: 'answer_2',
            question: '성별',
            type: 'radio',
            options: ['남성', '여성'],
          ),
          QuestionnaireQuestion(
            id: 'answer_4',
            question: '키 (cm)',
            type: 'number',
            hint: '예: 170',
          ),
          QuestionnaireQuestion(
            id: 'answer_5',
            question: '현재 몸무게 (kg)',
            type: 'number',
            hint: '예: 70',
          ),
        ],
      ),
      QuestionnaireSection(
        title: '다이어트 목표',
        description: '다이어트 목표를 설정해주세요',
        questions: [
          QuestionnaireQuestion(
            id: 'answer_3',
            question: '목표 감량 체중 (kg)',
            type: 'number',
            hint: '예: 10',
          ),
          QuestionnaireQuestion(
            id: 'answer_6',
            question: '다이어트 예상 기간',
            type: 'grid',
            options: ['3일 이내', '5일 이내', '1주 이내', '2주 이내', '3주 이내', '4주 이내', '5주 이내', '6주 이내', '10주 이내', '10주 이상'],
            columns: 2,
          ),
        ],
      ),
      QuestionnaireSection(
        title: '식습관',
        description: '현재 식습관에 대해 알려주세요',
        questions: [
          QuestionnaireQuestion(
            id: 'answer_7',
            question: '하루 끼니',
            type: 'grid',
            options: ['하루 1식', '하루 2식', '하루 3식', '하루 3식 이상'],
            columns: 2,
          ),
          QuestionnaireQuestion(
            id: 'answer_7_1',
            question: '식사 시간',
            type: 'text',
            hint: '예: 아침 8시, 점심 12시, 저녁 7시',
          ),
          QuestionnaireQuestion(
            id: 'answer_8',
            question: '식습관',
            type: 'grid',
            options: ['과식 주3회 이상', '단 음식(군것질) 주 3회 이상', '야식 주 3회 이상', '카페인음료 1일 3잔 이상'],
            columns: 2,
            allowMultiple: true,
          ),
          QuestionnaireQuestion(
            id: 'answer_9',
            question: '자주 먹는 음식',
            type: 'grid',
            options: ['한식', '중식', '양식', '일식', '양식', '샐러드/다이어트 식단', '육식', '튀김', '해산물', '과일', '빵/떡', '유제품'],
            columns: 2,
            allowMultiple: true,
          ),
        ],
      ),
      QuestionnaireSection(
        title: '운동 및 건강',
        description: '운동 습관과 건강 상태를 알려주세요',
        questions: [
          QuestionnaireQuestion(
            id: 'answer_10',
            question: '운동 습관',
            type: 'grid',
            options: ['일주일 1회 이하', '일주일 2~3회', '일주일 4회 이상'],
            columns: 2,
          ),
          QuestionnaireQuestion(
            id: 'answer_11',
            question: '질병',
            type: 'grid',
            options: ['간질환', '뼈/관절', '심혈관', '당뇨', '소화계통', '호흡계통', '신경계통', '비뇨생식계통', '정신/행동', '피부', '내분비, 영양, 대사질환', '없음'],
            columns: 2,
            allowMultiple: true,
          ),
          QuestionnaireQuestion(
            id: 'answer_12',
            question: '복용 중인 약',
            type: 'grid',
            options: ['혈압약', '항생제', '정신과약', '피부과약', '갑상선약', '당뇨약', '다이어트약', '스테로이드제', '위산분비 억제제', '항혈전제', '피임약', '항히스타민제', '소염진통제', '기타', '없음'],
            columns: 2,
            allowMultiple: true,
          ),
        ],
      ),
      QuestionnaireSection(
        title: '다이어트 경험',
        description: '과거 다이어트 경험에 대해 알려주세요',
        questions: [
          QuestionnaireQuestion(
            id: 'answer_13',
            question: '기존 다이어트 복용약 여부',
            type: 'radio',
            options: ['있음', '없음'],
          ),
          QuestionnaireQuestion(
            id: 'answer_13_medicine',
            question: '복용한 다이어트약명',
            type: 'text',
            hint: '없으면 "없음" 입력',
            isRequired: false,
          ),
          QuestionnaireQuestion(
            id: 'answer_13_period',
            question: '다이어트약 복용 기간',
            type: 'text',
            hint: '예: 3개월',
            isRequired: false,
          ),
          QuestionnaireQuestion(
            id: 'answer_13_dosage',
            question: '다이어트약 복용 횟수',
            type: 'text',
            hint: '예: 하루 3회',
            isRequired: false,
          ),
          QuestionnaireQuestion(
            id: 'answer_13_sideeffect',
            question: '부작용(불편했던 점)',
            type: 'text',
            isRequired: false,
          ),
        ],
      ),
    ];
  }

  void _loadExistingData(HealthProfileModel profile) {
    _formData['answer_1'] = profile.answer1;
    _formData['answer_2'] = profile.answer2;
    _formData['answer_3'] = profile.answer3;
    _formData['answer_4'] = profile.answer4;
    _formData['answer_5'] = profile.answer5;
    _formData['answer_6'] = profile.answer6;
    _formData['answer_7'] = profile.answer7;
    _formData['answer_7_1'] = profile.answer71;
    _formData['answer_8'] = profile.answer8;
    _formData['answer_9'] = profile.answer9;
    _formData['answer_10'] = profile.answer10;
    _formData['answer_11'] = profile.answer11;
    _formData['answer_12'] = profile.answer12;
    _formData['answer_13'] = profile.answer13;
    _formData['answer_13_medicine'] = profile.answer13Medicine;
    _formData['answer_13_period'] = profile.answer13Period;
    _formData['answer_13_dosage'] = profile.answer13Dosage;
    _formData['answer_13_sideeffect'] = profile.answer13Sideeffect;
    
    // UI 업데이트
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        title: Text(_existingProfile != null ? '문진표 수정' : '문진표 작성'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      child: _currentUser == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 진행률 표시
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_currentPage + 1} / ${_sections.length}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${((_currentPage + 1) / _sections.length * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (_currentPage + 1) / _sections.length,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    ],
                  ),
                ),
                
                // 폼 내용
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (page) {
                        setState(() {
                          _currentPage = page;
                        });
                      },
                      itemCount: _sections.length,
                      itemBuilder: (context, index) {
                        return _buildSectionPage(_sections[index]);
                      },
                    ),
                  ),
                ),
                
                // 네비게이션 버튼
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (_currentPage > 0)
                        ElevatedButton(
                          onPressed: _previousPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[300],
                            foregroundColor: Colors.black,
                          ),
                          child: const Text('이전'),
                        )
                      else
                        const SizedBox(width: 80),
                      
                      ElevatedButton(
                        onPressed: _currentPage == _sections.length - 1
                            ? _submitForm
                            : _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(_currentPage == _sections.length - 1 ? '완료' : '다음'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSectionPage(QuestionnaireSection section) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            section.description,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),
          
           ...section.questions.where((question) => _shouldShowQuestion(question)).map((question) => _buildQuestionWidget(question)),
        ],
      ),
    );
  }

  bool _shouldShowQuestion(QuestionnaireQuestion question) {
    // 다이어트약 관련 필드들은 answer_13이 "있음"일 때만 표시
    if (question.id.startsWith('answer_13') && question.id != 'answer_13') {
      return _formData['answer_13'] == '있음';
    }
    return true;
  }

  Widget _buildQuestionWidget(QuestionnaireQuestion question) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.question,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (question.hint != null) ...[
            const SizedBox(height: 4),
            Text(
              question.hint!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
          const SizedBox(height: 12),
          
          _buildInputWidget(question),
        ],
      ),
    );
  }

  Widget _buildInputWidget(QuestionnaireQuestion question) {
    switch (question.type) {
      case 'text':
        return TextFormField(
          initialValue: _formData[question.id] ?? '',
          decoration: InputDecoration(
            hintText: question.placeholder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          validator: question.isRequired
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return '${question.question}을(를) 입력해주세요';
                  }
                  // 생년월일 형식 검증 (YYYY-MM-DD)
                  if (question.id == 'answer_1') {
                    final dateRegex = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                    if (!dateRegex.hasMatch(value)) {
                      return 'YYYY-MM-DD 형식으로 입력해주세요 (예: 1990-01-01)';
                    }
                    // 날짜 유효성 검증
                    try {
                      final dateParts = value.split('-');
                      final year = int.parse(dateParts[0]);
                      final month = int.parse(dateParts[1]);
                      final day = int.parse(dateParts[2]);
                      final date = DateTime(year, month, day);
                      if (date.year != year || date.month != month || date.day != day) {
                        return '올바른 날짜를 입력해주세요';
                      }
                      // 미래 날짜 체크
                      if (date.isAfter(DateTime.now())) {
                        return '미래 날짜는 입력할 수 없습니다';
                      }
                      // 너무 오래된 날짜 체크 (1900년 이전)
                      if (year < 1900) {
                        return '1900년 이후의 날짜를 입력해주세요';
                      }
                    } catch (e) {
                      return '올바른 날짜 형식을 입력해주세요';
                    }
                  }
                  return null;
                }
              : null,
          onSaved: (value) {
            _formData[question.id] = value ?? '';
          },
        );
        
      case 'number':
        return TextFormField(
          initialValue: _formData[question.id] ?? '',
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: question.placeholder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
          validator: question.isRequired
              ? (value) {
                  if (value == null || value.isEmpty) {
                    return '${question.question}을(를) 입력해주세요';
                  }
                  return null;
                }
              : null,
          onSaved: (value) {
            _formData[question.id] = value ?? '';
          },
        );
        
        
      case 'radio':
        return Column(
          children: question.options!.map((option) {
            return RadioListTile<String>(
              title: Text(option),
              value: option,
              groupValue: _formData[question.id],
              onChanged: (value) {
                setState(() {
                  _formData[question.id] = value;
                  // "없음" 선택 시 관련 필드 초기화
                  if (question.id == 'answer_13' && value == '없음') {
                    _formData['answer_13_medicine'] = '';
                    _formData['answer_13_period'] = '';
                    _formData['answer_13_dosage'] = '';
                    _formData['answer_13_sideeffect'] = '';
                  }
                });
              },
            );
          }).toList(),
        );
        
      case 'grid':
        return _buildGridWidget(question);
        
      default:
        return const SizedBox();
    }
  }

  Widget _buildGridWidget(QuestionnaireQuestion question) {
    final columns = question.columns ?? 2;
    final options = question.options ?? [];
    final selectedValues = _formData[question.id] is List 
        ? List<String>.from(_formData[question.id])
        : (_formData[question.id] != null ? [_formData[question.id]] : []).cast<String>();
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 2.5,
      ),
      itemCount: options.length,
      itemBuilder: (context, index) {
        final option = options[index];
        final isSelected = question.allowMultiple 
            ? selectedValues.contains(option)
            : _formData[question.id] == option;
        
        return GestureDetector(
          onTap: () {
            setState(() {
              if (question.allowMultiple) {
                final currentList = List<String>.from(selectedValues);
                if (currentList.contains(option)) {
                  currentList.remove(option);
                } else {
                  currentList.add(option);
                }
                _formData[question.id] = currentList;
              } else {
                _formData[question.id] = option;
              }
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? Color(0xFFFFE5E5) : Colors.white,
              border: Border.all(
                color: isSelected ? Color(0xFFFF9999) : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                option,
                style: TextStyle(
                  color: isSelected ? Color(0xFFFF6B6B) : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }

  void _selectDate(String questionId) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    
    if (picked != null) {
      setState(() {
        _formData[questionId] = '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  void _nextPage() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      setState(() {
        _isLoading = true;
      });
      
      try {
        // TODO: API 호출로 데이터 저장
        await _saveHealthProfile();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_existingProfile != null 
                  ? '문진표가 수정되었습니다' 
                  : '문진표가 저장되었습니다'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('저장 중 오류가 발생했습니다: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveHealthProfile() async {
    final profile = HealthProfileModel(
      pfNo: _existingProfile?.pfNo, // 기존 프로필의 번호 포함
      mbId: _currentUser!.id,
      answer1: _formData['answer_1'] ?? '',
      answer2: _formData['answer_2'] ?? '',
      answer3: _formData['answer_3'] ?? '',
      answer4: _formData['answer_4'] ?? '',
      answer5: _formData['answer_5'] ?? '',
      answer6: _formData['answer_6'] ?? '',
      answer7: _formData['answer_7'] ?? '',
      answer8: _formData['answer_8'] ?? '',
      answer9: _formData['answer_9'] ?? '',
      answer10: _formData['answer_10'] ?? '',
      answer11: _formData['answer_11'] ?? '',
      answer12: _formData['answer_12'] ?? '',
      answer13: _formData['answer_13'] ?? '',
      answer13Period: _formData['answer_13_period'] ?? '',
      answer13Dosage: _formData['answer_13_dosage'] ?? '',
      answer13Medicine: _formData['answer_13_medicine'] ?? '',
      answer71: _formData['answer_7_1'] ?? '',
      answer13Sideeffect: _formData['answer_13_sideeffect'] ?? '',
      pfWdatetime: _existingProfile?.pfWdatetime ?? DateTime.now(),
      pfMdatetime: DateTime.now(),
      pfIp: '', // 서버에서 처리
      pfMemo: '',
    );
    
    if (_existingProfile != null && _existingProfile!.pfNo != null) {
      // 수정
      print('기존 문진표 수정: pfNo=${_existingProfile!.pfNo}');
      await QuestionnaireService.updateHealthProfile(profile);
    } else {
      // 새로 생성
      print('새 문진표 생성');
      await QuestionnaireService.saveHealthProfile(profile);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
