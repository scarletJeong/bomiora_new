import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/utils/node_value_parser.dart';
import '../../../data/models/user/user_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/prescription_purchase_history_service.dart';
import '../../../data/services/recent_view_service.dart';
import '../../shopping/screens/cart_general_screen.dart' as cart_general;
import '../../shopping/screens/cart_integration_screen.dart';
import '../../../data/repositories/product/product_category_catalog.dart';
import '../../shopping/utils/get_product.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../customer_service/screens/qa_list_screen.dart';
import 'app_toast_overlay.dart';
import 'cart_dropdown_menu.dart';
import 'recent_product_card.dart';

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
  List<Map<String, dynamic>> _recentProducts = [];
  bool _isLoadingRecent = false;
  List<ProductCategoryItem> _generalCategories =
      List<ProductCategoryItem>.from(productGeneralCategoryListFallback);
  List<ProductCategoryItem> _prescriptionCategories =
      List<ProductCategoryItem>.from(productPrescriptionCategoryListFallback);

  @override
  void initState() {
    super.initState();
    RecentViewService.revision.addListener(_onRecentViewChanged);
    _refreshUser().then((_) => _loadRecentProducts());
    _loadShopCategories();
  }

  @override
  void dispose() {
    RecentViewService.revision.removeListener(_onRecentViewChanged);
    super.dispose();
  }

  void _onRecentViewChanged() {
    _loadRecentProducts();
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
        height: 1,
      );

  EdgeInsets _mainMenuTitlePadding(BuildContext context) =>
      EdgeInsets.symmetric(vertical: healthDp(context, 10));

  void _openHealthcareStoreTopCategory(BuildContext context) {
    final top = _generalCategories.isNotEmpty
        ? _generalCategories.first
        : productGeneralCategoryListFallback.first;
    _popAndPushNamed(
      context,
      '/product-general/',
      arguments: {
        'categoryId': top.categoryId,
        'categoryName': top.label,
        'productKind': 'general',
      },
    );
  }

  Future<void> _openAdminPage() async {
    final result = await AuthService.issueAdminLoginToken();
    final loginUrl = result['loginUrl']?.toString() ?? '';
    if (result['success'] == true && loginUrl.isNotEmpty) {
      await launchUrl(
        Uri.parse(loginUrl),
        mode: LaunchMode.externalApplication,
      );
      return;
    }
    if (!mounted) return;
    AppToastOverlay.show(
      context,
      result['message']?.toString() ?? '관리자 페이지를 열 수 없습니다.',
    );
  }

  void _openContactList(BuildContext context) {
    Navigator.pop(context);
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => const QaListScreen(),
      ),
    );
  }

  Widget _buildShortcutGrid(BuildContext context) {
    final tileW = healthDp(context, _DrawerShortcut._tileSize);
    final tileGap = healthDp(context, _DrawerShortcut._tileGap);

    Widget cell(_DrawerShortcutData d) {
      return SizedBox(
        width: tileW,
        child: _DrawerShortcut(
          iconAsset: d.iconAsset,
          label: d.label,
          onTap: d.onTap,
          onCartPrescriptionTap: d.onCartPrescriptionTap,
          onCartShoppingTap: d.onCartShoppingTap,
        ),
      );
    }

    Widget shortcutRow(List<_DrawerShortcutData> items) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) SizedBox(width: tileGap),
              cell(items[i]),
            ],
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        shortcutRow([
          _DrawerShortcutData(
            iconAsset: AppAssets.menu_home_icon,
            label: '홈',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/home');
            },
          ),
          _DrawerShortcutData(
            iconAsset: AppAssets.menu_health_icon,
            label: '문진표',
            onTap: () => _popAndPushNamed(context, '/profile'),
          ),
          _DrawerShortcutData(
            iconAsset: AppAssets.menu_order_icon,
            label: '주문배송',
            onTap: () => _popAndPushNamed(context, '/order'),
          ),
          _DrawerShortcutData(
            iconAsset: AppAssets.menu_cart_icon,
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
          ),
        ]),
        SizedBox(height: healthDp(context, _DrawerShortcut._rowStackGap)),
        shortcutRow([
          _DrawerShortcutData(
            iconAsset: AppAssets.menu_coupon_icon,
            label: '쿠폰',
            onTap: () => _popAndPushNamed(context, '/coupon'),
          ),
          _DrawerShortcutData(
            iconAsset: AppAssets.menu_point_icon,
            label: '포인트',
            onTap: () => _popAndPushNamed(context, '/point'),
          ),
          _DrawerShortcutData(
            iconAsset: AppAssets.menu_mypage_icon,
            label: '마이페이지',
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/my_page');
            },
          ),
          _DrawerShortcutData(
            iconAsset: AppAssets.menu_QA_icon,
            label: '1:1 문의',
            onTap: () => _openContactList(context),
          ),
        ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        drawerTheme: DrawerThemeData(
          width: healthDp(context, 280),
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
                                hoverColor: Colors.transparent,
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                overlayColor: const WidgetStatePropertyAll(
                                  Colors.transparent,
                                ),
                                child: Padding(
                                  padding: _mainMenuTitlePadding(context),
                                  child: Text(
                                    '비대면 진료',
                                    style: _mainMenuTitleStyle(context),
                                  ),
                                ),
                              ),
                            ),
                            _MenuChevron(
                              direction: _isTelemedicineExpanded
                                  ? _MenuChevronDirection.up
                                  : _MenuChevronDirection.down,
                              onTap: () {
                                setState(() {
                                  _isTelemedicineExpanded =
                                      !_isTelemedicineExpanded;
                                });
                              },
                            ),
                          ],
                        ),
                        AnimatedCrossFade(
                          firstChild: Padding(
                            padding:
                                EdgeInsets.only(bottom: healthDp(context, 8)),
                            child: _ExpansionSubmenuWithRail(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ..._prescriptionCategories.map(
                                    (item) => _SubLink(
                                      label:
                                          productPrescriptionCategoryMenuLabel(
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
                                onTap: () =>
                                    _openHealthcareStoreTopCategory(context),
                                hoverColor: Colors.transparent,
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                overlayColor: const WidgetStatePropertyAll(
                                  Colors.transparent,
                                ),
                                child: Padding(
                                  padding: _mainMenuTitlePadding(context),
                                  child: Text(
                                    '헬스케어 스토어',
                                    style: _mainMenuTitleStyle(context),
                                  ),
                                ),
                              ),
                            ),
                            _MenuChevron(
                              direction: _isHealthcareStoreExpanded
                                  ? _MenuChevronDirection.up
                                  : _MenuChevronDirection.down,
                              onTap: () {
                                setState(() {
                                  _isHealthcareStoreExpanded =
                                      !_isHealthcareStoreExpanded;
                                });
                              },
                            ),
                          ],
                        ),
                        AnimatedCrossFade(
                          firstChild: Padding(
                            padding:
                                EdgeInsets.only(bottom: healthDp(context, 8)),
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
                  ],
                ),
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
              _SectionRow(
                title: '건강 콘텐츠',
                titleStyle: _mainMenuTitleStyle(context),
                titlePadding: EdgeInsets.only(top: healthDp(context, 10)),
                onTap: () => _popAndPushNamed(context, '/content'),
              ),
              SizedBox(height: healthDp(context, 20)),
              Divider(
                height: healthDp(context, 1),
                thickness: healthDp(context, 1),
                color: _divider,
              ),
              SizedBox(height: healthDp(context, 20)),
              Text(
                '최근 본 상품',
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
            ],
          ),
          SizedBox(height: healthDp(context, 6)),
          Row(
            children: [
              SizedBox(
                width: healthDp(context, 80),
                height: healthDp(context, 32),
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
                      healthDp(context, 80),
                      healthDp(context, 32),
                    ),
                    fixedSize: Size(
                      healthDp(context, 80),
                      healthDp(context, 32),
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(healthDp(context, 8)),
                    ),
                  ),
                  child: Text(
                    '로그인',
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: healthSp(context, 13),
                      fontWeight: FontWeight.w500,
                      height: 1.2,
                    ),
                  ),
                ),
              ),
              SizedBox(width: healthDp(context, 10)),
              SizedBox(
                width: healthDp(context, 80),
                height: healthDp(context, 32),
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
                      healthDp(context, 80),
                      healthDp(context, 32),
                    ),
                    fixedSize: Size(
                      healthDp(context, 80),
                      healthDp(context, 32),
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(healthDp(context, 8)),
                    ),
                  ),
                  child: Text(
                    '회원가입',
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: healthSp(context, 13),
                      fontWeight: FontWeight.w500,
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
          ],
        ),
        if (_user?.isAdmin == true) ...[
          SizedBox(height: healthDp(context, 10)),
          Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: healthDp(context, 80),
              height: healthDp(context, 32),
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _openAdminPage();
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
                    healthDp(context, 80),
                    healthDp(context, 32),
                  ),
                  fixedSize: Size(
                    healthDp(context, 80),
                    healthDp(context, 32),
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(healthDp(context, 8)),
                  ),
                ),
                child: Text(
                  '관리자',
                  style: TextStyle(
                    fontFamily: _fontFamily,
                    fontSize: healthSp(context, 13),
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
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
  final String iconAsset;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onCartPrescriptionTap;
  final VoidCallback? onCartShoppingTap;

  const _DrawerShortcutData({
    required this.iconAsset,
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
  static const double _tileSize = 46.15;
  static const double _labelGap = 7.69;
  static const double _tileGap = 15.38;
  static const double _rowStackGap = 23.08;

  final String iconAsset;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onCartPrescriptionTap;
  final VoidCallback? onCartShoppingTap;

  const _DrawerShortcut({
    required this.iconAsset,
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

  /// 비대면 구매 이력 있으면 드롭다운 숨기고 통합 장바구니로 직행
  bool _useIntegratedCart = false;
  final GlobalKey _cartAnchorKey = GlobalKey();
  OverlayEntry? _cartDropdownEntry;

  bool get _highlight => _hover || _pressed;
  bool get _isCartShortcut =>
      widget.label == '장바구니' &&
      widget.onCartPrescriptionTap != null &&
      widget.onCartShoppingTap != null;
  bool get _showCartDropdownButton => _isCartShortcut && !_useIntegratedCart;

  double get _shortcutIconSize {
    if (_isCartShortcut) return 20;
    if (widget.label == '쿠폰' || widget.label == '포인트') return 13;
    if (widget.label == '문진표' || widget.label == '주문배송') return 18;
    return 16;
  }

  @override
  void initState() {
    super.initState();
    if (_isCartShortcut) {
      _loadIntegratedCartFlag();
    }
  }

  Future<void> _loadIntegratedCartFlag() async {
    final useIntegrated =
        await PrescriptionPurchaseHistoryService.shouldUseIntegratedCart();
    if (!mounted) return;
    setState(() {
      _useIntegratedCart = useIntegrated;
    });
  }

  void _toggleCartDropdown() {
    if (_showCartDropdown) {
      _closeCartDropdown();
    } else {
      _openCartDropdown();
    }
  }

  void _onShortcutTap() {
    if (_isCartShortcut) {
      _onCartShortcutPressed();
      return;
    }
    widget.onTap();
  }

  Future<void> _onCartShortcutPressed() async {
    final navigator = Navigator.of(context);
    final useIntegrated =
        await PrescriptionPurchaseHistoryService.shouldUseIntegratedCart();
    if (!mounted) return;
    if (useIntegrated != _useIntegratedCart) {
      setState(() => _useIntegratedCart = useIntegrated);
    }
    if (useIntegrated) {
      navigator.pop();
      navigator.push(
        MaterialPageRoute<void>(
          builder: (_) => const CartIntegrationScreen(),
        ),
      );
      return;
    }
    _openCartDropdown();
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
    double top =
        anchorTopLeft.dy + anchorBox.size.height + healthDp(context, 6);
    if (overlayBox != null) {
      final edge = healthDp(context, 8);
      left = left.clamp(edge, overlayBox.size.width - menuW - edge);
      final menuH = healthDp(context, 120);
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
      fontSize: healthSp(context, 12),
      fontFamily: _DrawerShortcut._fontFamily,
      fontWeight: _highlight ? FontWeight.w700 : FontWeight.w500,
      height: 1.2,
    );

    final tileSize = healthDp(context, _DrawerShortcut._tileSize);
    final labelH = healthSp(context, 12) * 1.2;

    return SizedBox(
      width: tileSize,
      child: Material(
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  key: _cartAnchorKey,
                  width: tileSize,
                  height: tileSize,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: tileSize,
                        height: tileSize,
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
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          widget.iconAsset,
                          width: healthDp(context, _shortcutIconSize),
                          height: healthDp(context, _shortcutIconSize),
                          fit: BoxFit.contain,
                          colorFilter: ColorFilter.mode(
                            color,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                      if (_showCartDropdownButton)
                        Positioned(
                          right: -healthDp(context, 2),
                          bottom: -healthDp(context, 4),
                          child: GestureDetector(
                            onTap: _toggleCartDropdown,
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              width: healthDp(context, 16),
                              height: healthDp(context, 16),
                              alignment: Alignment.center,
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
                                size: healthDp(context, 11),
                                color: const Color(0xFFFF5A8D),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: healthDp(context, _DrawerShortcut._labelGap)),
                SizedBox(
                  width: tileSize,
                  height: labelH,
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    maxWidth: healthDp(context, 72),
                    child: Text(
                      widget.label,
                      style: labelStyle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.visible,
                    ),
                  ),
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

enum _MenuChevronDirection { right, down, up }

/// 메뉴 우측 화살표 — 오른쪽/아래/위가 같은 시작선·같은 크기
class _MenuChevron extends StatelessWidget {
  final _MenuChevronDirection direction;
  final VoidCallback? onTap;

  const _MenuChevron({
    required this.direction,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final size = healthDp(context, 20);
    Widget icon = Icon(
      direction == _MenuChevronDirection.up
          ? Icons.keyboard_arrow_up
          : Icons.keyboard_arrow_down,
      size: size,
      color: const Color(0xFF1A1A1E),
    );
    if (direction == _MenuChevronDirection.right) {
      icon = Transform.rotate(angle: -1.5708, child: icon);
    }

    final box = SizedBox(
      width: size,
      height: size,
      child: Center(child: icon),
    );

    if (onTap == null) return box;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: box,
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
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
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
            const _MenuChevron(direction: _MenuChevronDirection.right),
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
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
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
  final void Function(Map<String, dynamic> item) onTapProduct;

  const _RecentProductsGrid({
    required this.items,
    required this.isLoading,
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

    if (items.isEmpty) {
      return _buildEmptyMessage(context, '최근에 본 상품이 없습니다.');
    }

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
              for (var colIndex = 0;
                  colIndex < rows[rowIndex].length;
                  colIndex++) ...[
                if (colIndex > 0) SizedBox(width: healthDp(context, 10)),
                Expanded(
                  child: RecentProductCard(
                    item: rows[rowIndex][colIndex],
                    onTap: () => onTapProduct(rows[rowIndex][colIndex]),
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
    return Padding(
      padding: EdgeInsets.only(
        top: healthDp(context, 30),
        bottom: healthDp(context, 20),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: const Color(0xFF898686),
          fontSize: healthSp(context, 12),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }
}
