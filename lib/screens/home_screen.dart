import 'package:flutter/material.dart';
import '../widgets/main_banner_slider.dart';
import '../widgets/stats_section.dart';
import '../widgets/popular_products.dart';
import '../widgets/review_section.dart';
import '../widgets/tester_section.dart';
import '../widgets/bottom_banner.dart';
import '../services/auth/auth_manager.dart';
import '../models/user_model.dart';
import 'hybrid_shopping_screen.dart';
import 'webview_screen.dart';

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
    final user = await AuthManager.getCurrentUser();
    setState(() {
      _currentUser = user;
    });
  }

  void _showUserMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_currentUser != null) ...[
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.blue,
                child: Text(
                  _currentUser!.name.isNotEmpty 
                      ? _currentUser!.name[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _currentUser!.name,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _currentUser!.email,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
            ],
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('마이페이지'),
              onTap: () {
                Navigator.pop(context);
                // 마이페이지로 이동
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('설정'),
              onTap: () {
                Navigator.pop(context);
                // 설정 페이지로 이동
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('로그아웃', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _handleLogout();
              },
            ),
          ],
        ),
      ),
    );
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
      await AuthManager.logout();
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
                  builder: (context) => const HybridShoppingScreen(),
                ),
              );
            },
          ),
              IconButton(
                icon: const Icon(Icons.person, color: Colors.black),
                onPressed: () {
                  _showUserMenu(context);
                },
              ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.blue,
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
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('홈'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _currentIndex = 0;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.shopping_cart),
              title: const Text('장바구니'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _currentIndex = 2;
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('마이페이지'),
              onTap: () {
                Navigator.pop(context);
                setState(() {
                  _currentIndex = 3;
                });
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('건강대시보드'),
              onTap: () {
                Navigator.pop(context);
                // 보미오라 소개 페이지로 이동
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const WebViewScreen(
                          url: 'https://bomiora0.mycafe24.com/shop/list.php?ca_id=10&it_kind=prescription&mobile_app=1&hide_header=1&hide_footer=1',
                          title: '다이어트',
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cleaning_services, size: 20),
                  title: const Text('디톡스'),
                  onTap: () {
                    Navigator.pop(context);
                    // 디톡스 페이지로 이동
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.health_and_safety, size: 20),
                  title: const Text('건강/면역'),
                  onTap: () {
                    Navigator.pop(context);
                    // 건강/면역 페이지로 이동
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.psychology, size: 20),
                  title: const Text('심신안정'),
                  onTap: () {
                    Navigator.pop(context);
                    // 심신안정 페이지로 이동
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
                // 온라인 문의 페이지로 이동
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
        selectedItemColor: Colors.blue,
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
            label: '상품',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_cart),
            label: '장바구니',
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
        return _buildProductPage();
      case 2:
        return _buildCartPage();
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
                
                // 모바일 제품 소개 슬라이더
                const MobileProductSlider(),
                
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

  Widget _buildProductPage() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_bag, size: 64, color: Colors.blue),
          SizedBox(height: 16),
          Text(
            '상품 페이지',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            '상품 목록이 여기에 표시됩니다',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCartPage() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart, size: 64, color: Colors.blue),
          SizedBox(height: 16),
          Text(
            '장바구니',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            '장바구니 내용이 여기에 표시됩니다',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildMyPage() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person, size: 64, color: Colors.blue),
          SizedBox(height: 16),
          Text(
            '마이페이지',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            '회원 정보가 여기에 표시됩니다',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

// 모바일 제품 소개 슬라이더
class MobileProductSlider extends StatelessWidget {
  const MobileProductSlider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      child: Column(
        children: [
          Expanded(
            child: _buildProductSlide(
              title: "한의사가\n자신있게 처방하는\n다이어트 솔루션",
              subtitle: "과거에 과체중으로 스트레스를 받던 한의사가\n직접 복용하고, 개발한 다이어트 한약",
              productName: "보미 다이어트환",
              color: const Color(0xFF007FAE),
              features: [
                "굶지않는 한방 다이어트",
                "내 몸을 위한 건강한 체중감량", 
                "기초대사량 증가, 신진대사 활발",
                "체지방 분해, 식욕억제, 부종감소, 포만감"
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: _buildProductSlide(
              title: "한의사가\n자신있게 처방하는\n디톡스 솔루션",
              subtitle: "과거에 과체중으로 스트레스를 받던 한의사가\n직접 복용하고, 개발한 디톡스 한약",
              productName: "보미 디톡스환",
              color: const Color(0xFF499C28),
              features: [
                "붓기개선과 변비예방",
                "노폐물, 체지방 배출",
                "붓기감소, 체중감소, 미백작용",
                "혈액순환 개선, 변비개선"
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductSlide({
    required String title,
    required String subtitle,
    required String productName,
    required Color color,
    required List<String> features,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              productName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ...features.map((feature) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    feature,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }
}
