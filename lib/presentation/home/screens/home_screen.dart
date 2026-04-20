import 'package:flutter/material.dart';
import '../widgets/main_banner_slider.dart';
import '../widgets/review_section.dart';
import '../widgets/bottom_banner.dart';
import '../widgets/new_product.dart';
import '../widgets/wellness_section.dart';
import '../widgets/category_section.dart';
import '../widgets/guidebook_section.dart';
import '../widgets/home_quick_tab_section.dart';
import '../../../core/constants/app_assets.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/models/user/user_model.dart';
import '../../user/myPage/screens/my_page_screen.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/appbar_menutap.dart';
import '../../common/widgets/app_footer.dart';
import '../widgets/notice_section.dart';
import '../widgets/event_section.dart';

class HomeScreen extends StatefulWidget {
  final int initialIndex;

  const HomeScreen({
    super.key,
    this.initialIndex = 0,
  });

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
    _currentIndex = widget.initialIndex;
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
    final isMyPage = _currentIndex == 1;

    return MobileAppLayoutWrapper(
      child: Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: !isMyPage,
      appBar: isMyPage
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              surfaceTintColor: Colors.transparent,
              leading: Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.black),
                  onPressed: () {
                    Scaffold.of(context).openDrawer();
                  },
                ),
              ),
              title: Image.asset(
                AppAssets.bomioraLogo,
                height: 40,
              ),
              centerTitle: true,
            ),
      drawer: isMyPage
          ? null
          : AppBarMenuTapDrawer(
              onHealthDashboardTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/health');
              },
            ),
      body: _getCurrentPage(),
      // 하단 탭 임시 비활성화
      // bottomNavigationBar: SizedBox(
      //   height: kBottomNavigationBarHeight + 2.0,
      //   child: ...,
      // ),
    ),
    );
  }

  Widget _getCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return _buildHomePage();
      case 1:
        return _buildMyPage();
      default:
        return _buildHomePage();
    }
  }

  Widget _buildHomePage() {
    const sectionGap = SizedBox(height: 24);

    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Column(
              children: [
                // 메인 배너 슬라이더
                const MainBannerSlider(),
                const HomeQuickTabSection(),
                sectionGap,

                // 웰니스 섹션  - 임시
                const WellnessSection(),
                sectionGap,

                // 신상품 섹션 - 임시
                const NewProductSection(),
                sectionGap,
                
                // 카테고리 섹션 - 임시
                const CategorySection(),
                sectionGap,
                
                // 가이드북 섹션 - 임시
                const GuidebookSection(),
                sectionGap,

                // 리뷰 섹션 - 임시
                const ReviewSection(),
                sectionGap,

                // 공지사항 섹션 - 임시
                const NoticeSection(),
                sectionGap,

                // 이벤트 섹션 - 임시
                const EventSection(),
                sectionGap,
    
                // Footer
                // const AppFooter(),
              ],
            ),
          );
  }

  Widget _buildMyPage() {
    return const MyPageScreen();
  }

}

