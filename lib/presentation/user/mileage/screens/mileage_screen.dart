import 'package:flutter/material.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/point_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/models/point/point_history_model.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/app_footer.dart';

class MileageScreen extends StatefulWidget {
  const MileageScreen({super.key});

  @override
  State<MileageScreen> createState() => _MileageScreenState();
}

class _MileageScreenState extends State<MileageScreen> {
  UserModel? _currentUser;
  int? _currentPoint;
  List<PointHistory> _pointHistory = [];
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

        // 포인트 및 내역 병렬 조회
        await Future.wait([
          _loadCurrentPoint(),
          _loadPointHistory(),
        ]);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('데이터 로드 중 오류가 발생했습니다: $e'),
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

  Future<void> _loadCurrentPoint() async {
    if (_currentUser == null) return;
    
    try {
      final point = await PointService.getUserPoint(_currentUser!.id);
      setState(() {
        _currentPoint = point;
      });
    } catch (e) {
      print('포인트 조회 오류: $e');
    }
  }

  Future<void> _loadPointHistory() async {
    if (_currentUser == null) return;
    
    try {
      final history = await PointService.getPointHistory(_currentUser!.id);
      setState(() {
        _pointHistory = history;
      });
    } catch (e) {
      print('포인트 내역 조회 오류: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        title: const Text('포인트'),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.white,
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
          Icon(Icons.lock, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '로그인이 필요합니다',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 현재 포인트 섹션
          _buildCurrentPointSection(),
          
          // 포인트 규칙 안내
          _buildRulesSection(),
          
          // 포인트 내역
          _buildHistorySection(),
          
          const SizedBox(height: 300),
          
          // Footer
          const AppFooter(),
        ],
      ),
    );
  }

  Widget _buildCurrentPointSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 지갑 아이콘 (3D 스타일)
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFF4081), // 핑크
                  Color(0xFFFF6BA3),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.pink.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Stack(
              children: [
                // 지갑 본체
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4081),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                // 노란색 끈
                Positioned(
                  top: 8,
                  left: 20,
                  right: 20,
                  child: Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.yellow[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // 파란색 카드 (일부 보임)
                Positioned(
                  bottom: 12,
                  left: 12,
                  right: 12,
                  child: Container(
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.blue[400],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 포인트 텍스트
          Text(
            '포인트 ${PointService.formatPoint(_currentPoint ?? 0)}',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF4081),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRulesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '포인트 안내',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildRuleItem('100P = 100원 입니다. (1P = 1원)'),
          const SizedBox(height: 8),
          _buildRuleItem('2025년 8월 8일 이후 지급된 포인트는 지급일자 기준으로 1년 후 자동소멸됩니다.'),
          const SizedBox(height: 8),
          _buildRuleItem('할인 적용 및 프로모션 페이지를 통한 결제 시 포인트 사용이 불가합니다.(중복 할인 방지)'),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6, right: 8),
          width: 4,
          height: 4,
          decoration: const BoxDecoration(
            color: Colors.grey,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    if (_pointHistory.isEmpty) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Center(
          child: Text(
            '포인트 내역이 없습니다.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  '포인트 내역',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ..._pointHistory.map((history) => _buildHistoryItem(history)),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(PointHistory history) {
    final isEarned = history.isEarned;
    final changeAmount = history.changeAmount;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey[100]!),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 날짜 및 만료일
                Text(
                  '${history.formattedDate} 만료: ${history.formattedExpireDate}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 4),
                // 내용
                Text(
                  history.content.isNotEmpty ? history.content : '포인트 변동',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // 포인트 변동량
          Text(
            '${changeAmount >= 0 ? '+' : ''}${PointService.formatPoint(changeAmount.abs())}p',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isEarned ? const Color(0xFFFF4081) : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

