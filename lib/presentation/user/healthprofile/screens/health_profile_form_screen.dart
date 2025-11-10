import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/health_profile_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../models/health_profile_model.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';

class HealthProfileFormScreen extends StatefulWidget {
  final HealthProfileModel? existingProfile;
  
  const HealthProfileFormScreen({
    super.key,
    this.existingProfile,
  });

  @override
  State<HealthProfileFormScreen> createState() => _HealthProfileFormScreenState();
}

class _HealthProfileFormScreenState extends State<HealthProfileFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final PageController _pageController = PageController();
  
  UserModel? _currentUser;
  HealthProfileModel? _existingProfile; // 기존 문진표 정보 저장
  int _currentPage = 0;
  bool _isLoading = false;
  
  // 폼 데이터
  final Map<String, dynamic> _formData = {};
  
  // 다이어트 경험 관련 필드 백업 (있음 → 없음 → 있음 선택 시 복원용)
  final Map<String, String> _backupAnswer13Fields = {};
  
  // 건강 프로필 섹션들
  late List<HealthProfileSection> _sections;

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
    
    // 전달받은 기존 문진표가 있으면 우선 사용
    if (widget.existingProfile != null) {
      print('=== 전달받은 기존 문진표 사용 ===');
      print('문진표 번호: ${widget.existingProfile!.pfNo}');
      setState(() {
        _existingProfile = widget.existingProfile;
      });
      _loadExistingData(widget.existingProfile!);
    } else if (user != null) {
      // 전달받은 문진표가 없으면 API에서 확인
      _checkExistingProfile();
    }
  }

  void _checkExistingProfile() async {
    try {
      print('=== 문진표 확인 시작 ===');
      print('사용자 ID (mb_id): ${_currentUser!.id}');
      
      final existingProfile = await HealthProfileService.getHealthProfile(_currentUser!.id);
      
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
      HealthProfileSection(
        title: '기본 정보',
        description: '개인 기본 정보를 입력해주세요',
        questions: [
          HealthProfileQuestion(
            id: 'answer_1',
            question: '생년월일',
            type: 'birthdate', 
          ),
          HealthProfileQuestion(
            id: 'answer_2',
            question: '성별',
            type: 'radio',
            options: ['남성', '여성'],
          ),
          HealthProfileQuestion(
            id: 'answer_4',
            question: '키 (cm)',
            type: 'number',
            hint: '예: 170',
          ),
          HealthProfileQuestion(
            id: 'answer_5',
            question: '현재 몸무게 (kg)',
            type: 'number',
            hint: '예: 70',
          ),
        ],
      ),
      HealthProfileSection(
        title: '다이어트 목표',
        description: '다이어트 목표를 설정해주세요',
        questions: [
          HealthProfileQuestion(
            id: 'answer_3',
            question: '목표 감량 체중 (kg)',
            type: 'number',
            hint: '예: 10',
          ),
          HealthProfileQuestion(
            id: 'answer_6',
            question: '다이어트 예상 기간',
            type: 'grid',
            options: ['3일 이내', '5일 이내', '1주 이내', '2주 이내', '3주 이내', '4주 이내', '5주 이내', '6주 이내', '10주 이내', '10주 이상'],
            columns: 2,
          ),
        ],
      ),
      HealthProfileSection(
        title: '식습관',
        description: '현재 식습관에 대해 알려주세요',
        questions: [
          HealthProfileQuestion(
            id: 'answer_7',
            question: '하루 끼니',
            type: 'grid',
            options: ['하루 1식', '하루 2식', '하루 3식', '하루 3식 이상'],
            columns: 2,
          ),
          HealthProfileQuestion(
            id: 'answer_7_1',
            question: '식사 시간',
            type: 'mealtime',
          ),
          HealthProfileQuestion(
            id: 'answer_8',
            question: '식습관',
            type: 'grid',
            options: ['과식 주3회 이상', '단 음식(군것질) 주 3회 이상', '야식 주 3회 이상', '카페인음료 1일 3잔 이상', '해당없음'],
            columns: 2,
            allowMultiple: true,
          ),
          HealthProfileQuestion(
            id: 'answer_9',
            question: '자주 먹는 음식',
            type: 'grid',
            options: ['한식', '양식', '중식', '샐러드/다이어트식단', '빵/떡', '육식', '해산물', '튀김', '과일', '유제품'],
            columns: 2,
            allowMultiple: true,
          ),
        ],
      ),
      HealthProfileSection(
        title: '운동 및 건강',
        description: '운동 습관과 건강 상태를 알려주세요',
        questions: [
          HealthProfileQuestion(
            id: 'answer_10',
            question: '운동 습관',
            type: 'grid',
            options: ['일주일 1회 이하', '일주일 2~3회', '일주일 4회 이상'],
            columns: 2,
          ),
          HealthProfileQuestion(
            id: 'answer_11',
            question: '질병',
            type: 'grid',
            options: ['간질환', '뼈/관절', '심혈관', '당뇨', '소화계통', '호흡계통', '신경계통', '비뇨생식계통', '정신/행동', '피부', '내분비, 영양, 대사질환', '없음'],
            columns: 2,
            allowMultiple: true,
          ),
          HealthProfileQuestion(
            id: 'answer_12',
            question: '복용 중인 약',
            type: 'grid',
            options: ['혈압약', '갑상선약', '항생제', '당뇨약', '정신과약', '다이어트약', '피부과약', '스테로이드제', '위산분비 억제제', '항히스타민제', '항혈전제', '소염진통제', '피임약', '없음', '기타'],
            columns: 2,
            allowMultiple: true,
          ),
          HealthProfileQuestion(
            id: 'answer_12_other',
            question: '기타 (복용 중인 약)',
            type: 'text',
            hint: '기타 약물명을 입력해주세요',
            isRequired: false,
          ),
        ],
      ),
      HealthProfileSection(
        title: '다이어트 경험',
        description: '과거 다이어트 경험에 대해 알려주세요',
        questions: [
          HealthProfileQuestion(
            id: 'answer_13',
            question: '기존 다이어트 복용약 여부',
            type: 'radio',
            options: ['있음', '없음'],
          ),
          HealthProfileQuestion(
            id: 'answer_13_medicine',
            question: '복용한 다이어트약명',
            type: 'text',
            isRequired: false,
          ),
          HealthProfileQuestion(
            id: 'answer_13_period',
            question: '다이어트약 복용 기간',
            type: 'text',
            hint: '예: 3개월',
            isRequired: false,
          ),
          HealthProfileQuestion(
            id: 'answer_13_dosage',
            question: '다이어트약 복용 횟수',
            type: 'text',
            hint: '예: 하루 3회',
            isRequired: false,
          ),
          HealthProfileQuestion(
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
    // 생년월일 파싱 (YYYYMMDD 형식)
    if (profile.answer1.isNotEmpty && profile.answer1.length >= 8) {
      _formData['birth_year'] = profile.answer1.substring(0, 4);
      _formData['birth_month'] = profile.answer1.substring(4, 6);
      _formData['birth_day'] = profile.answer1.substring(6, 8);
    }
    _formData['answer_1'] = profile.answer1;
    
    // 성별 변환 (M -> 남성, F -> 여성)
    if (profile.answer2 == 'M') {
      _formData['answer_2'] = '남성';
    } else if (profile.answer2 == 'F') {
      _formData['answer_2'] = '여성';
    } else {
      _formData['answer_2'] = profile.answer2;
    }
    _formData['answer_3'] = profile.answer3;
    _formData['answer_4'] = profile.answer4;
    _formData['answer_5'] = profile.answer5;
    _formData['answer_6'] = profile.answer6;
    _formData['answer_7'] = profile.answer7;
    
    // 식사시간 파싱 (| 기준으로 분리)
    // 예: 122||222|555,666,777 -> 1식: 122, 2식: (없음), 3식: 222, 기타: 555,666,777
    if (profile.answer71.isNotEmpty) {
      final parts = profile.answer71.split('|');
      // 각 부분을 순서대로 할당 (빈 문자열도 유지)
      _formData['meal_1'] = parts.length > 0 ? parts[0] : '';
      _formData['meal_2'] = parts.length > 1 ? parts[1] : '';
      _formData['meal_3'] = parts.length > 2 ? parts[2] : '';
      _formData['meal_other'] = parts.length > 3 ? parts[3] : '';
    }
    _formData['answer_7_1'] = profile.answer71;
    
    // answer_8 (식습관) - 파이프(|)로 구분된 문자열을 List로 변환
    if (profile.answer8.isNotEmpty) {
      _formData['answer_8'] = profile.answer8.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } else {
      _formData['answer_8'] = [];
    }
    
    // answer_9 (자주 먹는 음식) - 파이프(|)로 구분된 문자열을 List로 변환
    if (profile.answer9.isNotEmpty) {
      _formData['answer_9'] = profile.answer9.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } else {
      _formData['answer_9'] = [];
    }
    
    _formData['answer_10'] = profile.answer10;
    
    // answer_11 (질병) - 파이프(|)로 구분된 문자열을 List로 변환
    if (profile.answer11.isNotEmpty) {
      _formData['answer_11'] = profile.answer11.split('|').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } else {
      _formData['answer_11'] = [];
    }
    
    // 복용중인 약 처리 (기타 항목 파싱) - 파이프(|)로 구분
    if (profile.answer12.isNotEmpty) {
      // answer_12가 문자열인 경우 List로 변환
      if (profile.answer12.contains('|')) {
        final parts = profile.answer12.split('|');
        final List<String> answer12List = [];
        String? otherValue;
        
        for (final part in parts) {
          final trimmed = part.trim();
          if (trimmed.startsWith('기타:')) {
            // "기타: 약물명" 형식 파싱
            otherValue = trimmed.substring(3).trim();
            answer12List.add('기타');
          } else {
            answer12List.add(trimmed);
          }
        }
        
        _formData['answer_12'] = answer12List;
        if (otherValue != null && otherValue.isNotEmpty) {
          _formData['answer_12_other'] = otherValue;
        }
      } else {
        // 단일 값인 경우
        if (profile.answer12 == '기타') {
          _formData['answer_12'] = ['기타'];
        } else {
          _formData['answer_12'] = [profile.answer12];
        }
      }
    } else {
      _formData['answer_12'] = [];
    }
    
    // 다이어트약 복용경험 변환 (1 = 없음, 2 = 있음)
    if (profile.answer13 == '1') {
      _formData['answer_13'] = '없음';
    } else if (profile.answer13 == '2') {
      _formData['answer_13'] = '있음';
    } else {
      _formData['answer_13'] = profile.answer13;
    }
    
    _formData['answer_13_medicine'] = profile.answer13Medicine;
    _formData['answer_13_period'] = profile.answer13Period;
    _formData['answer_13_dosage'] = profile.answer13Dosage;
    _formData['answer_13_sideeffect'] = profile.answer13Sideeffect;
    
    // 기존 데이터 백업 (있음 → 없음 → 있음 선택 시 복원용)
    _backupAnswer13Fields['answer_13_medicine'] = profile.answer13Medicine;
    _backupAnswer13Fields['answer_13_period'] = profile.answer13Period;
    _backupAnswer13Fields['answer_13_dosage'] = profile.answer13Dosage;
    _backupAnswer13Fields['answer_13_sideeffect'] = profile.answer13Sideeffect;
    
    print('=== 다이어트약 복용경험 로드 ===');
    print('answer_13 원본: ${profile.answer13}');
    print('answer_13 변환: ${_formData['answer_13']}');
    print('answer_13_medicine: ${profile.answer13Medicine}');
    print('answer_13_period: ${profile.answer13Period}');
    print('answer_13_dosage: ${profile.answer13Dosage}');
    print('answer_13_sideeffect: ${profile.answer13Sideeffect}');
    
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
                              color: Color(0xFFFF3787),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: (_currentPage + 1) / _sections.length,
                        backgroundColor: Colors.grey[300],
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF3787)),
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
                          backgroundColor: const Color(0xFFFF3787),
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

  Widget _buildSectionPage(HealthProfileSection section) {
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

  bool _shouldShowQuestion(HealthProfileQuestion question) {
    // 다이어트약 관련 필드들은 answer_13이 "있음" 또는 "2"일 때만 표시
    if (question.id.startsWith('answer_13') && question.id != 'answer_13') {
      final answer13 = _formData['answer_13'];
      return answer13 == '있음' || answer13 == '2';
    }
    // 복용중인 약 "기타" 입력 필드
    if (question.id == 'answer_12_other') {
      final answer12 = _formData['answer_12'];
      if (answer12 is List) {
        return answer12.contains('기타');
      }
      return answer12 == '기타';
    }
    return true;
  }

  Widget _buildQuestionWidget(HealthProfileQuestion question) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  question.question,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (question.allowMultiple == true)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '*중복 선택 가능',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[400],
                    ),
                  ),
                ),
            ],
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

  Widget _buildInputWidget(HealthProfileQuestion question) {
    switch (question.type) {
      case 'birthdate':
        return _buildBirthdateInput();
        
      case 'mealtime':
        return _buildMealtimeInput();
        
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
                  return null;
                }
              : null,
          onSaved: (value) {
            final savedValue = value ?? '';
            _formData[question.id] = savedValue;
            
            // 다이어트 경험 관련 필드 입력 시 백업 업데이트
            if (question.id.startsWith('answer_13') && question.id != 'answer_13') {
              _backupAnswer13Fields[question.id] = savedValue;
            }
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
            final savedValue = value ?? '';
            _formData[question.id] = savedValue;
            
            // 다이어트 경험 관련 필드 입력 시 백업 업데이트
            if (question.id.startsWith('answer_13') && question.id != 'answer_13') {
              _backupAnswer13Fields[question.id] = savedValue;
            }
          },
        );
        
        
      case 'radio':
        return Column(
          children: question.options!.map((option) {
            // 성별 변환 (M/F -> 남성/여성)
            // 다이어트약 복용경험 변환 (1 -> 없음, 2 -> 있음)
            String? groupValue = _formData[question.id];
            if (question.id == 'answer_2') {
              if (groupValue == 'M') groupValue = '남성';
              if (groupValue == 'F') groupValue = '여성';
            } else if (question.id == 'answer_13') {
              if (groupValue == '1') groupValue = '없음';
              if (groupValue == '2') groupValue = '있음';
            }
            
            return RadioListTile<String>(
              title: Text(option),
              value: option,
              groupValue: groupValue,
              onChanged: (value) {
                setState(() {
                  // 성별 저장 시 M/F로 변환
                  if (question.id == 'answer_2') {
                    _formData[question.id] = value == '남성' ? 'M' : (value == '여성' ? 'F' : value ?? '');
                  } else if (question.id == 'answer_13') {
                    // 다이어트약 복용경험 저장 시 1/2로 변환 (없음=1, 있음=2)
                    final newValue = value == '없음' ? '1' : (value == '있음' ? '2' : value ?? '');
                    final oldValue = _formData[question.id];
                    _formData[question.id] = newValue;
                    
                    if (value == '없음') {
                      // "없음" 선택 시 관련 필드 초기화
                      _formData['answer_13_medicine'] = '';
                      _formData['answer_13_period'] = '';
                      _formData['answer_13_dosage'] = '';
                      _formData['answer_13_sideeffect'] = '';
                    } else if (value == '있음') {
                      // "있음" 선택 시 기존 백업 데이터가 있으면 복원
                      if (oldValue == '1' || oldValue == '없음') {
                        // 없음에서 있음으로 변경한 경우, 백업 데이터 복원
                        if (_backupAnswer13Fields['answer_13_medicine'] != null) {
                          _formData['answer_13_medicine'] = _backupAnswer13Fields['answer_13_medicine'] ?? '';
                        }
                        if (_backupAnswer13Fields['answer_13_period'] != null) {
                          _formData['answer_13_period'] = _backupAnswer13Fields['answer_13_period'] ?? '';
                        }
                        if (_backupAnswer13Fields['answer_13_dosage'] != null) {
                          _formData['answer_13_dosage'] = _backupAnswer13Fields['answer_13_dosage'] ?? '';
                        }
                        if (_backupAnswer13Fields['answer_13_sideeffect'] != null) {
                          _formData['answer_13_sideeffect'] = _backupAnswer13Fields['answer_13_sideeffect'] ?? '';
                        }
                      }
                      // 이미 있음이었거나 데이터가 입력되어 있는 경우는 그대로 유지
                    }
                    
                    // UI 업데이트를 위해 강제 리빌드
                    Future.microtask(() {
                      if (mounted) {
                        setState(() {});
                      }
                    });
                  } else {
                    _formData[question.id] = value;
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

  Widget _buildGridWidget(HealthProfileQuestion question) {
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
                  // "기타" 선택 해제 시 입력 필드 초기화
                  if (question.id == 'answer_12' && option == '기타') {
                    _formData['answer_12_other'] = '';
                  }
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
              color: isSelected ? const Color(0xFFFFE5EE) : Colors.white,
              border: Border.all(
                color: isSelected ? const Color(0xFFFF3787) : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                option,
                style: TextStyle(
                  color: isSelected ? const Color(0xFFFF3787) : Colors.black87,
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
        await _saveHealthProfile();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_existingProfile != null 
                  ? '문진표가 수정되었습니다' 
                  : '문진표가 저장되었습니다'),
              backgroundColor: const Color(0xFFFF3787),
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
    print('========================================');
    print('📝 [문진표 ${_existingProfile != null ? '수정' : '생성'}] 전송할 데이터 확인');
    print('========================================');
    print('기본 정보:');
    print('  - 생년월일: ${_formData['birth_year']}-${_formData['birth_month']}-${_formData['birth_day']}');
    print('  - 성별: ${_formData['answer_2']}');
    print('  - 목표 체중: ${_formData['answer_3']}kg');
    print('  - 키: ${_formData['answer_4']}cm');
    print('  - 현재 체중: ${_formData['answer_5']}kg');
    print('  - 다이어트 기간: ${_formData['answer_6']}');
    print('');
    print('식습관:');
    print('  - 하루 식사 횟수: ${_formData['answer_7']}');
    print('  - 식사 시간: ${_formData['meal_1']}/${_formData['meal_2']}/${_formData['meal_3']}/${_formData['meal_other']}');
    print('  - 식습관: ${_formData['answer_8']}');
    print('  - 자주 먹는 음식: ${_formData['answer_9']}');
    print('');
    print('운동/건강:');
    print('  - 운동 빈도: ${_formData['answer_10']}');
    print('  - 질병: ${_formData['answer_11']}');
    print('  - 복용 중인 약: ${_formData['answer_12']}');
    print('  - 복용약(기타): ${_formData['answer_12_other']}');
    print('');
    print('다이어트 경험:');
    print('  - 다이어트약 복용 경험: ${_formData['answer_13']}');
    print('  - 약 이름: ${_formData['answer_13_medicine']}');
    print('  - 복용 기간: ${_formData['answer_13_period']}');
    print('  - 복용 횟수: ${_formData['answer_13_dosage']}');
    print('  - 부작용: ${_formData['answer_13_sideeffect']}');
    print('');
    if (_existingProfile != null) {
      print('수정 대상 문진표 번호: ${_existingProfile!.pfNo}');
    }
    print('========================================');
    
    // 생년월일 합치기 (YYYYMMDD 형식)
    final birthYear = _formData['birth_year'] ?? '';
    final birthMonth = _formData['birth_month'] ?? '';
    final birthDay = _formData['birth_day'] ?? '';
    final birthDate = birthYear.length == 4 && birthMonth.length == 2 && birthDay.length == 2
        ? '$birthYear$birthMonth$birthDay'
        : _formData['answer_1'] ?? '';
    
    // 식사시간 합치기 (| 기준으로 연결)
    final meal1 = _formData['meal_1'] ?? '';
    final meal2 = _formData['meal_2'] ?? '';
    final meal3 = _formData['meal_3'] ?? '';
    final mealOther = _formData['meal_other'] ?? '';
    final mealtime = '$meal1|$meal2|$meal3|$mealOther';
    
    final profile = HealthProfileModel(
      pfNo: _existingProfile?.pfNo, // 기존 프로필의 번호 포함
      mbId: _currentUser!.id,
      answer1: birthDate,
      answer2: _formData['answer_2'] ?? '',
      answer3: _formData['answer_3'] ?? '',
      answer4: _formData['answer_4'] ?? '',
      answer5: _formData['answer_5'] ?? '',
      answer6: _formData['answer_6'] ?? '',
      answer7: _formData['answer_7'] ?? '',
      answer8: _formatListToString(_formData['answer_8']),
      answer9: _formatListToString(_formData['answer_9']),
      answer10: _formData['answer_10'] ?? '',
      answer11: _formatListToString(_formData['answer_11']),
      answer12: _formatAnswer12(_formData['answer_12'], _formData['answer_12_other']),
      answer13: _formData['answer_13'] ?? '', // 1 또는 2로 저장됨
      answer13Period: _formData['answer_13_period'] ?? '',
      answer13Dosage: _formData['answer_13_dosage'] ?? '',
      answer13Medicine: _formData['answer_13_medicine'] ?? '',
      answer71: mealtime,
      answer13Sideeffect: _formData['answer_13_sideeffect'] ?? '',
      pfWdatetime: _existingProfile?.pfWdatetime ?? DateTime.now(),
      pfMdatetime: DateTime.now(),
      pfIp: '', // 서버에서 처리
      pfMemo: '',
    );
    
    if (_existingProfile != null && _existingProfile!.pfNo != null) {
      // 수정
      print('기존 문진표 수정: pfNo=${_existingProfile!.pfNo}');
      await HealthProfileService.updateHealthProfile(profile);
    } else {
      // 새로 생성
      print('새 문진표 생성');
      await HealthProfileService.saveHealthProfile(profile);
    }
  }

  /// 생년월일 입력 위젯 (년/월/일 3칸)
  Widget _buildBirthdateInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextFormField(
                initialValue: _formData['birth_year'] ?? '',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: InputDecoration(
                  labelText: '년',
                  hintText: '1990',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '년을 입력해주세요';
                  }
                  if (value.length != 4) {
                    return '4자리 숫자를 입력해주세요';
                  }
                  final year = int.tryParse(value);
                  if (year == null) {
                    return '올바른 숫자를 입력해주세요';
                  }
                  if (year < 1900 || year > DateTime.now().year) {
                    return '1900년부터 ${DateTime.now().year}년까지 입력 가능합니다';
                  }
                  return null;
                },
                onSaved: (value) {
                  _formData['birth_year'] = value ?? '';
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: _formData['birth_month'] ?? '',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                decoration: InputDecoration(
                  labelText: '월',
                  hintText: '01',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '월을 입력해주세요';
                  }
                  final month = int.tryParse(value);
                  if (month == null || month < 1 || month > 12) {
                    return '1월부터 12월까지 입력 가능합니다';
                  }
                  return null;
                },
                onSaved: (value) {
                  _formData['birth_month'] = (value ?? '').padLeft(2, '0');
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextFormField(
                initialValue: _formData['birth_day'] ?? '',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ],
                decoration: InputDecoration(
                  labelText: '일',
                  hintText: '01',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return '일을 입력해주세요';
                  }
                  final day = int.tryParse(value);
                  if (day == null || day < 1 || day > 31) {
                    return '1일부터 31일까지 입력 가능합니다';
                  }
                  // 년/월 정보로 실제 날짜 유효성 검증
                  final year = int.tryParse(_formData['birth_year'] ?? '');
                  final month = int.tryParse(_formData['birth_month'] ?? '');
                  if (year != null && month != null) {
                    try {
                      final date = DateTime(year, month, day);
                      if (date.year != year || date.month != month || date.day != day) {
                        return '올바른 날짜를 입력해주세요';
                      }
                      if (date.isAfter(DateTime.now())) {
                        return '미래 날짜는 입력할 수 없습니다';
                      }
                    } catch (e) {
                      return '올바른 날짜를 입력해주세요';
                    }
                  }
                  return null;
                },
                onSaved: (value) {
                  _formData['birth_day'] = (value ?? '').padLeft(2, '0');
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 식사시간 입력 위젯 (1식, 2식, 3식, 기타 4칸 한 줄)
  Widget _buildMealtimeInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '1식',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    initialValue: _formData['meal_1'] ?? '',
                    decoration: InputDecoration(
                      hintText: '예: 08:00',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSaved: (value) {
                      _formData['meal_1'] = value ?? '';
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '2식',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    initialValue: _formData['meal_2'] ?? '',
                    decoration: InputDecoration(
                      hintText: '예: 12:00',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSaved: (value) {
                      _formData['meal_2'] = value ?? '';
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '3식',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    initialValue: _formData['meal_3'] ?? '',
                    decoration: InputDecoration(
                      hintText: '예: 19:00',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSaved: (value) {
                      _formData['meal_3'] = value ?? '';
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '기타',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    initialValue: _formData['meal_other'] ?? '',
                    decoration: InputDecoration(
                      hintText: '예: 간식',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onSaved: (value) {
                      _formData['meal_other'] = value ?? '';
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '*해당되는 입력란에만 입력하세요.',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  /// List를 문자열로 변환 (allowMultiple 필드용) - 파이프(|)로 구분
  String _formatListToString(dynamic value) {
    if (value == null) return '';
    if (value is List) {
      return value.join('|');
    }
    return value.toString();
  }

  /// 복용중인 약(answer_12) 포맷팅 - 파이프(|)로 구분
  String _formatAnswer12(dynamic answer12, String? otherValue) {
    if (answer12 == null) return '';
    
    if (answer12 is List) {
      final List<String> result = [];
      for (final item in answer12) {
        if (item == '기타' && otherValue != null && otherValue.isNotEmpty) {
          result.add('기타: $otherValue');
        } else {
          result.add(item.toString());
        }
      }
      return result.join('|');
    }
    
    // List가 아닌 경우
    final answer12Str = answer12.toString();
    if (answer12Str == '기타' && otherValue != null && otherValue.isNotEmpty) {
      return '기타: $otherValue';
    }
    return answer12Str;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}

