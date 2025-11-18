import 'package:flutter/material.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/health_profile_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../models/health_profile_model.dart';
import 'health_profile_form_screen.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/app_footer.dart';

class HealthProfileListScreen extends StatefulWidget {
  const HealthProfileListScreen({super.key});

  @override
  State<HealthProfileListScreen> createState() => _HealthProfileListScreenState();
}

class _HealthProfileListScreenState extends State<HealthProfileListScreen> {
  UserModel? _currentUser;
  HealthProfileModel? _healthProfile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await AuthService.getUser();
      if (user != null) {
        setState(() {
          _currentUser = user;
        });
        
        await _loadHealthProfile();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('데이터 로드 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            width: 568, // 600px - 32px (양쪽 16px 여백)
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadHealthProfile() async {
    try {
      _healthProfile = await HealthProfileService.getHealthProfile(_currentUser!.id);
    } catch (e) {
      // 건강프로필가 없거나 오류가 발생한 경우
      _healthProfile = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        title: const Text('건강프로필'),
        elevation: 0,
        scrolledUnderElevation: 0, // 스크롤 시 AppBar 색상 변경 방지
        surfaceTintColor: Colors.transparent, // Material 3의 tint 효과 제거
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null
              ? _buildLoginRequired()
              : _buildContent(),
    );
  }

  Widget _buildLoginRequired() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.login,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '로그인이 필요합니다',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '건강프로필를 작성하려면 로그인해주세요',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 32,
                vertical: 12,
              ),
            ),
            child: const Text('로그인'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_healthProfile == null) {
      return _buildEmptyState();
    }

    return _buildProfileCard();
  }

  Widget _buildEmptyState() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 100),
          Icon(
            Icons.assignment_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 24),
          Text(
            '건강프로필가 없습니다',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '다이어트 상담을 위해\n건강프로필를 작성해주세요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: _navigateToForm,
            icon: const Icon(Icons.add),
            label: const Text('건강프로필 작성하기'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 300),
          const AppFooter(),
        ],
      ),
    );
  }

  Widget _buildProfileCard() {
    final profile = _healthProfile!;
    
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 컨텐츠에 padding 적용
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          // 기본 정보 카드
          _buildInfoCard(
            title: '기본 정보',
            icon: Icons.person,
            sectionIndex: 0,
            children: [
              _buildInfoRow('생년월일', _formatBirthDate(profile.answer1)),
              _buildInfoRow('성별', _formatGender(profile.answer2)),
              _buildInfoRow('키', '${profile.answer4}cm'),
              _buildInfoRow('현재 몸무게', '${profile.answer5}kg'),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 다이어트 목표 카드
          _buildInfoCard(
            title: '다이어트 목표',
            icon: Icons.flag,
            sectionIndex: 1,
            children: [
              _buildInfoRow('목표 감량 체중', '${profile.answer3}kg'),
              _buildInfoRow('예상 기간', profile.answer6),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 식습관 카드
          _buildInfoCard(
            title: '식습관',
            icon: Icons.restaurant,
            sectionIndex: 2,
            children: [
              _buildInfoRow('하루 끼니', profile.answer7),
              _buildInfoRow('식사 시간', _formatMealTime(profile.answer71)),
              _buildInfoRow('식습관', profile.answer8),
              _buildInfoRow('자주 먹는 음식', profile.answer9),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 운동 및 건강 카드
          _buildInfoCard(
            title: '운동 및 건강',
            icon: Icons.fitness_center,
            sectionIndex: 3,
            children: [
              _buildInfoRow('운동 습관', profile.answer10),
              _buildInfoRow('질병', profile.answer11.isEmpty ? '없음' : profile.answer11),
              _buildInfoRow('복용 중인 약', profile.answer12.isEmpty ? '없음' : profile.answer12),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 다이어트 경험 카드
          if (profile.answer13.isNotEmpty) ...[
            _buildInfoCard(
              title: '다이어트 경험',
              icon: Icons.history,
              sectionIndex: 4,
              children: [
                _buildInfoRow('기존 다이어트약 복용', _formatDietExperience(profile.answer13)),
                if (profile.answer13Medicine.isNotEmpty)
                  _buildInfoRow('복용한 다이어트약명', profile.answer13Medicine),
                if (profile.answer13Period.isNotEmpty)
                  _buildInfoRow('복용 기간', profile.answer13Period),
                if (profile.answer13Dosage.isNotEmpty)
                  _buildInfoRow('복용 횟수', profile.answer13Dosage),
                if (profile.answer13Sideeffect.isNotEmpty)
                  _buildInfoRow('부작용', profile.answer13Sideeffect),
              ],
            ),
            const SizedBox(height: 16),
          ],
          
          // 작성/수정 정보
          _buildInfoCard(
            title: '건강프로필 정보',
            icon: Icons.info,
            children: [
              _buildInfoRow('작성일', _formatDate(profile.pfWdatetime)),
              _buildInfoRow('수정일', _formatDate(profile.pfMdatetime)),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // 수정 버튼
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _navigateToEditForm,
              icon: const Icon(Icons.edit),
              label: const Text('건강프로필 수정하기'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF3787),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
              ],
            ),
          ),
          
          const SizedBox(height: 100),
          
          // Footer  
          const AppFooter(),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    int? sectionIndex, // 섹션 인덱스 (null이면 수정 불가능한 카드)
  }) {
    return Card(
      color: const Color(0xFFFFF5F5), // 연한 핑크색 배경 건강프로필 카드 색상
      elevation: 2,
      surfaceTintColor: Colors.transparent, // Material 3의 tint 효과 제거
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: sectionIndex != null 
            ? () => _navigateToEditSection(sectionIndex)
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: Colors.blue,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (sectionIndex != null) ...[
                    const Icon(
                      Icons.edit,
                      size: 20,
                      color: Color(0xFFFF3787),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '수정',
                      style: TextStyle(
                        fontSize: 13,
                        color: const Color(0xFFFF3787),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// 생년월일 포맷팅 (YYYYMMDD -> YYYY-MM-DD)
  String _formatBirthDate(String birthDate) {
    if (birthDate.isEmpty) return '-';
    if (birthDate.length == 8) {
      // YYYYMMDD 형식
      return '${birthDate.substring(0, 4)}-${birthDate.substring(4, 6)}-${birthDate.substring(6, 8)}';
    }
    return birthDate;
  }

  /// 성별 포맷팅 (M -> 남성, F -> 여성)
  String _formatGender(String gender) {
    if (gender.isEmpty) return '-';
    if (gender == 'M') return '남성';
    if (gender == 'F') return '여성';
    return gender;
  }

  /// 식사시간 포맷팅 (| 기준으로 파싱하여 표시)
  String _formatMealTime(String mealTime) {
    if (mealTime.isEmpty) return '-';
    
    final parts = mealTime.split('|');
    final meal1 = parts.length > 0 && parts[0].isNotEmpty ? parts[0] : null;
    final meal2 = parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
    final meal3 = parts.length > 2 && parts[2].isNotEmpty ? parts[2] : null;
    final mealOther = parts.length > 3 && parts[3].isNotEmpty ? parts[3] : null;
    
    final List<String> displayParts = [];
    if (meal1 != null) displayParts.add('1식: $meal1');
    if (meal2 != null) displayParts.add('2식: $meal2');
    if (meal3 != null) displayParts.add('3식: $meal3');
    if (mealOther != null) displayParts.add('기타: $mealOther');
    
    if (displayParts.isEmpty) return '-';
    return displayParts.join(', ');
  }

  /// 다이어트 경험 포맷팅 (1 -> 없음, 2 -> 있음)
  String _formatDietExperience(String experience) {
    if (experience.isEmpty) return '-';
    if (experience == '1') return '없음';
    if (experience == '2') return '있음';
    return experience;
  }

  void _navigateToForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HealthProfileFormScreen(),
      ),
    );
    
    if (result == true) {
      _loadData();
    }
  }

  void _navigateToEditForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HealthProfileFormScreen(
          existingProfile: _healthProfile,
        ),
      ),
    );
    
    if (result == true) {
      _loadData();
    }
  }

  void _navigateToEditSection(int sectionIndex) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HealthProfileFormScreen(
          existingProfile: _healthProfile,
          initialSectionIndex: sectionIndex,
        ),
      ),
    );
    
    if (result == true) {
      _loadData();
    }
  }
}

