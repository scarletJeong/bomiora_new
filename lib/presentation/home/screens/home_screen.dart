import 'package:flutter/material.dart';
import '../widgets/main_banner_slider.dart';
import '../widgets/stats_section.dart';
import '../widgets/popular_products.dart';
import '../widgets/review_section.dart';
import '../widgets/tester_section.dart';
import '../widgets/bottom_banner.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/models/user/user_model.dart';
import '../../shopping/screens/cart_screen.dart';
import '../../shopping/screens/product_list_screen.dart';
import '../../shopping/screens/category_screen.dart';
import '../../health/dashboard/screens/health_dashboard_screen.dart';
import '../../health/telemedicine/screens/telemedicine_webview_screen.dart';
import '../../user/healthprofile/screens/health_profile_list_screen.dart';
import '../../user/coupon/screens/coupon_screen.dart';
import '../../user/mileage/screens/mileage_screen.dart';
import '../../customer_service/screens/customer_service_screen.dart';
import '../../shopping/wish/screens/wish_list_screen.dart';
import '../../user/myPage/screens/my_page_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isLoading = true;
  UserModel? _currentUser;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
      final user = await AuthService.getUser();
    setState(() {
      _currentUser = user;
    });
  }


  Future<void> _handleLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃'),
        content: const Text('정말 로그아웃하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await AuthService.logout();
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Future<void> _loadData() async {
    try {
      // 임시로 더미 데이터 사용 (API 연동 전)
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      print('데이터 로드 실패: $e');
    }
  }
  
  // 3 메뉴판
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.black),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
        title: Image.asset(
          'assets/images/bomiora-logo.png',
          height: 40,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart, color: Colors.black),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const CartScreen(),
                ),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Color(0xFFFFDBEA),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Image.asset(
                    'assets/images/bomiora-logo.png',
                    height: 40,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '보미오라 다이어트 쇼핑몰',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            // 메뉴 그리드
            Container(
              padding: const EdgeInsets.all(16),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 16,
                childAspectRatio: 0.8,
                children: [
                  _buildMenuGridItem(
                    icon: Icons.home,
                    label: '홈',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _currentIndex = 0;
                      });
                    },
                  ),
                  _buildMenuGridItem(
                    icon: Icons.assignment,
                    label: '문진표',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HealthProfileListScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuGridItem(
                    icon: Icons.local_shipping,
                    label: '주문배송',
                    onTap: () {
                      Navigator.pop(context);
                      // 주문배송 페이지로 이동
                    },
                  ),
                  _buildMenuGridItem(
                    icon: Icons.shopping_cart,
                    label: '장바구니',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CartScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuGridItem(
                    icon: Icons.card_giftcard,
                    label: '쿠폰',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CouponScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuGridItem(
                    icon: Icons.stars,
                    label: '포인트',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MileageScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuGridItem(
                    icon: Icons.person,
                    label: 'Mypage',
                    onTap: () {
                      Navigator.pop(context);
                      setState(() {
                        _currentIndex = 3;
                      });
                    },
                  ),
                  _buildMenuGridItem(
                    icon: Icons.headset_mic,
                    label: '고객센터',
                    onTap: () {
                      Navigator.pop(context);
                      // 고객센터 페이지로 이동 - FAQ 탭 먼저 표시
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CustomerServiceScreen(initialTabIndex: 0),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('건강대시보드'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HealthDashboardScreen(),
                  ),
                );
              },
            ),
            ExpansionTile(
              //leading: const Icon(Icons.local_hospital),
              title: const Text('비대면 진료'),
              children: [
                ListTile(
                  leading: const Icon(Icons.fitness_center, size: 20),
                  title: const Text('다이어트'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      '/product-list',
                      arguments: {
                        'categoryId': '10',
                        'categoryName': '다이어트',
                        'productKind': 'prescription',
                      },
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cleaning_services, size: 20),
                  title: const Text('디톡스'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      '/product-list',
                      arguments: {
                        'categoryId': '20',
                        'categoryName': '디톡스',
                        'productKind': 'prescription',
                      },
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.health_and_safety, size: 20),
                  title: const Text('심신안정'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      '/product-list',
                      arguments: {
                        'categoryId': '80',
                        'categoryName': '심신안정',
                        'productKind': 'prescription',
                      },
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.psychology, size: 20),
                  title: const Text('건강/면역'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      '/product-list',
                      arguments: {
                        'categoryId': '50',
                        'categoryName': '건강/면역',
                        'productKind': 'prescription',
                      },
                    );
                  },
                ),
              ],
            ),
            ListTile(
              leading: const Icon(Icons.card_giftcard),
              title: const Text('체험단'),
              onTap: () {
                Navigator.pop(context);
                // 체험단 페이지로 이동
              },
            ),
            ListTile(
              leading: const Icon(Icons.star),
              title: const Text('리뷰'),
              onTap: () {
                Navigator.pop(context);
                // 리뷰 페이지로 이동
              },
            ),
            ListTile(
              leading: const Icon(Icons.help),
              title: const Text('온라인 문의'),
              onTap: () {
                Navigator.pop(context);
                // 온라인 문의 페이지로 이동 - 내 문의내역 탭 먼저 표시
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CustomerServiceScreen(initialTabIndex: 1),
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('설정'),
              onTap: () {
                Navigator.pop(context);
                // 설정 페이지로 이동
              },
            ),
          ],
        ),
      ),
      body: _getCurrentPage(),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFFFF3787),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag),
            label: '카테고리',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite),
            label: '찜',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: '마이페이지',
          ),
        ],
      ),
    );
  }

  Widget _getCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return _buildHomePage();
      case 1:
        return _buildCategoryPage();
      case 2:
        return _buildWishlistPage();
      case 3:
        return _buildMyPage();
      default:
        return _buildHomePage();
    }
  }

  Widget _buildHomePage() {
    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Column(
              children: [
                // 메인 배너 슬라이더
                const MainBannerSlider(),
                
                // 통계 섹션
                const StatsSection(),
                
                
                // 인기상품 섹션
                const PopularProducts(),
                
                // 리뷰 섹션
                const ReviewSection(),
                
                // 체험단 섹션
                const TesterSection(),
                
                // 하단 배너
                const BottomBanner(),
              ],
            ),
          );
  }

  Widget _buildCategoryPage() {
    return const CategoryScreen();
  }

  Widget _buildWishlistPage() {
    return const WishListScreen();
  }

  Widget _buildMyPage() {
    return const MyPageScreen();
  }

  Widget _buildMenuGridItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 32,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

