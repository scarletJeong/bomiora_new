import 'package:flutter/material.dart';
import '../widgets/banner_slider.dart';
import '../widgets/review_section.dart';
import '../widgets/product_section.dart';
import '../widgets/wellness_section.dart';
import '../widgets/category_section.dart';
import '../widgets/guidebook_section.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/models/user/user_model.dart';
import '../../user/myPage/screens/my_page_screen.dart';
import '../../common/widgets/app_bar_menu.dart';
import '../../common/widgets/appbar_menutap.dart';
import '../../common/widgets/navi_bar.dart';
import '../../common/widgets/app_footer.dart';  
import '../../health/health_common/health_responsive_scale.dart';
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
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadData();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.getUser();
    if (!mounted) return;
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
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home',
          (route) => false,
        );
      }
    }
  }

  Future<void> _loadData() async {
    try {
      // 임시로 더미 데이터 사용 (API 연동 전)
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }
  
  // 3 메뉴판
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: false,
      appBar: AppBarMenu(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      drawer: AppBarMenuTapDrawer(
        onHealthDashboardTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/health');
        },
      ),
      body: _getCurrentPage(),
      bottomNavigationBar: const FooterBar(),
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
    final sectionGap = healthDp(context, 40);

    return isLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            child: Column(
              children: [
                // 메인 배너 슬라이더
                const BannerSlider(),
                SizedBox(height: sectionGap),

                // 웰니스 섹션  - 임시
                const WellnessSection(),
                SizedBox(height: sectionGap),

                // 신상품 섹션 - 임시
                const ProductSection(),
                SizedBox(height: sectionGap),
                
                // 카테고리 섹션 - 임시
                const CategorySection(),
                SizedBox(height: sectionGap),
                
                // 가이드북 섹션 - 임시
                const GuidebookSection(),
                SizedBox(height: sectionGap),

                // 리뷰 섹션 - 임시
                const ReviewSection(),
                SizedBox(height: sectionGap),

                // 공지사항 섹션 - 임시
                const NoticeSection(),
                SizedBox(height: sectionGap),

                // 이벤트 섹션 - 임시
                const EventSection(),
                SizedBox(height: sectionGap),
    
                // Footer
                // const AppFooter(),
                const AppFooter(),
              ],
            ),
          );
  }

  Widget _buildMyPage() {
    return const MyPageScreen();
  }

}

