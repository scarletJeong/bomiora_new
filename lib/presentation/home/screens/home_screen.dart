import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../../data/models/home/banner_model.dart';
import '../../../data/models/product/product_model.dart';
import '../../../data/repositories/product/product_category_catalog.dart';
import '../../../data/repositories/product/product_repository.dart';
import '../../../data/services/banner_service.dart';
import '../../common/widgets/app_footer.dart';
import '../../common/widgets/appbar_menutap.dart';
import '../../common/widgets/navi_bar.dart';
import '../../common/widgets/product_card_with_subscription.dart';
import '../../common/widgets/product_main_card.dart';
import '../../common/widgets/web_dragscroll.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../../shopping/utils/get_product.dart'
    show
        ProductCategoryItem,
        productGeneralCategoryChipLabel,
        productPrescriptionCategoryMenuLabel;
import '../../user/myPage/screens/my_page_screen.dart';
import '../widgets/banner_slider.dart';
import '../widgets/event_section.dart';
import '../widgets/guidebook_section.dart';
import '../widgets/home_section_widgets.dart';
import '../widgets/notice_section.dart';
import '../widgets/review_section.dart';

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
  static const int _kNewLimit = 4;
  static const int _kMdPickLimit = 4;
  static const int _kCategoryMaxDisplay = 4;
  static const List<({String id, String label, String kind})> _kPinnedTabs = [
    (id: '10', label: '다이어트', kind: 'prescription'),
    (id: '20', label: '디톡스', kind: 'prescription'),
    (id: 'a0', label: '다이어트쉐이크', kind: 'general'),
    (id: '50', label: '건강면역', kind: 'prescription'),
    (id: '80', label: '심신안정', kind: 'prescription'),
  ];

  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late final Future<List<BannerModel>> _bannersFuture;
  late final Future<List<Product>> _newProductsFuture;
  bool _loadBelowFold = false;

  bool _bannerReady = false;
  bool _productsReady = false;
  bool _aboveFoldNotified = false;

  List<Product> _newProducts = const [];
  bool _newLoading = true;
  bool _imagesSettledNotified = false;
  int _pendingImages = 0;
  int _settledImages = 0;

  List<Product> _mdPickProducts = const [];
  bool _mdPickLoading = true;

  List<ProductCategoryItem> _tabs = const [];
  int _selectedTabIndex = 0;
  int _tabsRequestToken = 0;
  bool _tabsLoading = true;
  String? _tabsError;
  final Map<String, List<Product>> _productsByCategory = {};
  bool _categoryLoading = false;
  String? _categoryError;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _bannersFuture =
        widget.bannersFuture ?? BannerService.fetchMobileBanners();
    _newProductsFuture =
        widget.newProductsFuture ??
            ProductRepository.getNewProducts(limit: _kNewLimit);
    _loadNewProducts();
    _scheduleBelowFoldLoad();
  }

  Future<void> _loadNewProducts() async {
    try {
      final products = await _newProductsFuture;
      if (!mounted) return;
      final withImage = products
          .where((p) => p.displayImageUrl.trim().isNotEmpty)
          .toList();
      setState(() {
        _newProducts = products;
        _newLoading = false;
        _pendingImages = products.length >= 2 ? withImage.length : 0;
        _settledImages = 0;
      });
      if (_pendingImages == 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _notifyImagesSettled();
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _newProducts = const [];
        _newLoading = false;
        _pendingImages = 0;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _notifyImagesSettled();
      });
    }
  }

  void _notifyImagesSettled() {
    if (_imagesSettledNotified) return;
    _imagesSettledNotified = true;
    _markProductsReady();
  }

  void _onOneImageSettled() {
    _settledImages += 1;
    if (_settledImages >= _pendingImages) {
      _notifyImagesSettled();
    }
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
    await Future.any<void>([
      Future.wait<void>([_bannersFuture, _newProductsFuture]).then((_) {}),
      Future<void>.delayed(const Duration(milliseconds: 400)),
    ]);
    if (!mounted) return;
    setState(() => _loadBelowFold = true);
    _loadMdPick();
    _refreshCategoryTabs();
  }

  Future<void> _loadMdPick() async {
    try {
      final products = await ProductRepository.getMdPickProducts(
        limit: _kMdPickLimit,
        productKind: 'general',
      );
      if (!mounted) return;
      setState(() {
        _mdPickProducts = products;
        _mdPickLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _mdPickProducts = const [];
        _mdPickLoading = false;
      });
    }
  }

  Future<void> _refreshCategoryTabs() async {
    final requestToken = ++_tabsRequestToken;
    setState(() {
      _tabsLoading = true;
      _tabsError = null;
    });

    try {
      final results = await Future.wait([
        ProductCategoryCatalog.prescriptionCategories(),
        ProductCategoryCatalog.generalCategories(),
      ]);
      if (!mounted || requestToken != _tabsRequestToken) return;

      final tabs = _buildHomeTabs(
        prescription: results[0],
        general: results[1],
      );

      setState(() {
        _tabsLoading = false;
        if (tabs.isEmpty) {
          _tabs = const [];
          _tabsError = '카테고리를 불러오지 못했습니다.';
        } else {
          _tabs = tabs;
          _selectedTabIndex = _selectedTabIndex.clamp(0, tabs.length - 1);
          _tabsError = null;
        }
      });

      if (tabs.isNotEmpty) {
        _loadProductsForCurrentTab();
      }
    } catch (_) {
      if (!mounted || requestToken != _tabsRequestToken) return;
      setState(() {
        _tabsLoading = false;
        _tabs = const [];
        _tabsError = '카테고리를 불러오지 못했습니다.';
      });
    }
  }

  List<ProductCategoryItem> _buildHomeTabs({
    required List<ProductCategoryItem> prescription,
    required List<ProductCategoryItem> general,
  }) {
    final rxById = <String, ProductCategoryItem>{
      for (final t in prescription) t.categoryId.trim().toLowerCase(): t,
    };
    final gnById = <String, ProductCategoryItem>{
      for (final t in general) t.categoryId.trim().toLowerCase(): t,
    };

    final out = <ProductCategoryItem>[];
    final usedGeneralIds = <String>{};

    for (final pinned in _kPinnedTabs) {
      final id = pinned.id.toLowerCase();
      if (pinned.kind == 'prescription') {
        final src = rxById[id];
        out.add(
          ProductCategoryItem(
            label: _chipLabel(
              src?.label ?? pinned.label,
              productKind: 'prescription',
            ),
            categoryId: pinned.id,
            productKind: 'prescription',
          ),
        );
      } else {
        final src = gnById[id];
        out.add(
          ProductCategoryItem(
            label: src?.label.trim().isNotEmpty == true
                ? productGeneralCategoryChipLabel(src!.label)
                : pinned.label,
            categoryId: pinned.id,
            productKind: 'general',
          ),
        );
        usedGeneralIds.add(id);
      }
    }

    for (final g in general) {
      final id = g.categoryId.trim().toLowerCase();
      if (id.isEmpty || id == 'a0' || usedGeneralIds.contains(id)) continue;
      out.add(
        ProductCategoryItem(
          label: productGeneralCategoryChipLabel(g.label),
          categoryId: g.categoryId,
          productKind: 'general',
        ),
      );
    }

    return out;
  }

  String _chipLabel(String raw, {required String productKind}) {
    final t = raw.trim();
    if (t.isEmpty) return t;
    if (productKind == 'prescription') {
      return productPrescriptionCategoryMenuLabel(t);
    }
    return productGeneralCategoryChipLabel(t);
  }

  String _cacheKeyForTab(ProductCategoryItem tab) =>
      '${tab.productKind}:${tab.categoryId}';

  void _selectTab(int index) {
    if (index < 0 || index >= _tabs.length || index == _selectedTabIndex) {
      return;
    }
    setState(() => _selectedTabIndex = index);
    _loadProductsForCurrentTab();
  }

  Future<void> _loadProductsForCurrentTab() async {
    if (_tabs.isEmpty) return;

    final tab = _tabs[_selectedTabIndex];
    final cacheKey = _cacheKeyForTab(tab);
    if (_productsByCategory.containsKey(cacheKey)) return;

    setState(() {
      _categoryLoading = true;
      _categoryError = null;
    });

    try {
      final products = await ProductRepository.getProductsByCategory(
        categoryId: tab.categoryId,
        productKind: tab.productKind,
        page: 1,
        pageSize: _kCategoryMaxDisplay,
      );
      if (!mounted) return;
      setState(() {
        _productsByCategory[cacheKey] = products;
        _categoryLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _categoryLoading = false;
        _categoryError = '상품을 불러오지 못했습니다.';
      });
    }
  }

  void _openProduct(Product product, {String? fallbackKind}) {
    final kind = (product.productKind ?? fallbackKind ?? 'general')
        .trim()
        .toLowerCase();
    final route = kind == 'prescription'
        ? '/product/${product.id}'
        : '/product-general/${product.id}';
    Navigator.pushNamed(context, route);
  }

  void _openCategoryProductList() {
    if (_tabs.isEmpty) return;
    final tab = _tabs[_selectedTabIndex];
    final isGeneral = tab.productKind == 'general';
    Navigator.pushNamed(
      context,
      isGeneral ? '/product-general/' : '/product/',
      arguments: <String, dynamic>{
        'categoryId': tab.categoryId,
        'categoryName': tab.label,
        'productKind': tab.productKind,
      },
    );
  }

  @override
  void dispose() {
    _tabsRequestToken++;
    super.dispose();
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
        return const MyPageScreen();
      default:
        return _buildHomePage();
    }
  }

  Widget _buildHomePage() {
    final sectionGap = healthDp(context, 48);

    return SingleChildScrollView(
      child: Column(
        children: [
          BannerSlider(
            bannersFuture: _bannersFuture,
            onPrimaryImageSettled: _markBannerReady,
          ),
          SizedBox(height: sectionGap),
          _buildNewProductBlock(),
          SizedBox(height: sectionGap),
          if (_loadBelowFold) ...[
            _buildCategoryBlock(),
            SizedBox(height: sectionGap),
            _buildMdPickBlock(),
            SizedBox(height: sectionGap),
            const GuidebookSection(),
            SizedBox(height: sectionGap),
            const ReviewSection(),
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

  Widget _buildNewProductBlock() {
    if (!_newLoading && _newProducts.length < 2) {
      return const SizedBox.shrink();
    }

    final hPad = healthDp(context, 20);
    final cardW = ProductMainCard.preferredCardWidth(context);
    final cardH = ProductMainCard.preferredMainAxisExtent(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: const HomeSectionTitleRow(
            line1: 'New',
            line2: 'Product',
          ),
        ),
        SizedBox(height: healthDp(context, 20)),
        _horizontalProductRow(
          height: cardH,
          loading: _newLoading,
          itemCount: _newProducts.length,
          itemBuilder: (_, index) {
            final product = _newProducts[index];
            return SizedBox(
              width: cardW,
              height: cardH,
              child: ProductMainCard(
                product: product,
                onTap: () => _openProduct(product, fallbackKind: 'general'),
                onImageSettled: product.displayImageUrl.trim().isEmpty
                    ? null
                    : _onOneImageSettled,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildMdPickBlock() {
    if (_mdPickLoading || _mdPickProducts.length < 4) {
      return const SizedBox.shrink();
    }

    final hPad = healthDp(context, 20);
    final cardW = ProductCardWithSubscription.preferredCardWidth(context);
    final cardH =
        ProductCardWithSubscription.preferredMainAxisExtent(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: const HomeSectionTitleRow(
            line1: "",
            line2: 'MD\'s Pick',
            singleLine: true,
          ),
        ),
        SizedBox(height: healthDp(context, 20)),
        _horizontalProductRow(
          height: cardH,
          itemCount: _mdPickProducts.length,
          itemBuilder: (_, index) {
            final product = _mdPickProducts[index];
            return SizedBox(
              width: cardW,
              height: cardH,
              child: ProductCardWithSubscription(
                product: product,
                onTap: () => _openProduct(product),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildCategoryBlock() {
    if (_tabsLoading) {
      return SizedBox(
        height: healthDp(context, 280),
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    if (_tabsError != null || _tabs.isEmpty) {
      return const SizedBox.shrink();
    }

    final hPad = healthDp(context, 20);
    final selected = _tabs[_selectedTabIndex];
    final cacheKey = _cacheKeyForTab(selected);
    final products = _productsByCategory[cacheKey] ?? const <Product>[];
    final displayProducts = products.take(_kCategoryMaxDisplay).toList();
    final showMoreOnLast = products.length >= _kCategoryMaxDisplay;
    final cardW = ProductCardWithSubscription.preferredCardWidth(context);
    final cardH =
        ProductCardWithSubscription.preferredMainAxisExtent(context);
    final tabFs = healthSp(context, 12);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: const HomeSectionTitleRow(
            line1: '건강을',
            line2: '채우는 시간',
          ),
        ),
        SizedBox(height: healthDp(context, 20)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: WebDragScrollConfiguration(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < _tabs.length; i++) ...[
                    if (i > 0) ...[
                      SizedBox(width: healthDp(context, 4)),
                      Text(
                        '|',
                        style: TextStyle(
                          color: const Color(0xFFC9C9C9),
                          fontSize: tabFs * 0.62,
                          height: 1.0,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      SizedBox(width: healthDp(context, 4)),
                    ],
                    _CategoryTabChip(
                      label: _tabs[i].label,
                      selected: _selectedTabIndex == i,
                      fontSize: tabFs,
                      onTap: () => _selectTab(i),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        SizedBox(height: healthDp(context, 20)),
        _buildCategoryCarousel(
          products: products,
          displayProducts: displayProducts,
          showMoreOnLast: showMoreOnLast,
          cardW: cardW,
          cardH: cardH,
        ),
      ],
    );
  }

  Widget _buildCategoryCarousel({
    required List<Product> products,
    required List<Product> displayProducts,
    required bool showMoreOnLast,
    required double cardW,
    required double cardH,
  }) {
    if (_categoryLoading && products.isEmpty) {
      return Center(
        child: SizedBox(
          width: healthDp(context, 20),
          height: healthDp(context, 20),
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    if (_categoryError != null && products.isEmpty) {
      return Center(
        child: Text(
          _categoryError!,
          style: TextStyle(
            color: const Color(0x665B3F43),
            fontSize: healthSp(context, 12),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w400,
          ),
        ),
      );
    }
    if (products.isEmpty) {
      final iconSz = healthDp(context, 40);
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              AppAssets.emptyCategoryIcon,
              width: iconSz,
              height: iconSz,
              fit: BoxFit.contain,
            ),
            SizedBox(height: healthDp(context, 8)),
            Text(
              '등록된 상품이 없습니다.',
              style: TextStyle(
                color: const Color(0x665B3F43),
                fontSize: healthSp(context, 12),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      );
    }

    return _horizontalProductRow(
      height: cardH,
      itemCount: displayProducts.length,
      itemBuilder: (_, index) {
        final product = displayProducts[index];
        final showMore =
            index == displayProducts.length - 1 && showMoreOnLast;
        return SizedBox(
          width: cardW,
          height: cardH,
          child: ProductCardWithSubscription(
            product: product,
            showMoreOverlay: showMore,
            onTap: showMore
                ? _openCategoryProductList
                : () => _openProduct(
                      product,
                      fallbackKind: _tabs[_selectedTabIndex].productKind,
                    ),
          ),
        );
      },
    );
  }

  Widget _horizontalProductRow({
    required double height,
    required int itemCount,
    required NullableIndexedWidgetBuilder itemBuilder,
    bool loading = false,
    bool padded = true,
  }) {
    final hPad = healthDp(context, 20);
    final gap = healthDp(context, 12);

    if (loading) {
      return SizedBox(
        height: height,
        child: Center(
          child: SizedBox(
            width: healthDp(context, 20),
            height: healthDp(context, 20),
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return SizedBox(
      height: height,
      child: WebDragScrollConfiguration(
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: padded
              ? EdgeInsets.symmetric(horizontal: hPad)
              : EdgeInsets.zero,
          itemCount: itemCount,
          separatorBuilder: (_, __) => SizedBox(width: gap),
          itemBuilder: itemBuilder,
        ),
      ),
    );
  }
}

class _CategoryTabChip extends StatelessWidget {
  const _CategoryTabChip({
    required this.label,
    required this.selected,
    required this.fontSize,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double fontSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(healthDp(context, 4)),
      child: Container(
        padding: EdgeInsets.only(bottom: healthDp(context, 1)),
        decoration: BoxDecoration(
          border: selected
              ? const Border(
                  bottom: BorderSide(
                    width: 1,
                    color: Color(0xFFFF5A8D),
                  ),
                )
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? const Color(0xFFFF5A8D)
                : const Color(0xFF383838),
            fontSize: fontSize,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
            height: 1.08,
          ),
        ),
      ),
    );
  }
}
