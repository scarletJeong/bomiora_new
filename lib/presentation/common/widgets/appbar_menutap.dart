import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/node_value_parser.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../data/models/user/user_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/recent_view_service.dart';
import '../../shopping/screens/cart_general_screen.dart' as cart_general;
import '../../../data/repositories/product/product_category_catalog.dart';
import '../../shopping/utils/get_product.dart';
import '../../settings/settings_screen.dart';
import '../../health/health_common/health_responsive_scale.dart';
import 'cart_dropdown_menu.dart';

/// AppBar 햄버거 메뉴에서 공통으로 사용하는 Drawer (Figma 사이드 메뉴 스타일)
class AppBarMenuTapDrawer extends StatefulWidget {
  final VoidCallback onHealthDashboardTap;

  const AppBarMenuTapDrawer({
    super.key,
    required this.onHealthDashboardTap,
  });

  @override
  State<AppBarMenuTapDrawer> createState() => _AppBarMenuTapDrawerState();
}

class _AppBarMenuTapDrawerState extends State<AppBarMenuTapDrawer> {
  static const String _fontFamily = 'Gmarket Sans TTF';

  static const Color _inkTitle = Color(0xFF1A1A1A);
  static const Color _inkMuted = Color(0xFF898686);
  static const Color _divider = Color(0x7FD2D2D2);
  static const Color _brandPink = Color(0xFFFF5A8D);

  UserModel? _user;
  bool _isTelemedicineExpanded = false;
  bool _isHealthcareStoreExpanded = false;
  bool _isContentExpanded = false;
  List<Map<String, dynamic>> _recentProducts = [];
  bool _isLoadingRecent = false;
  List<ProductCategoryItem> _generalCategories =
      List<ProductCategoryItem>.from(productGeneralCategoryListFallback);
  List<ProductCategoryItem> _prescriptionCategories =
      List<ProductCategoryItem>.from(productPrescriptionCategoryListFallback);

  @override
  void initState() {
    super.initState();
    _refreshUser().then((_) => _loadRecentProducts());
    _loadShopCategories();
  }

  Future<void> _loadShopCategories() async {
    final results = await Future.wait([
      ProductCategoryCatalog.generalCategories(),
      ProductCategoryCatalog.prescriptionCategories(),
    ]);
    if (!mounted) return;
    setState(() {
      _generalCategories = results[0];
      _prescriptionCategories = results[1];
    });
  }

  Future<void> _refreshUser() async {
    final u = await AuthService.getUser();
    if (mounted) setState(() => _user = u);
  }

  Future<void> _loadRecentProducts() async {
    if (!mounted) return;
    setState(() => _isLoadingRecent = true);
    final items = await RecentViewService.getRecentList(limit: 4);
    if (!mounted) return;
    setState(() {
      _recentProducts = items;
      _isLoadingRecent = false;
    });
  }

  void _openRecentProduct(BuildContext context, Map<String, dynamic> item) {
    final itId = NodeValueParser.asString(item['it_id'])?.trim() ?? '';
    if (itId.isEmpty) return;

    final kind = (NodeValueParser.asString(item['it_kind']) ??
            NodeValueParser.asString(item['product_kind']) ??
            '')
        .trim()
        .toLowerCase();

    Navigator.pop(context);
    if (kind == 'general') {
      Navigator.pushNamed(context, '/product-general/$itId');
    } else {
      Navigator.pushNamed(context, '/product/$itId');
    }
  }

  String get _greetingName {
    final u = _user;
    if (u == null) return '회원';
    final n = (u.nickname != null && u.nickname!.trim().isNotEmpty)
        ? u.nickname!.trim()
        : u.name.trim();
    return n.isEmpty ? '회원' : n;
  }

  void _popAndPushNamed(BuildContext context, String route,
      {Object? arguments}) {
    Navigator.pop(context);
    Navigator.pushNamed(context, route, arguments: arguments);
  }

  ProductCategoryItem _prescriptionDietCategory() {
    return _prescriptionCategories.firstWhere(
      (item) => item.categoryId == '10',
      orElse: () => productPrescriptionCategoryListFallback.first,
    );
  }

  void _openPrescriptionDietList(BuildContext context) {
    final diet = _prescriptionDietCategory();
    _popAndPushNamed(
      context,
      '/product/',
      arguments: {
        'categoryId': diet.categoryId,
        'categoryName': diet.label,
        'productKind': 'prescription',
      },
    );
  }

  TextStyle _mainMenuTitleStyle(BuildContext context) => TextStyle(
        color: const Color(0xFF1A1A1E),
        fontSize: healthSp(context, 14),
        fontFamily: _fontFamily,
        fontWeight: FontWeight.w500,
        letterSpacing: healthSp(context, -1.26),
      );

  EdgeInsets _mainMenuTitlePadding(BuildContext context) =>
      EdgeInsets.symmetric(vertical: healthDp(context, 10));

  Future<void> _openKakaoTalkConsult() async {
    const kakaoChannelUrl = 'https://pf.kakao.com/_NdxgAG';
    final uri = Uri.parse(kakaoChannelUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened || !mounted) return;
    Navigator.pop(context);
  }

  Widget _buildShortcutGrid(BuildContext context) {
    Widget cell(_DrawerShortcutData d) {
      return Expanded(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: healthDp(context, 2)),
          child: _DrawerShortcut(
            icon: d.icon,
            label: d.label,
            onTap: d.onTap,
            onCartPrescriptionTap: d.onCartPrescriptionTap,
            onCartShoppingTap: d.onCartShoppingTap,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cell(_DrawerShortcutData(
              icon: Icons.home_outlined,
              label: '홈',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/home');
              },
            )),
            cell(_DrawerShortcutData(
              icon: Icons.assignment_outlined,
              label: '문진표',
              onTap: () => _popAndPushNamed(context, '/profile'),
            )),
            cell(_DrawerShortcutData(
              icon: Icons.local_shipping_outlined,
              label: '주문배송',
              onTap: () => _popAndPushNamed(context, '/order'),
            )),
            cell(_DrawerShortcutData(
              icon: Icons.shopping_cart_outlined,
              label: '장바구니',
              onTap: () {},
              onCartPrescriptionTap: () => _popAndPushNamed(context, '/cart'),
              onCartShoppingTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const cart_general.CartScreen(),
                  ),
                );
              },
            )),
          ],
        ),
        SizedBox(height: healthDp(context, 14)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cell(_DrawerShortcutData(
              icon: Icons.confirmation_number_outlined,
              label: '쿠폰',
              onTap: () => _popAndPushNamed(context, '/coupon'),
            )),
            cell(_DrawerShortcutData(
              icon: Icons.stars_outlined,
              label: '포인트',
              onTap: () => _popAndPushNamed(context, '/point'),
            )),
            cell(_DrawerShortcutData(
              icon: Icons.person_outline,
              label: '마이페이지',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/my_page');
              },
            )),
            cell(_DrawerShortcutData(
              icon: Icons.headset_mic_outlined,
              label: '카카오톡 상담',
              onTap: _openKakaoTalkConsult,
            )),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        drawerTheme: DrawerThemeData(
          width: healthDp(context, 250),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(
              right: Radius.circular(healthDp(context, 20)),
            ),
          ),
          scrimColor: Colors.black.withValues(alpha: 0.20),
        ),
      ),
      child: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              healthDp(context, 20),
              healthDp(context, 50),
              healthDp(context, 20),
              healthDp(context, 20),
            ),
            children: [
              _buildHeader(context),
              SizedBox(height: healthDp(context, 20)),
              _buildShortcutGrid(context),
              SizedBox(height: healthDp(context, 20)),
              Divider(
                height: healthDp(context, 1),
                thickness: healthDp(context, 1),
                color: _divider,
              ),
              SizedBox(height: healthDp(context, 20)),
              _SectionRow(
                title: '보미오라소개',
                titleStyle: _mainMenuTitleStyle(context),
                titlePadding: _mainMenuTitlePadding(context),
                onTap: () => _popAndPushNamed(context, '/bomiora-introduce'),
              ),
              SizedBox(height: healthDp(context, 10)),
              _SectionRow(
                title: '건강 대시보드',
                titleStyle: _mainMenuTitleStyle(context),
                titlePadding: _mainMenuTitlePadding(context),
                onTap: () {
                  Navigator.pop(context);
                  widget.onHealthDashboardTap();
                },
              ),
              SizedBox(height: healthDp(context, 10)),
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: Column(
                  children: [
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _openPrescriptionDietList(context),
                                child: Padding(
                                  padding: _mainMenuTitlePadding(context),
                                  child: Text(
                                    '비대면 진료',
                                    style: _mainMenuTitleStyle(context),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _isTelemedicineExpanded =
                                      !_isTelemedicineExpanded;
                                });
                              },
                              icon: Icon(
                                _isTelemedicineExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: _inkTitle,
                                size: healthDp(context, 24),
                              ),
                            ),
                          ],
                        ),
                        AnimatedCrossFade(
                          firstChild: Padding(
                            padding: EdgeInsets.only(bottom: healthDp(context, 8)),
                            child: _ExpansionSubmenuWithRail(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ..._prescriptionCategories.map(
                                    (item) => _SubLink(
                                      label: productPrescriptionCategoryMenuLabel(
                                        item.label,
                                      ),
                                      onTap: () => _popAndPushNamed(
                                        context,
                                        '/product/',
                                        arguments: {
                                          'categoryId': item.categoryId,
                                          'categoryName': item.label,
                                          'productKind': 'prescription',
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          secondChild: const SizedBox.shrink(),
                          crossFadeState: _isTelemedicineExpanded
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                          duration: const Duration(milliseconds: 180),
                        ),
                      ],
                    ),
                    SizedBox(height: healthDp(context, 10)),
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                  Navigator.pushNamed(
                                    context,
                                    '/healthcare-store',
                                  );
                                },
                                child: Padding(
                                  padding: _mainMenuTitlePadding(context),
                                  child: Text(
                                    '헬스케어 스토어',
                                    style: _mainMenuTitleStyle(context),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _isHealthcareStoreExpanded =
                                      !_isHealthcareStoreExpanded;
                                });
                              },
                              icon: Icon(
                                _isHealthcareStoreExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: _inkTitle,
                                size: healthDp(context, 24),
                              ),
                            ),
                          ],
                        ),
                        AnimatedCrossFade(
                          firstChild: Padding(
                            padding: EdgeInsets.only(bottom: healthDp(context, 8)),
                            child: _ExpansionSubmenuWithRail(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: _generalCategories
                                    .map(
                                      (item) => _SubLink(
                                        label: item.label,
                                        onTap: () => _popAndPushNamed(
                                          context,
                                          '/product-general/',
                                          arguments: {
                                            'categoryId': item.categoryId,
                                            'categoryName': item.label,
                                            'productKind': 'general',
                                          },
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ),
                          ),
                          secondChild: const SizedBox.shrink(),
                          crossFadeState: _isHealthcareStoreExpanded
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                          duration: const Duration(milliseconds: 180),
                        ),
                      ],
                    ),
                    SizedBox(height: healthDp(context, 10)),
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () => _popAndPushNamed(context, '/content'),
                                child: Padding(
                                  padding: _mainMenuTitlePadding(context),
                                  child: Text(
                                    '건강 콘텐츠',
                                    style: _mainMenuTitleStyle(context),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _isContentExpanded = !_isContentExpanded;
                                });
                              },
                              icon: Icon(
                                _isContentExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: _inkTitle,
                                size: healthDp(context, 24),
                              ),
                            ),
                          ],
                        ),
                        AnimatedCrossFade(
                          firstChild: Padding(
                            padding: EdgeInsets.only(bottom: healthDp(context, 8)),
                            child: _ExpansionSubmenuWithRail(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _SubLink(
                                    label: '건강상식',
                                    onTap: () => _popAndPushNamed(
                                      context,
                                      '/content/list',
                                      arguments: const {'category': '건강상식'},
                                    ),
                                  ),
                                  _SubLink(
                                    label: '운동가이드',
                                    onTap: () => _popAndPushNamed(
                                      context,
                                      '/content/list',
                                      arguments: const {'category': '운동가이드'},
                                    ),
                                  ),
                                  _SubLink(
                                    label: '추천식단',
                                    onTap: () => _popAndPushNamed(
                                      context,
                                      '/content/list',
                                      arguments: const {'category': '추천식단'},
                                    ),
                                  ),
                                  _SubLink(
                                    label: '질환관리',
                                    onTap: () => _popAndPushNamed(
                                      context,
                                      '/content/list',
                                      arguments: const {'category': '질환관리'},
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          secondChild: const SizedBox.shrink(),
                          crossFadeState: _isContentExpanded
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                          duration: const Duration(milliseconds: 180),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: healthDp(context, 20)),
              Divider(
                height: healthDp(context, 1),
                thickness: healthDp(context, 1),
                color: _divider,
              ),
              SizedBox(height: healthDp(context, 20)),
              Text(
                '최근에 본 상품',
                style: TextStyle(
                  color: _inkMuted,
                  fontSize: healthSp(context, 12),
                  fontFamily: _fontFamily,
                  fontWeight: FontWeight.w500,
                  height: 1.32,
                ),
              ),
              SizedBox(height: healthDp(context, 10)),
              _RecentProductsGrid(
                items: _recentProducts,
                isLoading: _isLoadingRecent,
                isLoggedIn: _user != null,
                onTapProduct: (item) => _openRecentProduct(context, item),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    if (_user == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '로그인을 하세요.',
                  style: TextStyle(
                    fontSize: healthSp(context, 16),
                    fontFamily: 'Gmarket Sans TTF',
                    color: Colors.black,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              _DrawerSettingsIcon(context),
            ],
          ),
          SizedBox(height: healthDp(context, 16)),
          Row(
            children: [
              SizedBox(
                width: healthDp(context, 70),
                height: healthDp(context, 22),
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/login');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _brandPink,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    minimumSize: Size(
                      healthDp(context, 70),
                      healthDp(context, 22),
                    ),
                    fixedSize: Size(
                      healthDp(context, 70),
                      healthDp(context, 22),
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(healthDp(context, 6)),
                    ),
                  ),
                  child: Text(
                    '로그인',
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: healthSp(context, 10),
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              SizedBox(width: healthDp(context, 10)),
              SizedBox(
                width: healthDp(context, 70),
                height: healthDp(context, 22),
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/signup');
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _brandPink,
                    side: BorderSide(
                      color: _brandPink,
                      width: healthDp(context, 1),
                    ),
                    padding: EdgeInsets.zero,
                    minimumSize: Size(
                      healthDp(context, 70),
                      healthDp(context, 22),
                    ),
                    fixedSize: Size(
                      healthDp(context, 70),
                      healthDp(context, 22),
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(healthDp(context, 6)),
                    ),
                  ),
                  child: Text(
                    '회원가입',
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: healthSp(context, 10),
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: healthSp(context, 16),
                    fontFamily: _fontFamily,
                    color: Colors.black,
                  ),
                  children: [
                    TextSpan(
                      text: '$_greetingName 님 ',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: healthSp(context, 16),
                        fontFamily: _fontFamily,
                      ),
                    ),
                    TextSpan(
                      text: '안녕하세요.',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: healthSp(context, 16),
                        fontFamily: _fontFamily,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _DrawerSettingsIcon(context),
          ],
        ),
      ],
    );
  }
}

class _DrawerSettingsIcon extends StatelessWidget {
  final BuildContext drawerContext;

  const _DrawerSettingsIcon(this.drawerContext);

  void _onTap() {
    Navigator.pop(drawerContext);
    Navigator.push(
      drawerContext,
      MaterialPageRoute<void>(
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _onTap,
        borderRadius: BorderRadius.circular(healthDp(context, 8)),
        child: SizedBox(
          //width: healthDp(context, 25),
          //height: healthDp(context, 25),
          child: Center(
            child: SvgPicture.asset(
              AppAssets.settingsIcon,
              width: healthDp(context, 25),
              height: healthDp(context, 25),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

/// 펼친 하위 메뉴 왼쪽에 이어지는 세로 라인
class _ExpansionSubmenuWithRail extends StatelessWidget {
  final Widget child;

  const _ExpansionSubmenuWithRail({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: const Color(0xFFD2D2D2),
            width: healthDp(context, 1.5),
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.only(left: healthDp(context, 12)),
        child: child,
      ),
    );
  }
}

class _DrawerShortcutData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onCartPrescriptionTap;
  final VoidCallback? onCartShoppingTap;

  const _DrawerShortcutData({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onCartPrescriptionTap,
    this.onCartShoppingTap,
  });
}

/// 4×2 그리드 셀: 마우스 호버·손가락 누름 시 아이콘·글자 #FF5A8D
class _DrawerShortcut extends StatefulWidget {
  static const String _fontFamily = 'Gmarket Sans TTF';
  static const Color _muted = Color(0xFF898686);
  static const Color _hoverPink = Color(0xFFFF5A8D);

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onCartPrescriptionTap;
  final VoidCallback? onCartShoppingTap;

  const _DrawerShortcut({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onCartPrescriptionTap,
    this.onCartShoppingTap,
  });

  @override
  State<_DrawerShortcut> createState() => _DrawerShortcutState();
}

class _DrawerShortcutState extends State<_DrawerShortcut> {
  bool _hover = false;
  bool _pressed = false;
  bool _showCartDropdown = false;
  final GlobalKey _cartAnchorKey = GlobalKey();
  OverlayEntry? _cartDropdownEntry;

  bool get _highlight => _hover || _pressed;
  bool get _isCartShortcut =>
      widget.label == '장바구니' &&
      widget.onCartPrescriptionTap != null &&
      widget.onCartShoppingTap != null;

  void _toggleCartDropdown() {
    if (_showCartDropdown) {
      _closeCartDropdown();
    } else {
      _openCartDropdown();
    }
  }

  void _onShortcutTap() {
    if (_isCartShortcut) {
      _openCartDropdown();
      return;
    }
    widget.onTap();
  }

  void _openCartDropdown() {
    if (_showCartDropdown) return;

    final anchorContext = _cartAnchorKey.currentContext;
    final anchorBox = anchorContext?.findRenderObject() as RenderBox?;
    if (anchorBox == null || !anchorBox.attached) return;

    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    final anchorTopLeft = anchorBox.localToGlobal(Offset.zero);

    final menuW = cartDropdownWidth(context);
    double left = anchorTopLeft.dx + anchorBox.size.width - menuW;
    double top = anchorTopLeft.dy +
        anchorBox.size.height +
        healthDp(context, 6);
    if (overlayBox != null) {
      final edge = healthDp(context, 8);
      left = left.clamp(edge, overlayBox.size.width - menuW - edge);
      final menuH = healthDp(context, 96);
      top = top.clamp(edge, overlayBox.size.height - menuH - edge);
    }

    _cartDropdownEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeCartDropdown,
              child: const SizedBox.expand(),
            ),
          ),
          Positioned(
            left: left,
            top: top,
            child: Material(
              color: Colors.transparent,
              child: CartDropdownMenuPanel(
                onPrescriptionTap: () =>
                    _onSelectCartOption(widget.onCartPrescriptionTap),
                onShoppingTap: () =>
                    _onSelectCartOption(widget.onCartShoppingTap),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_cartDropdownEntry!);
    setState(() {
      _showCartDropdown = true;
    });
  }

  void _closeCartDropdown() {
    _cartDropdownEntry?.remove();
    _cartDropdownEntry = null;
    if (mounted && _showCartDropdown) {
      setState(() {
        _showCartDropdown = false;
      });
    }
  }

  void _onSelectCartOption(VoidCallback? onTap) {
    if (onTap == null) return;
    _closeCartDropdown();
    onTap();
  }

  @override
  void dispose() {
    _closeCartDropdown();
    super.dispose();
  }

  @override
  void reassemble() {
    super.reassemble();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cartDropdownEntry?.remove();
      _cartDropdownEntry = null;
      _showCartDropdown = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final color =
        _highlight ? _DrawerShortcut._hoverPink : _DrawerShortcut._muted;
    final labelStyle = TextStyle(
      color: color,
      fontSize: healthSp(context, 10),
      fontFamily: _DrawerShortcut._fontFamily,
      fontWeight: _highlight ? FontWeight.w700 : FontWeight.w500,
      height: 1.35,
    );

    final isPoint = widget.label == '포인트';
    return Material(
      color: Colors.transparent,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => setState(() => _pressed = true),
          onPointerUp: (_) => setState(() => _pressed = false),
          onPointerCancel: (_) => setState(() => _pressed = false),
          child: InkWell(
            onTap: _onShortcutTap,
            borderRadius: BorderRadius.circular(healthDp(context, 12)),
            splashColor: _DrawerShortcut._hoverPink.withValues(alpha: 0.18),
            highlightColor: _DrawerShortcut._hoverPink.withValues(alpha: 0.08),
            hoverColor: Colors.transparent,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: healthDp(context, 4)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    key: _cartAnchorKey,
                    width: healthDp(context, 44),
                    height: healthDp(context, 44),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: healthDp(context, 44),
                          height: healthDp(context, 44),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(
                              healthDp(context, 15),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0x19000000),
                                blurRadius: healthDp(context, 4),
                                offset: Offset.zero,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: isPoint
                              ? Text(
                                  'P',
                                  style: TextStyle(
                                    color: color,
                                    fontSize: healthSp(context, 16),
                                    fontFamily: _DrawerShortcut._fontFamily,
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : Icon(
                                  widget.icon,
                                  size: healthDp(context, 22),
                                  color: color,
                                ),
                        ),
                        if (_isCartShortcut)
                          Positioned(
                            right: -healthDp(context, 4),
                            bottom: -healthDp(context, 4),
                            child: GestureDetector(
                              onTap: _toggleCartDropdown,
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                width: healthDp(context, 20),
                                height: healthDp(context, 20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFFF5A8D),
                                    width: healthDp(context, 1),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0x19000000),
                                      blurRadius: healthDp(context, 4),
                                      offset: Offset.zero,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _showCartDropdown
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  size: healthDp(context, 16),
                                  color: const Color(0xFFFF5A8D),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  SizedBox(height: healthDp(context, 6)),
                  Text(
                    widget.label,
                    style: labelStyle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  final String title;
  final TextStyle titleStyle;
  final EdgeInsets titlePadding;
  final VoidCallback onTap;

  const _SectionRow({
    required this.title,
    required this.titleStyle,
    required this.titlePadding,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: titlePadding,
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: titleStyle,
              ),
            ),
            Transform.rotate(
              angle: -1.5708,
              child: Icon(
                Icons.keyboard_arrow_down,
                size: healthDp(context, 20),
                color: const Color(0xFF1A1A1E),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubLink extends StatelessWidget {
  static const String _fontFamily = 'Gmarket Sans TTF';

  final String label;
  final VoidCallback onTap;

  const _SubLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: healthDp(context, 8),
          horizontal: healthDp(context, 4),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: TextStyle(
              color: const Color(0xFF898686),
              fontSize: healthSp(context, 14),
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w500,
              letterSpacing: healthSp(context, -1.26),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentProductsGrid extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final bool isLoading;
  final bool isLoggedIn;
  final void Function(Map<String, dynamic> item) onTapProduct;

  const _RecentProductsGrid({
    required this.items,
    required this.isLoading,
    required this.isLoggedIn,
    required this.onTapProduct,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return SizedBox(
        height: healthDp(context, 120),
        child: Center(
          child: SizedBox(
            width: healthDp(context, 24),
            height: healthDp(context, 24),
            child: CircularProgressIndicator(
              strokeWidth: healthDp(context, 2),
              color: const Color(0xFFFF5A8D),
            ),
          ),
        ),
      );
    }

    if (!isLoggedIn) {
      return _buildEmptyMessage(
        context,
        '로그인 후 최근 본 상품을 확인할 수 있습니다.',
      );
    }

    if (items.isEmpty) {
      return _buildEmptyMessage(context, '최근 본 상품이 없습니다.');
    }

    final radius = healthDp(context, 5.12);
    const borderColor = Color(0x7FD2D2D2);
    final display = items.take(4).toList();
    final rows = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < display.length; i += 2) {
      final end = (i + 2 <= display.length) ? i + 2 : display.length;
      rows.add(display.sublist(i, end));
    }

    return Column(
      children: [
        for (var rowIndex = 0; rowIndex < rows.length; rowIndex++) ...[
          if (rowIndex > 0) SizedBox(height: healthDp(context, 10)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var colIndex = 0; colIndex < rows[rowIndex].length; colIndex++) ...[
                if (colIndex > 0) SizedBox(width: healthDp(context, 10)),
                Expanded(
                  child: _RecentProductCard(
                    item: rows[rowIndex][colIndex],
                    onTap: () => onTapProduct(rows[rowIndex][colIndex]),
                    radius: radius,
                    borderColor: borderColor,
                  ),
                ),
              ],
              if (rows[rowIndex].length == 1)
                Expanded(child: SizedBox(height: healthDp(context, 1))),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildEmptyMessage(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: healthDp(context, 24)),
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 0.5),
            color: const Color(0x7FD2D2D2),
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
        ),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: const Color(0xFF898686),
          fontSize: healthSp(context, 12),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _RecentProductCard extends StatelessWidget {
  static const String _fontFamily = 'Gmarket Sans TTF';

  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final double radius;
  final Color borderColor;

  const _RecentProductCard({
    required this.item,
    required this.onTap,
    required this.radius,
    required this.borderColor,
  });

  String get _title =>
      NodeValueParser.asString(item['product_name'])?.trim() ??
      NodeValueParser.asString(item['it_name'])?.trim() ??
      '상품';

  String get _price {
    final raw = NodeValueParser.asInt(item['product_price']) ??
        NodeValueParser.asInt(item['it_price']);
    return '${PriceFormatter.format(raw)}원';
  }

  String get _imageUrl {
    final raw = NodeValueParser.asString(item['image_url']) ??
        NodeValueParser.asString(item['it_img']) ??
        NodeValueParser.asString(item['it_img1']) ??
        '';
    return raw.trim();
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageUrl;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(radius),
                    topRight: Radius.circular(radius),
                  ),
                  child: Container(
                    height: healthDp(context, 100),
                    color: const Color(0xFFE8E8E8),
                    alignment: Alignment.center,
                    child: imageUrl.isNotEmpty
                        ? Image.network(
                            ImageUrlHelper.getImageUrl(imageUrl),
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: healthDp(context, 100),
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.image_outlined,
                              color: Colors.grey.shade500,
                              size: healthDp(context, 32),
                            ),
                          )
                        : Icon(
                            Icons.image_outlined,
                            color: Colors.grey.shade500,
                            size: healthDp(context, 32),
                          ),
                  ),
                ),
                Positioned(
                  right: healthDp(context, 6),
                  top: healthDp(context, 6),
                  child: Container(
                    width: healthDp(context, 22),
                    height: healthDp(context, 22),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.favorite_border,
                      size: healthDp(context, 12),
                      color: const Color(0xFF898686),
                    ),
                  ),
                ),
              ],
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                healthDp(context, 6),
                healthDp(context, 6),
                healthDp(context, 6),
                healthDp(context, 10),
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                  color: borderColor,
                  width: healthDp(context, 0.51),
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(radius),
                  bottomRight: Radius.circular(radius),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '보미오라한의원',
                    style: TextStyle(
                      color: const Color(0xFF1A1A1A),
                      fontSize: healthSp(context, 8),
                      fontFamily: _fontFamily,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 2)),
                  Text(
                    _title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF1A1A1A),
                      fontSize: healthSp(context, 10),
                      fontFamily: _fontFamily,
                      fontWeight: FontWeight.w700,
                      letterSpacing: healthSp(context, -0.90),
                    ),
                  ),
                  SizedBox(height: healthDp(context, 4)),
                  Row(
                    children: [
                      Text(
                        '0%',
                        style: TextStyle(
                          color: const Color(0xFFFF5A8D),
                          fontSize: healthSp(context, 8),
                          fontFamily: _fontFamily,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: healthDp(context, 4)),
                      Text(
                        _price,
                        style: TextStyle(
                          color: const Color(0xFF1A1A1A),
                          fontSize: healthSp(context, 8),
                          fontFamily: _fontFamily,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
