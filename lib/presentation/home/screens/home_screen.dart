import 'package:flutter/material.dart';

import '../../user/myPage/screens/my_page_screen.dart';
import '../../common/widgets/app_bar_menu.dart';
import '../../common/widgets/appbar_menutap.dart';
import '../../common/widgets/navi_bar.dart';
import '../../common/widgets/app_footer.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../widgets/banner_slider.dart';
import '../widgets/review_section.dart';
import '../widgets/product_section.dart';
import '../widgets/mdpick_section.dart';
import '../widgets/category_section.dart';
import '../widgets/guidebook_section.dart';
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
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

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

    return SingleChildScrollView(
      child: Column(
        children: [
          const BannerSlider(),
          SizedBox(height: sectionGap),

          // 신상품 (it_kind 무관 · 최신 4개)
          const ProductSection(),
          SizedBox(height: sectionGap),

          const CategorySection(),
          SizedBox(height: sectionGap),

          // MD's Pick (it_type5 + general + ca_id≠a0 · 4개)
          const MdPickSection(),
          SizedBox(height: sectionGap),

          const GuidebookSection(),
          SizedBox(height: sectionGap),

          const ReviewSection(),
          SizedBox(height: sectionGap),

          const NoticeSection(),
          SizedBox(height: sectionGap),

          const EventSection(),
          SizedBox(height: sectionGap),
          const AppFooter(),
        ],
      ),
    );
  }

  Widget _buildMyPage() {
    return const MyPageScreen();
  }
}
