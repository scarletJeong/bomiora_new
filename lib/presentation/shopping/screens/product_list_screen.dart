import 'package:flutter/material.dart';
import '../../../data/repositories/product/product_category_catalog.dart';
import '../../../data/repositories/product/product_repository.dart';
import '../../../data/models/product/product_model.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/app_bar_menu.dart';
import '../../common/widgets/appbar_menutap.dart';
import '../../common/widgets/app_footer.dart';
import '../../common/widgets/navi_bar.dart';
import '../../common/widgets/product_card.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../utils/get_product.dart';
import '../widgets/product_banner_slider.dart';

class ProductListScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;
  final String? productKind;

  const ProductListScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
    this.productKind,
  });

  // arguments에서 생성하는 팩토리 생성자
  factory ProductListScreen.fromArguments(Map<String, dynamic> arguments) {
    return ProductListScreen(
      categoryId: arguments['categoryId'] ?? '',
      categoryName: arguments['categoryName'] ?? '',
      productKind: arguments['productKind'],
    );
  }

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  List<Product> _products = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _tabScrollController = ScrollController();
  late List<GlobalKey> _tabKeys;

  late String _activeCategoryId;

  List<_CategoryTab> _baseTabOrder = [];
  bool _tabsReady = false;
  int _tabsRequestToken = 0;

  static const String _gmarket = 'Gmarket Sans TTF';
  static const Color _tabPink = Color(0xFFFF5B8C);
  static const Color _tabMuted = Color(0xFF898686);

  double _pageHPad(BuildContext context) => healthDp(context, 27);

  @override
  void initState() {
    super.initState();

    _activeCategoryId = widget.categoryId;

    _initTabsAndLoad();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _initTabsAndLoad() async {
    final requestToken = ++_tabsRequestToken;
    final List<ProductCategoryItem> source;
    if (widget.productKind == 'general') {
      source = await ProductCategoryCatalog.generalCategories();
    } else {
      source = await ProductCategoryCatalog.prescriptionCategories();
    }

    if (!mounted || requestToken != _tabsRequestToken) return;

    _baseTabOrder = source
        .map((item) => _CategoryTab(id: item.categoryId, label: item.label))
        .toList();
    _tabKeys = List.generate(_baseTabOrder.length, (_) => GlobalKey());

    setState(() => _tabsReady = true);

    await _loadProducts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabScrollController.dispose();
    super.dispose();
  }

  void _scrollActiveTabIntoView({bool animate = true}) {
    if (!_tabsReady || _baseTabOrder.isEmpty) return;

    final index =
        _baseTabOrder.indexWhere((tab) => tab.id == _activeCategoryId);
    if (index < 0) return;

    final tabContext = _tabKeys[index].currentContext;
    if (tabContext == null) return;

    Scrollable.ensureVisible(
      tabContext,
      alignment: 0.5,
      duration: animate ? const Duration(milliseconds: 280) : Duration.zero,
      curve: Curves.easeInOut,
    );
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadMoreProducts();
      }
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final products = await ProductRepository.getProductsByCategory(
        categoryId: _activeCategoryId,
        productKind: widget.productKind,
        page: 1,
        pageSize: _pageSize,
      );

      setState(() {
        _products = products;
        _isLoading = false;
        _hasMore = products.length >= _pageSize;
        _currentPage = 1;
      });
      _scheduleActiveTabScroll();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = '상품 목록을 불러오는데 실패했습니다: $e';
      });
      _scheduleActiveTabScroll();
    }
  }

  void _scheduleActiveTabScroll({bool animate = false}) {
    if (!_tabsReady || _baseTabOrder.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_tabsReady) return;
      _scrollActiveTabIntoView(animate: animate);
    });
  }

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final products = await ProductRepository.getProductsByCategory(
        categoryId: _activeCategoryId,
        productKind: widget.productKind,
        page: nextPage,
        pageSize: _pageSize,
      );

      setState(() {
        if (products.isNotEmpty) {
          _products.addAll(products);
          _currentPage = nextPage;
          _hasMore = products.length >= _pageSize;
        } else {
          _hasMore = false;
        }
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
        _hasMore = false;
      });
      print('더 많은 상품 로드 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      scaffoldKey: _scaffoldKey,
      appBar: AppBarMenu(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      drawer: AppBarMenuTapDrawer(
        onHealthDashboardTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/health');
        },
      ),
      bottomNavigationBar: const FooterBar(),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (!_tabsReady || (_isLoading && _products.isEmpty)) {
      return Center(
        child: SizedBox(
          width: healthDp(context, 36),
          height: healthDp(context, 36),
          child: const CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    if (_hasError && _products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: healthDp(context, 64),
              color: Colors.grey[400],
            ),
            SizedBox(height: healthDp(context, 16)),
            Text(
              _errorMessage ?? '상품을 불러올 수 없습니다',
              style: TextStyle(
                fontSize: healthSp(context, 16),
                color: Colors.grey[600],
                fontFamily: _gmarket,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: healthDp(context, 24)),
            ElevatedButton(
              onPressed: _loadProducts,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          const SliverToBoxAdapter(
            child: ProductBannerSlider(),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: healthDp(context, 20)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: _pageHPad(context)),
              child: _buildCategoryTabs(),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              _pageHPad(context),
              healthDp(context, 10),
              _pageHPad(context),
              healthDp(context, 48),
            ),
            sliver: _products.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: healthDp(context, 56)),
                      child: Column(
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: healthDp(context, 64),
                            color: Colors.grey[400],
                          ),
                          SizedBox(height: healthDp(context, 16)),
                          Text(
                            '등록된 상품이 없습니다',
                            style: TextStyle(
                              fontSize: healthSp(context, 16),
                              color: Colors.grey[600],
                              fontFamily: _gmarket,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisExtent:
                          ProductCatalogCard.preferredMainAxisExtent(context),
                      crossAxisSpacing: healthDp(context, 9),
                      mainAxisSpacing: healthDp(context, 20),
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == _products.length) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.all(healthDp(context, 16)),
                              child: SizedBox(
                                width: healthDp(context, 28),
                                height: healthDp(context, 28),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                          );
                        }
                        return _buildProductCard(_products[index]);
                      },
                      childCount: _products.length + (_isLoadingMore ? 1 : 0),
                    ),
                  ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: healthDp(context, 32))),
          const SliverToBoxAdapter(child: AppFooter()),
        ],
      ),
    );
  }

  String _tabDisplayLabel(String label) {
    return label
        .replaceAll(' 제품', '')
        .replaceAll(' / ', '')
        .replaceAll('/', '')
        .replaceAll('환', '')
        .trim();
  }

  Widget _buildCategoryTabs() {
    return SingleChildScrollView(
      controller: _tabScrollController,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < _baseTabOrder.length; i++) ...[
            if (i > 0)
              SizedBox(
                width: healthDp(
                  context,
                  _baseTabOrder[i - 1].id == _activeCategoryId ? 10 : 14,
                ),
              ),
            _buildCategoryTabChip(_baseTabOrder[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryTabChip(_CategoryTab tab) {
    final index = _baseTabOrder.indexOf(tab);
    final selected = tab.id == _activeCategoryId;
    final label = _tabDisplayLabel(tab.label);

    if (selected) {
      return KeyedSubtree(
        key: _tabKeys[index],
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _onSelectTab(tab),
            borderRadius: BorderRadius.circular(healthDp(context, 20)),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: healthDp(context, 10),
                vertical: healthDp(context, 4),
              ),
              decoration: ShapeDecoration(
                color: _tabPink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 20)),
                ),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: healthSp(context, 14),
                  fontFamily: _gmarket,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return KeyedSubtree(
      key: _tabKeys[index],
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onSelectTab(tab),
          borderRadius: BorderRadius.circular(healthDp(context, 20)),
          child: Padding(
            padding: EdgeInsets.only(bottom: healthDp(context, 3)),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _tabMuted,
                fontSize: healthSp(context, 12),
                fontFamily: _gmarket,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onSelectTab(_CategoryTab tab) async {
    if (_activeCategoryId == tab.id) return;

    setState(() {
      _activeCategoryId = tab.id;

      _products = [];
      _currentPage = 1;
      _hasMore = true;
      _isLoadingMore = false;
      _hasError = false;
      _errorMessage = null;
      _isLoading = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });

    await _loadProducts();
  }

  Widget _buildProductCard(Product product) {
    return ProductCatalogCard(
      product: product,
      onTap: () {
        final detailRoute = widget.productKind == 'general'
            ? '/product-general/${product.id}'
            : '/product/${product.id}';
        Navigator.pushNamed(context, detailRoute);
      },
    );
  }

  void _showImageInfo(Product product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('이미지 정보'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '제품 ID (it_id):',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SelectableText(
                product.id,
                style: TextStyle(fontSize: healthSp(context, 14)),
              ),
              const SizedBox(height: 16),
              const Text(
                '이미지 URL:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              SelectableText(
                product.imageUrl ?? '(없음)',
                style: TextStyle(
                  fontSize: 12,
                  color:
                      product.imageUrl != null ? Colors.black87 : Colors.grey,
                ),
              ),
              if (product.imageUrl != null) ...[
                const SizedBox(height: 16),
                const Text(
                  '제품명:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SelectableText(
                  product.name,
                  style: TextStyle(fontSize: healthSp(context, 14)),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('닫기'),
          ),
          if (product.imageUrl != null)
            TextButton(
              onPressed: () {

                Navigator.of(context).pop();
              },
              child: const Text('콘솔 출력'),
            ),
        ],
      ),
    );
  }
}

class _CategoryTab {
  final String id;
  final String label;

  const _CategoryTab({
    required this.id,
    required this.label,
  });
}
