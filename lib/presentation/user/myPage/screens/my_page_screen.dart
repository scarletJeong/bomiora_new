import 'package:flutter/material.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/services/coupon_service.dart';
import '../../../../data/services/point_service.dart';
import '../../../../data/services/review_service.dart';
import '../../../../data/services/contact_service.dart';
import '../../../../data/services/order_service.dart';
import '../../healthprofile/screens/health_profile_list_screen.dart';
import '../../../settings/settings_screen.dart';
import 'profile_settings_screen.dart';
import '../../../customer_service/screens/customer_service_screen.dart';
import '../../review/my_reviews_screen.dart';
import '../../coupon/screens/coupon_screen.dart';
import '../../mileage/screens/mileage_screen.dart';
import '../../delivery/delivery_list_screen.dart';

class MyPageScreen extends StatefulWidget {
  const MyPageScreen({super.key});

  @override
  State<MyPageScreen> createState() => _MyPageScreenState();
}

class _MyPageScreenState extends State<MyPageScreen> {
  UserModel? _currentUser;
  
  // 마이페이지 통계 데이터
  int _orderCount = 0;
  int _reviewCount = 0;
  int _contactCount = 0;
  int _couponCount = 0;
  int? _userPoint;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.getUser();
    if (!mounted) return;
    
    setState(() {
      _currentUser = user;
    });
    
    // 사용자 정보 로드 후 통계 데이터 로드
    if (user != null) {
      _loadMyPageStats(user.id);
    }
  }
  
  Future<void> _loadMyPageStats(String userId) async {
    // 쿠폰 개수 (사용가능한 쿠폰만)
    try {
      final coupons = await CouponService.getAvailableCoupons(userId);
      if (!mounted) return;
      
      setState(() {
        _couponCount = coupons.length;
      });
    } catch (e) {
      print('쿠폰 개수 조회 오류: $e');
    }
    
    // 포인트
    try {
      final point = await PointService.getUserPoint(userId);
      if (!mounted) return;
      
      setState(() {
        _userPoint = point;
      });
    } catch (e) {
      print('포인트 조회 오류: $e');
    }
    
    // 리뷰 개수
    try {
      final result = await ReviewService.getMemberReviews(
        mbId: userId,
        page: 0,
        size: 1,
      );
      if (!mounted) return;
      
      if (result['success'] == true) {
        setState(() {
          _reviewCount = result['totalElements'] ?? 0;
        });
      }
    } catch (e) {
      print('리뷰 개수 조회 오류: $e');
    }
    
    // 문의 개수
    try {
      final contacts = await ContactService.getMyContacts();
      if (!mounted) return;
      
      setState(() {
        _contactCount = contacts.length;
      });
    } catch (e) {
      print('문의 개수 조회 오류: $e');
    }
    
    // 주문·배송 개수 (결제완료~배송중 상태만 카운트)
    try {
      int totalOrderCount = 0;
      
      // 결제완료 상태 조회
      final paymentResult = await OrderService.getOrderList(
        mbId: userId,
        status: 'payment',
        page: 0,
        size: 1,
      );
      if (paymentResult['success'] == true) {
        totalOrderCount += (paymentResult['totalElements'] ?? 0) as int;
      }
      
      // 배송준비중 상태 조회
      final preparingResult = await OrderService.getOrderList(
        mbId: userId,
        status: 'preparing',
        page: 0,
        size: 1,
      );
      if (preparingResult['success'] == true) {
        totalOrderCount += (preparingResult['totalElements'] ?? 0) as int;
      }
      
      // 배송중 상태 조회
      final deliveringResult = await OrderService.getOrderList(
        mbId: userId,
        status: 'delivering',
        page: 0,
        size: 1,
      );
      if (deliveringResult['success'] == true) {
        totalOrderCount += (deliveringResult['totalElements'] ?? 0) as int;
      }
      
      if (!mounted) return;
      
      setState(() {
        _orderCount = totalOrderCount;
      });
    } catch (e) {
      print('주문 개수 조회 오류: $e');
    }
  }
  
  String _formatPoint(int point) {
    return point.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
        title: const Text(
          '마이페이지',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 회원 정보 섹션 (클릭 가능)
            GestureDetector(
              onTap: () {
                if (_currentUser != null) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProfileSettingsScreen(),
                    ),
                  ).then((value) {
                    // 설정 화면에서 돌아왔을 때 사용자 정보 새로고침
                    _loadCurrentUser();
                  });
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: const Color(0xFFFF3787).withOpacity(0.1),
                          child: const Icon(
                            Icons.person,
                            size: 40,
                            color: Color(0xFFFF3787),
                          ),
                        ),
                        if (_currentUser != null)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF3787),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(
                                Icons.edit,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _currentUser?.name ?? '로그인이 필요합니다',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_currentUser != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _currentUser!.email,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (_currentUser!.phone != null && _currentUser!.phone!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          _currentUser!.phone!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // 통계 카드 (주문·예약, 리뷰, 문의, 쿠폰, 포인트)
            if (_currentUser != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 1,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatCard(
                      icon: Icons.receipt_long,
                      iconColor: Colors.blue,
                      label: '주문·배송',
                      value: '$_orderCount',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DeliveryListScreen(),
                          ),
                        ).then((value) {
                          // 주문 화면에서 돌아왔을 때 통계 새로고침
                          if (_currentUser != null) {
                            _loadMyPageStats(_currentUser!.id);
                          }
                        });
                      },
                    ),
                    _buildStatCard(
                      icon: Icons.rate_review,
                      iconColor: const Color(0xFFFF4081),
                      label: '리뷰',
                      value: '$_reviewCount',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MyReviewsScreen(),
                          ),
                        ).then((value) {
                          // 리뷰 화면에서 돌아왔을 때 통계 새로고침
                          if (_currentUser != null) {
                            _loadMyPageStats(_currentUser!.id);
                          }
                        });
                      },
                    ),
                    _buildStatCard(
                      icon: Icons.help_outline,
                      iconColor: Colors.purple,
                      label: '문의',
                      value: '$_contactCount',
                      onTap: () {
                        // 마이페이지에서 문의 아이콘 클릭 시 내 문의내역 탭으로 이동
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CustomerServiceScreen(initialTabIndex: 1),
                          ),
                        );
                      },
                    ),
                    _buildStatCard(
                      icon: Icons.local_offer,
                      iconColor: Colors.red,
                      label: '쿠폰',
                      value: '$_couponCount장',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CouponScreen(),
                          ),
                        ).then((value) {
                          // 쿠폰 화면에서 돌아왔을 때 통계 새로고침
                          if (_currentUser != null) {
                            _loadMyPageStats(_currentUser!.id);
                          }
                        });
                      },
                    ),
                    _buildStatCard(
                      icon: Icons.stars,
                      iconColor: Colors.orange,
                      label: '포인트',
                      value: _userPoint != null ? '${_formatPoint(_userPoint!)}원' : '0원',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MileageScreen(),
                          ),
                        ).then((value) {
                          // 포인트 화면에서 돌아왔을 때 통계 새로고침
                          if (_currentUser != null) {
                            _loadMyPageStats(_currentUser!.id);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // 메뉴 리스트
              _buildMenuItem(
                icon: Icons.assignment,
                title: '건강프로필',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HealthProfileListScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              _buildMenuItem(
                icon: Icons.dashboard_outlined,
                title: '건강대시보드',
                onTap: () {
                  // TODO: 건강대시보드 페이지로 이동
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('건강대시보드는 추후 구현 예정입니다.')),
                  );
                },
              ),
              const SizedBox(height: 8),
              _buildMenuItem(
                icon: Icons.settings,
                title: '설정',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                },
              ),
            ] else ...[
              // 로그인 안 된 경우
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/login');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF3787),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    '로그인',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatCard({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFFFF3787),
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }
}

