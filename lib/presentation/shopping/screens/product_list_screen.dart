import 'package:flutter/material.dart';
import '../../../data/repositories/product/product_repository.dart';
import '../../../data/models/product/product_model.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/appbar_menutap.dart';
import '../utils/get_product.dart';
import '../widgets/product_banner_slider.dart';
import '../../../core/constants/app_assets.dart';

String _productListStripHtml(String? raw) {
  if (raw == null) return '';
  var s = raw.replaceAll(RegExp(r'<[^>]*>'), ' ');
  s = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"');
  s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
  return s;
}

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

  static const Color _brandPink = Color(0xFFFF5A8D);
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
        extendBodyBehindAppBar: true,
        appBar: AppBar(
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
        drawer: AppBarMenuTapDrawer(
          onHealthDashboardTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/health');
          },
        ),
        body: DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _products.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_hasError && _products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? '상품을 불러올 수 없습니다',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontFamily: _gmarket,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
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
          const SliverToBoxAdapter(
            child: SizedBox(height: 20),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
              child: _buildCategoryTabs(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            sliver: _products.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 56),
                      child: Column(
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            '등록된 상품이 없습니다',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontFamily: _gmarket,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      // 세로 여유 (하단 텍스트 오버플로 방지)
                      childAspectRatio: 0.66,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == _products.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          );
                        }
                        return _buildProductCard(_products[index]);
                      },
                      childCount: _products.length + (_isLoadingMore ? 1 : 0),
                    ),
                  ),
          ),
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
              style: const TextStyle(
                fontSize: 22,
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
                        fontSize: 14,
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
    return LayoutBuilder(
      builder: (context, itemConstraints) {
        final screenW = MediaQuery.sizeOf(context).width;
        final tScale = (screenW / 390.0).clamp(0.88, 1.18);
        final namePlain = _productListStripHtml(product.name);
        final subjectPlain = _productListStripHtml(product.itSubject);
        final descPlain = _productListStripHtml(
          product.itBasic ?? product.description ?? '',
        );
        final nameFs = (12.5 * tScale).clamp(11.0, 15.0);
        final subjectFs = (10.0 * tScale).clamp(9.0, 12.0);
        final descFs = (10.5 * tScale).clamp(9.5, 12.5);
        final origFs = (10.5 * tScale).clamp(9.5, 12.5);
        final discFs = (11.5 * tScale).clamp(10.5, 14.0);
        final priceFs = (13.5 * tScale).clamp(12.0, 16.0);

        final imageHeight = itemConstraints.hasBoundedHeight
            ? itemConstraints.maxHeight * 2 / 3
            : 220.0;

        return GestureDetector(
          onTap: () {
            final detailRoute = widget.productKind == 'general'
                ? '/product-general/${product.id}'
                : '/product/${product.id}';
            Navigator.pushNamed(
              context,
              detailRoute,
            );
          },
          child: Card(
            elevation: 2,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: imageHeight,
                  width: double.infinity,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(12),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        product.imageUrl != null
                            ? Image.network(
                                product.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  print('❌ 이미지 로드 실패: ${product.imageUrl}');
                                  print('   에러: $error');
                                  return _buildPlaceholderImage(product);
                                },
                                loadingBuilder:
                                    (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  );
                                },
                              )
                            : _buildPlaceholderImage(product),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              if (subjectPlain.isNotEmpty) ...[
                                Text(
                                  subjectPlain,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: subjectFs,
                                    fontWeight: FontWeight.w400,
                                    fontFamily: _gmarket,
                                  ),
                                ),
                                SizedBox(height: 3 * tScale),
                              ],
                              Text(
                                namePlain,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: const Color(0xFF231F20),
                                  fontSize: nameFs,
                                  fontWeight: FontWeight.w500,
                                  fontFamily: _gmarket,
                                  height: 1.25,
                                ),
                              ),
                              if (descPlain.isNotEmpty) ...[
                                SizedBox(height: 4 * tScale),
                                Text(
                                  descPlain,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontSize: descFs,
                                    fontWeight: FontWeight.w300,
                                    fontFamily: _gmarket,
                                    height: 1.25,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (product.originalPrice != null &&
                            product.originalPrice! > product.price) ...[
                          Text(
                            product.formattedOriginalPrice ?? '',
                            style: TextStyle(
                              fontSize: origFs,
                              color: Colors.grey[600],
                              decoration: TextDecoration.lineThrough,
                              fontFamily: _gmarket,
                            ),
                          ),
                          SizedBox(height: 4 * tScale),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (product.discountRate != null)
                              Text(
                                '${product.discountRate!.toStringAsFixed(0)}%',
                                style: TextStyle(
                                  fontSize: discFs,
                                  color: _brandPink,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: _gmarket,
                                ),
                              ),
                            if (product.discountRate != null)
                              SizedBox(width: 5 * tScale),
                            Expanded(
                              child: Text(
                                product.formattedPrice,
                                style: TextStyle(
                                  fontSize: priceFs,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                  fontFamily: _gmarket,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaceholderImage(Product product) {
    return Container(
      width: double.infinity,
      color: Colors.grey[200],
      child: Icon(
        Icons.image_not_supported,
        size: 40,
        color: Colors.grey[400],
      ),
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
                style: const TextStyle(fontSize: 14),
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
                  style: const TextStyle(fontSize: 14),
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
                // 콘솔에도 출력
                print('🔍 이미지 정보:');
                print('   제품 ID: ${product.id}');
                print('   제품명: ${product.name}');
                print('   이미지 URL: ${product.imageUrl}');
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
