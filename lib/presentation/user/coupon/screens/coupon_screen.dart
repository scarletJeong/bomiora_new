import 'package:flutter/material.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/coupon_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/models/coupon/coupon_model.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/app_footer.dart';

class CouponScreen extends StatefulWidget {
  const CouponScreen({super.key});

  @override
  State<CouponScreen> createState() => _CouponScreenState();
}

class _CouponScreenState extends State<CouponScreen> with SingleTickerProviderStateMixin {
  UserModel? _currentUser;
  List<Coupon> _allCoupons = [];
  List<Coupon> _availableCoupons = [];
  List<Coupon> _usedCoupons = [];
  List<Coupon> _expiredCoupons = [];
  bool _isLoading = true;
  late TabController _tabController;
  final TextEditingController _couponCodeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _couponCodeController.dispose();
    super.dispose();
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

        await _loadCoupons();
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

  Future<void> _loadCoupons() async {
    if (_currentUser == null) return;

    try {
      // 백엔드에서 분리된 API로 각각 조회
      final results = await Future.wait([
        CouponService.getAvailableCoupons(_currentUser!.id),
        CouponService.getUsedCoupons(_currentUser!.id),
        CouponService.getExpiredCoupons(_currentUser!.id),
      ]);
      
      setState(() {
        _availableCoupons = results[0];
        _usedCoupons = results[1];
        _expiredCoupons = results[2];
        _allCoupons = [
          ..._availableCoupons,
          ..._usedCoupons,
          ..._expiredCoupons,
        ];
      });
    } catch (e) {
      print('쿠폰 조회 오류: $e');
    }
  }

  Future<void> _registerCoupon() async {
    if (_couponCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('쿠폰 코드를 입력해주세요.')),
      );
      return;
    }

    if (_currentUser == null) return;

    try {
      final result = await CouponService.registerCoupon(
        _currentUser!.id,
        _couponCodeController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? ''),
            backgroundColor: result['success'] == true ? Colors.green : Colors.red,
          ),
        );

        if (result['success'] == true) {
          _couponCodeController.clear();
          await _loadCoupons();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('쿠폰 등록 중 오류가 발생했습니다: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        title: const Text('쿠폰'),
        backgroundColor: Colors.white,
        elevation: 0,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 내 쿠폰 개수 섹션
        _buildCouponSummary(),
        
        // 탭
        TabBar(
          controller: _tabController,
          labelColor: Colors.black,
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFFF4081),
          tabs: const [
            Tab(text: '사용가능한 쿠폰'),
            Tab(text: '사용한 쿠폰'),
            Tab(text: '지난 쿠폰'),
          ],
        ),
        
        // 쿠폰 등록 섹션
        _buildCouponRegistration(),
        
        // 쿠폰 리스트
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildCouponList(_availableCoupons, '사용할 수 있는 쿠폰이 없습니다.'),
              _buildCouponList(_usedCoupons, '사용한 쿠폰이 없습니다.'),
              _buildCouponList(_expiredCoupons, '만료된 쿠폰이 없습니다.'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCouponSummary() {
    final totalCoupons = _availableCoupons.length; // 사용 가능한 쿠폰만 카운트
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // 쿠폰 아이콘 (단일 태그 형태)
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFF4081),
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
                // 노란색 끈 (상단)
                Positioned(
                  top: 4,
                  left: 15,
                  right: 15,
                  child: Container(
                    height: 3,
                    decoration: BoxDecoration(
                      color: Colors.yellow[600],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // 3줄 바코드 스타일 (중앙)
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Colors.white),
                        ),
                      ),
                      SizedBox(height: 2),
                      SizedBox(
                        width: 20,
                        height: 3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Colors.white),
                        ),
                      ),
                      SizedBox(height: 2),
                      SizedBox(
                        width: 20,
                        height: 3,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 내 쿠폰 텍스트
          Text(
            '내 쿠폰 $totalCoupons개',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCouponRegistration() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '쿠폰 등록하기',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _couponCodeController,
                  decoration: InputDecoration(
                    hintText: '쿠폰 코드를 입력해주세요',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: _registerCoupon,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal[300],
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('쿠폰 등록하기'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCouponList(List<Coupon> coupons, String emptyMessage) {
    if (coupons.isEmpty) {
      return SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 빈 상태 메시지 (padding 적용)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Center(
                  child: Text(
                    emptyMessage,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 300),
            
            // Footer  
            const AppFooter(),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // 쿠폰 리스트 (padding 적용)
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return _buildCouponCard(coupons[index]);
              },
              childCount: coupons.length,
            ),
          ),
        ),
        
        // Footer  
        const SliverToBoxAdapter(
          child: Column(
            children: [
              SizedBox(height: 300),
              AppFooter(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCouponCard(Coupon coupon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 날짜 범위
          Text(
            coupon.formattedDateRange,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          // 쿠폰 정보
          Text(
            coupon.subject,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (coupon.target.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              coupon.target,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ],
          const SizedBox(height: 8),
          // 할인 금액
          Text(
            coupon.discountText,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFFFF4081),
            ),
          ),
        ],
      ),
    );
  }
}

