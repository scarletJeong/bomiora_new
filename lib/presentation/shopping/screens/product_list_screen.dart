import 'package:flutter/material.dart';
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
import '../widgets/product_main/product_main_category_tap.dart';

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
  List<Product> _products = [];
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  int _currentPage = 1;
  final int _pageSize = 20;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  final ScrollController _scrollController = ScrollController();

  late String _activeCategoryId;
  late String _activeCategoryName;

  late List<_CategoryTab> _tabs;
  late List<_CategoryTab> _baseTabOrder;

  static const String _gmarket = 'Gmarket Sans TTF';

  @override
  void initState() {
    super.initState();

    _activeCategoryId = widget.categoryId;
    _activeCategoryName = widget.categoryName;

    if (widget.productKind == 'general') {
      _baseTabOrder = productGeneralCategoryList
          .map((item) => _CategoryTab(id: item.categoryId, label: item.label))
          .toList();
    } else {
      _baseTabOrder = productPrescriptionCategoryList
          .map((item) => _CategoryTab(id: item.categoryId, label: item.label))
          .toList();
    }

    _tabs = _buildInitialTabs();

    _loadProducts();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = '상품 목록을 불러오는데 실패했습니다: $e';
      });
    }
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
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Builder(
            builder: (ctx) => AppBarMenu(
              onMenuPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
        ),
        drawer: AppBarMenuTapDrawer(
          onHealthDashboardTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/health');
          },
        ),
        bottomNavigationBar: const FooterBar(),
        body: DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _products.isEmpty) {
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
            child: SizedBox(height: healthDp(context, 10)),
          ),
          SliverToBoxAdapter(
            child: ProductMainCategoryTap(
              productKind: widget.productKind ?? 'prescription',
              compact: true,
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: healthDp(context, 10)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                healthDp(context, 18),
                healthDp(context, 8),
                healthDp(context, 18),
                healthDp(context, 6),
              ),
              child: _buildScreenTitle(),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              healthDp(context, 18),
              healthDp(context, 8),
              healthDp(context, 18),
              healthDp(context, 20),
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
                      // Figma 카드(이미지+다줄 텍스트) 비율 — 세로 여유 확보
                      childAspectRatio: 0.58,
                      crossAxisSpacing: healthDp(context, 12),
                      mainAxisSpacing: healthDp(context, 16),
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

  Widget _buildCategoryTabs() {
    final selected = _tabs.isNotEmpty ? _tabs.first : null;
    final others = _tabs.length > 1 ? _tabs.sublist(1) : const <_CategoryTab>[];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (selected != null)
          InkWell(
            onTap: () => _onSelectTab(selected),
            child: AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              style: TextStyle(
                fontSize: healthSp(context, 22),
                fontWeight: FontWeight.w800,
                color: Colors.black,
                fontFamily: _gmarket,
              ),
              child: Text(selected.label),
            ),
          ),
        const SizedBox(width: 14),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: others.map((tab) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: InkWell(
                    onTap: () => _onSelectTab(tab),
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      style: TextStyle(
                        fontSize: healthSp(context, 14),
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[500],
                        fontFamily: _gmarket,
                      ),
                      child: Text(tab.label),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScreenTitle() {
    return Padding(
      padding: EdgeInsets.only(left: healthDp(context, 6)),
      child: Text(
        '| $_activeCategoryName',
        style: TextStyle(
          fontSize: healthSp(context, 19.29),
          fontWeight: FontWeight.w700,
          color: Colors.black,
          fontFamily: _gmarket,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Future<void> _onSelectTab(_CategoryTab tab) async {
    if (_tabs.isNotEmpty && _tabs.first.id == tab.id) return;

    setState(() {
      _tabs = _buildTabsForSelectedId(tab.id);

      _activeCategoryId = tab.id;
      _activeCategoryName = tab.label;

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

  List<_CategoryTab> _buildInitialTabs() {
    final initialId = _activeCategoryId;
    final existsInBase = _baseTabOrder.any((t) => t.id == initialId);
    if (!existsInBase) {
      return [
        _CategoryTab(id: initialId, label: _activeCategoryName),
        ..._baseTabOrder,
      ];
    }

    return _buildTabsForSelectedId(initialId);
  }

  List<_CategoryTab> _buildTabsForSelectedId(String selectedId) {
    final selected = _baseTabOrder.firstWhere(
      (t) => t.id == selectedId,
      orElse: () => _CategoryTab(id: selectedId, label: _activeCategoryName),
    );

    final rest = _baseTabOrder.where((t) => t.id != selected.id).toList();
    return [selected, ...rest];
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
