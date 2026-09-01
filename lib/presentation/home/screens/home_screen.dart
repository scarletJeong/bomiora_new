import 'package:flutter/material.dart';

import '../../../data/models/home/banner_model.dart';
import '../../../data/models/product/product_model.dart';
import '../../../data/repositories/product/product_repository.dart';
import '../../../data/services/banner_service.dart';
import '../../user/myPage/screens/my_page_screen.dart';
import '../../common/widgets/appbar_menutap.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
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

  /// 스플래시에서 미리 받은 Future — 중복 API 호출 방지
  final Future<List<BannerModel>>? bannersFuture;
  final Future<List<Product>>? newProductsFuture;

  /// 배너 첫 장 + 신상품 이미지가 모두 준비되면 1회 호출
  final VoidCallback? onAboveFoldImagesReady;

  const HomeScreen({
    super.key,
    this.initialIndex = 0,
    this.bannersFuture,
    this.newProductsFuture,
    this.onAboveFoldImagesReady,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final Future<List<BannerModel>> _bannersFuture;
  late final Future<List<Product>> _newProductsFuture;
  bool _loadBelowFold = false;

  bool _bannerReady = false;
  bool _productsReady = false;
  bool _aboveFoldNotified = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _bannersFuture =
        widget.bannersFuture ?? BannerService.fetchMobileBanners();
    _newProductsFuture =
        widget.newProductsFuture ?? ProductRepository.getNewProducts(limit: 4);
    _scheduleBelowFoldLoad();
  }

  void _markBannerReady() {
    if (_bannerReady) return;
    _bannerReady = true;
    _tryNotifyAboveFold();
  }

  void _markProductsReady() {
    if (_productsReady) return;
    _productsReady = true;
    _tryNotifyAboveFold();
  }

  void _tryNotifyAboveFold() {
    if (_aboveFoldNotified) return;
    if (!_bannerReady || !_productsReady) return;
    _aboveFoldNotified = true;
    widget.onAboveFoldImagesReady?.call();
  }

  Future<void> _scheduleBelowFoldLoad() async {
    // 우선 API가 빨리 끝나면 바로, 아니면 최대 ~400ms 후 하단 로드 시작
    await Future.any<void>([
      Future.wait<void>([_bannersFuture, _newProductsFuture]).then((_) {}),
      Future<void>.delayed(const Duration(milliseconds: 400)),
    ]);
    if (!mounted) return;
    setState(() => _loadBelowFold = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: false,
      appBar: HealthAppBar.logo(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        actionsStyle: _currentIndex == 1
            ? HealthAppBarActionsStyle.myPage
            : HealthAppBarActionsStyle.home,
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
          BannerSlider(
            bannersFuture: _bannersFuture,
            onPrimaryImageSettled: _markBannerReady,
          ),
          SizedBox(height: sectionGap),

          // 신상품 (it_kind 무관 · 최신 4개)
          ProductSection(
            productsFuture: _newProductsFuture,
            onImagesSettled: _markProductsReady,
          ),
          SizedBox(height: sectionGap),

          if (_loadBelowFold) ...[
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
          ] else
            SizedBox(height: healthDp(context, 80)),
        ],
      ),
    );
  }

  Widget _buildMyPage() {
    return const MyPageScreen();
  }
}
