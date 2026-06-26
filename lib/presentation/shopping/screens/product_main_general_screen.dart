import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../../data/models/product/product_model.dart';
import '../../../data/repositories/product/product_category_catalog.dart';
import '../../../data/repositories/product/product_repository.dart';
import '../../common/widgets/app_bar_menu.dart';
import '../../common/widgets/appbar_menutap.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/app_footer.dart';
import '../../common/widgets/navi_bar.dart';
import '../../common/widgets/product_card.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../utils/get_product.dart';

/// 헬스케어 스토어 메인 중간 이미지 (카테고리 칩 아래)
const String _kMidBannerAsset = AppAssets.generalMainBanner;

const int _kMaxCategoryProducts = 4;
const int _kMdPickLimit = 4;

double _contentHorizontalPad(BuildContext context) => healthDp(context, 27);

/// 헬스케어 스토어(일반 상품) 메인 — 카테고리별 API 상품 + MD's Pick(API).
///
/// 본문 스크롤 구성은 [_buildHealthcareStoreMainSlivers] 한곳에서 순서를 본다
/// (`BomioraIntroduceScreen`의 `Column(children: [...])`와 같은 역할).
class ProductMainGeneralScreen extends StatefulWidget {
  const ProductMainGeneralScreen({super.key});

  @override
  State<ProductMainGeneralScreen> createState() => _ProductMainGeneralScreenState();
}

class _ProductMainGeneralScreenState extends State<ProductMainGeneralScreen> {
  static const String _font = 'Gmarket Sans TTF';

  final GlobalKey<ScaffoldState> _pageScaffoldKey = GlobalKey<ScaffoldState>();
  final Map<String, List<Product>> _byCategory = {};
  List<ProductCategoryItem> _categories =
      List<ProductCategoryItem>.from(productGeneralCategoryListFallback);
  List<Product> _mdPickProducts = [];
  Product? _weekDealProduct;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final categories = await ProductCategoryCatalog.generalCategories();
      final mdPick = await ProductRepository.getMdPickProducts(
        limit: _kMdPickLimit,
        productKind: 'general',
      );
      final categoryResults = await Future.wait(
        categories.map(
          (c) => ProductRepository.getProductsByCategory(
            categoryId: c.categoryId,
            productKind: 'general',
            page: 1,
            pageSize: _kMaxCategoryProducts,
          ),
        ),
      );
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _mdPickProducts = mdPick;
        _byCategory.clear();
        for (var i = 0; i < categories.length; i++) {
          _byCategory[categories[i].categoryId] = categoryResults[i];
        }
        _weekDealProduct = _resolveWeekDealProduct();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _openProductDetail(Product p) {
    Navigator.pushNamed(context, '/product-general/${p.id}');
  }

  /// 카테고리별 로드 상품 중 할인율 최대 1건 (동률·할인 없음이면 첫 상품)
  Product? _resolveWeekDealProduct() {
    final all = _byCategory.values.expand((list) => list).toList();
    if (all.isEmpty) return null;

    Product? best;
    var bestRate = -1.0;
    for (final product in all) {
      final rate = product.discountRate ?? 0;
      if (rate > bestRate) {
        bestRate = rate;
        best = product;
      }
    }
    return best ?? all.first;
  }

  String _weekDealCategoryLabel(Product product) {
    for (final cat in _categories) {
      if (cat.categoryId == product.categoryId) {
        return productGeneralCategoryChipLabel(cat.label);
      }
    }
    final name = stripProductCatalogHtml(product.categoryName);
    if (name.isNotEmpty && name != '기타') return name;
    return '헬스케어';
  }

  String? _weekDealBrandLabel(Product product) {
    final subject = stripProductCatalogHtml(product.itSubject);
    if (subject.isEmpty) return null;
    if (isBomioraHospitalProductSubject(subject)) return null;
    return subject;
  }

  void _openCategoryList(ProductCategoryItem item) {
    Navigator.pushNamed(
      context,
      '/product-general/',
      arguments: {
        'categoryId': item.categoryId,
        'categoryName': item.label,
        'productKind': item.productKind,
      },
    );
  }

  // 일반 제품 카테고리 제목 스타일 - | 제목목
  TextStyle _sectionTitleStyle(BuildContext context) => TextStyle(
        color: Colors.black,
        fontSize: healthSp(context, 16),
        fontFamily: _font,
        fontWeight: FontWeight.w700,
        letterSpacing: healthSp(context, -1.44),
      );

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: healthDp(context, 1),
          height: healthDp(context, 16),
          color: Colors.black,
        ),
        SizedBox(width: healthDp(context, 10)),
        Flexible(
          child: Text(
            title,
            style: _sectionTitleStyle(context),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final heroScale = (w / 375.0).clamp(0.85, 1.15);

    return MobileAppLayoutWrapper(
      scaffoldKey: _pageScaffoldKey,
      appBar: AppBarMenu(
        onMenuPressed: () => _pageScaffoldKey.currentState?.openDrawer(),
      ),
      drawer: AppBarMenuTapDrawer(
        onHealthDashboardTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/health');
        },
      ),
      bottomNavigationBar: const FooterBar(),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: _font),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: EdgeInsets.all(healthDp(context, 24)),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '상품을 불러오지 못했습니다.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: healthSp(context, 15),
                              color: Colors.grey[800],
                            ),
                          ),
                          SizedBox(height: healthDp(context, 16)),
                          FilledButton(
                            onPressed: _load,
                            child: const Text('다시 시도'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: _buildHealthcareStoreMainSlivers(context, heroScale),
                    ),
                  ),
      ),
    );
  }

  /// 메인 스크롤에 쌓이는 섹션 순서 (상단 → 하단).
  List<Widget> _buildHealthcareStoreMainSlivers(
    BuildContext context,
    double heroScale,
  ) {
    return [
      SliverToBoxAdapter(
        child: _HeroWithWeeklyDeal(
          heroScale: heroScale,
          weekDealProduct: _weekDealProduct,
          categoryLabel: _weekDealProduct == null
              ? null
              : _weekDealCategoryLabel(_weekDealProduct!),
          brandLabel: _weekDealProduct == null
              ? null
              : _weekDealBrandLabel(_weekDealProduct!),
          onDealTap: _weekDealProduct == null
              ? null
              : () => _openProductDetail(_weekDealProduct!),
        ),
      ),
      if (_mdPickProducts.isNotEmpty) ...[
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              _contentHorizontalPad(context),
              healthDp(context, 12),
              _contentHorizontalPad(context),
              healthDp(context, 8),
            ),
            child: _buildSectionTitle(context, "MD's Pick"),
          ),
        ),
        SliverToBoxAdapter(
          child: _MdPickSection(
            products: _mdPickProducts,
            onProductTap: _openProductDetail,
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: healthDp(context, 8))),
      ],
      SliverToBoxAdapter(
        child: _HealthcareCategoryHeader(
          categories: _categories,
          onChipTap: _openCategoryList,
        ),
      ),
      SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.only(bottom: healthDp(context, 20)),
          child: const _MidBannerImage(),
        ),
      ),
      ..._buildCategorySectionSlivers(context),
      SliverToBoxAdapter(child: SizedBox(height: healthDp(context, 32))),
      const SliverToBoxAdapter(child: AppFooter()),
    ];
  }

  List<Widget> _buildCategorySectionSlivers(BuildContext context) {
    final out = <Widget>[];
    for (var idx = 0; idx < _categories.length; idx++) {
      final cat = _categories[idx];
      final all = _byCategory[cat.categoryId] ?? const <Product>[];
      final products = all.take(_kMaxCategoryProducts).toList();
      if (idx > 0) {
        out.add(SliverToBoxAdapter(child: SizedBox(height: healthDp(context, 36))));
      }
      out.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              _contentHorizontalPad(context),
              idx == 0 ? healthDp(context, 8) : 0,
              _contentHorizontalPad(context),
              healthDp(context, 8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSectionTitle(
                    context,
                    cat.label.replaceAll(' 제품', ''),
                  ),
                ),
                _PinkMoreButton(
                  onTap: () => _openCategoryList(cat),
                ),
              ],
            ),
          ),
        ),
      );
      out.add(
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            _contentHorizontalPad(context),
            0,
            _contentHorizontalPad(context),
            healthDp(context, 8),
          ),
          sliver: products.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: healthDp(context, 24)),
                    child: Center(
                      child: Text(
                        '등록된 상품이 없습니다',
                        style: TextStyle(
                          fontSize: healthSp(context, 13),
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                )
              : SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: healthDp(context, 5),
                    crossAxisSpacing: healthDp(context, 12),
                    mainAxisExtent:
                        ProductCatalogCard.preferredMainAxisExtent(context),
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, index) {
                      final p = products[index];
                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: ProductCatalogCard(
                          product: p,
                          onTap: () => _openProductDetail(p),
                        ),
                      );
                    },
                    childCount: products.length,
                  ),
                ),
        ),
      );
    }
    return out;
  }
}

class _HeroBlock extends StatelessWidget {
  final double scale;

  const _HeroBlock({required this.scale});

  static double heightFor(double scale) => 216 * scale;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      child: SizedBox(
        height: heightFor(scale),
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFFE8E0D5)),
            Positioned(
              left: 0,
              right: 0,
              top: 60 * scale,
              child: Column(
                children: [
                  Text(
                    '당신의 일상에 건강을 더하다.',
                    style: TextStyle(
                      color: const Color(0xFF6D5F47),
                      fontSize: healthSp(context, 12),
                      fontWeight: FontWeight.w300,
                      shadows: const [
                        Shadow(
                          color: Colors.white70,
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '헬스케어 스토어',
                    style: TextStyle(
                      color: const Color(0xFF6D5F47),
                      fontSize: healthSp(context, 24),
                      fontWeight: FontWeight.w700,
                      shadows: const [
                        Shadow(
                          color: Colors.white54,
                          blurRadius: 8,
                        ),
                      ],
                    ),
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

/// 히어로 하단에 이주의 DEAL 카드가 겹쳐 보이도록 묶은 블록
class _HeroWithWeeklyDeal extends StatelessWidget {
  final double heroScale;
  final Product? weekDealProduct;
  final String? categoryLabel;
  final String? brandLabel;
  final VoidCallback? onDealTap;

  const _HeroWithWeeklyDeal({
    required this.heroScale,
    required this.weekDealProduct,
    required this.categoryLabel,
    required this.brandLabel,
    required this.onDealTap,
  });

  @override
  Widget build(BuildContext context) {
    final heroH = _HeroBlock.heightFor(heroScale);
    final product = weekDealProduct;

    if (product == null || categoryLabel == null || onDealTap == null) {
      return _HeroBlock(scale: heroScale);
    }

    final overlap = _WeeklyDealCard.heroOverlap(context);
    final extentBelow = _WeeklyDealCard.extentBelowHero(context);

    return SizedBox(
      height: heroH + extentBelow,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          _HeroBlock(scale: heroScale),
          Positioned(
            top: heroH - overlap,
            left: _contentHorizontalPad(context),
            right: _contentHorizontalPad(context),
            child: _WeeklyDealCard(
              product: product,
              categoryLabel: categoryLabel!,
              brandLabel: brandLabel,
              onTap: onDealTap!,
            ),
          ),
        ],
      ),
    );
  }
}

class _MidBannerImage extends StatelessWidget {
  const _MidBannerImage();

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 374 / 234,
      child: Image.asset(
        _kMidBannerAsset,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (_, __, ___) => Container(
          color: const Color(0xFFF0F0F0),
          alignment: Alignment.center,
          child: Icon(Icons.image_outlined, color: Colors.grey[400]),
        ),
      ),
    );
  }
}

/// 가이드북 섹션과 동일한 `+ More` pill 버튼
class _PinkMoreButton extends StatelessWidget {
  final VoidCallback onTap;

  const _PinkMoreButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9999),
        hoverColor: Colors.transparent,
        splashColor: const Color(0x33FF5A8D),
        highlightColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 8),
            vertical: healthDp(context, 2),
          ),
          decoration: ShapeDecoration(
            color: const Color(0xFFFF5A8D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9999),
            ),
          ),
          child: Text(
            '+More',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: healthSp(context, 10),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// MD's Pick 아래: 상단 여백 → 칩 행 너비에 맞춘 구분선 → 칩 → 하단 여백
class _HealthcareCategoryHeader extends StatelessWidget {
  final List<ProductCategoryItem> categories;
  final void Function(ProductCategoryItem) onChipTap;

  const _HealthcareCategoryHeader({
    required this.categories,
    required this.onChipTap,
  });

  static double chipDiameter(BuildContext context) =>
      healthDp(context, 76).clamp(64.0, 88.0);

  static double chipTrackWidth(BuildContext context, int categoryCount) {
    final d = chipDiameter(context);
    final gap = healthDp(context, 12);
    final n = categoryCount;
    if (n <= 0) return d;
    return n * d + (n - 1) * gap;
  }

  @override
  Widget build(BuildContext context) {
    final trackW = chipTrackWidth(context, categories.length);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: healthDp(context, 20)),
        Center(
          child: SizedBox(
            width: trackW,
            child: Divider(
              height: healthDp(context, 1),
              thickness: healthDp(context, 1),
              color: const Color(0xFFE8E8E8),
            ),
          ),
        ),
        SizedBox(height: healthDp(context, 20)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _contentHorizontalPad(context)),
          child: _CategoryChipsRow(
            categories: categories,
            onChipTap: onChipTap,
          ),
        ),
        SizedBox(height: healthDp(context, 20)),
      ],
    );
  }
}

class _CategoryChipsRow extends StatelessWidget {
  final List<ProductCategoryItem> categories;
  final void Function(ProductCategoryItem) onChipTap;

  const _CategoryChipsRow({
    required this.categories,
    required this.onChipTap,
  });

  @override
  Widget build(BuildContext context) {
    final diameter = _HealthcareCategoryHeader.chipDiameter(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < categories.length; i++) ...[
                  if (i > 0) SizedBox(width: healthDp(context, 12)),
                  _CategoryIconChip(
                    diameter: diameter,
                    iconAsset:
                        productGeneralCategoryIconAsset(categories[i].categoryId),
                    label: productGeneralCategoryChipLabel(categories[i].label),
                    onTap: () => onChipTap(categories[i]),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CategoryIconChip extends StatelessWidget {
  final double diameter;
  final String iconAsset;
  final String label;
  final VoidCallback onTap;

  const _CategoryIconChip({
    required this.diameter,
    required this.iconAsset,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconSize = (diameter * 0.38).clamp(22.0, 32.0);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: diameter,
          height: diameter,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: healthDp(context, 8),
                offset: Offset(0, healthDp(context, 2)),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              healthDp(context, 6),
              healthDp(context, 8),
              healthDp(context, 6),
              healthDp(context, 6),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                  child: Center(
                    child: SvgPicture.asset(
                      iconAsset,
                      width: iconSize,
                      height: iconSize,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF676767),
                    fontSize: healthSp(context, 8).clamp(8.0, 11.0),
                    fontWeight: FontWeight.w500,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 이주의 DEAL — 히어로와 MD's Pick 사이 단일 프로모 카드
class _WeeklyDealCard extends StatelessWidget {
  static const Color _brandPink = Color(0xFFFF5A8D);
  static const Color _textDark = Color(0xFF1A1A1E);
  static const Color _metaMuted = Color(0xFF898686);
  static const String _font = 'Gmarket Sans TTF';

  final Product product;
  final String categoryLabel;
  final String? brandLabel;
  final VoidCallback onTap;

  const _WeeklyDealCard({
    required this.product,
    required this.categoryLabel,
    required this.brandLabel,
    required this.onTap,
  });

  /// 히어로 위로 겹치는 카드 높이 (리본·본문 포함)
  static double totalHeight(BuildContext context) {
    final ribbonTop = healthDp(context, 6);
    final innerPad = healthDp(context, 12) * 2;
    final imageSize = healthDp(context, 96);
    final textBlock = healthDp(context, 112);
    return ribbonTop + innerPad + math.max(imageSize, textBlock);
  }

  /// 히어로 하단에 걸치는 겹침 높이
  static double heroOverlap(BuildContext context) => healthDp(context, 80);

  /// 히어로 아래로 내려오는 카드 영역 높이
  static double extentBelowHero(BuildContext context) =>
      totalHeight(context) - heroOverlap(context);

  @override
  Widget build(BuildContext context) {
    final imageSize = healthDp(context, 96);
    final title = stripProductCatalogHtml(product.name);
    final discount = (product.discountRate ?? 0).round();
    final rating = product.rating;
    final reviewCount = product.reviewCount ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.only(top: healthDp(context, 6)),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(healthDp(context, 12)),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(healthDp(context, 12)),
                border: Border.all(
                  color: const Color(0xFFE8E8E8),
                  width: healthDp(context, 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: healthDp(context, 10),
                    offset: Offset(0, healthDp(context, 3)),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(healthDp(context, 10)),
                    child: SizedBox(
                      width: imageSize,
                      height: imageSize,
                      child: ColoredBox(
                        color: const Color(0xFFF3F3F3),
                        child: product.displayImageUrl.isNotEmpty
                            ? Image.network(
                                product.displayImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.image_not_supported_outlined,
                                  color: Colors.grey[400],
                                  size: healthDp(context, 28),
                                ),
                              )
                            : Icon(
                                Icons.image_outlined,
                                color: Colors.grey[400],
                                size: healthDp(context, 28),
                              ),
                      ),
                    ),
                  ),
                  SizedBox(width: healthDp(context, 12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 카테고리 라벨
                        Text(
                          categoryLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: healthSp(context, 9),
                            fontFamily: _font,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        // 브랜드 라벨
                        if (brandLabel != null) ...[
                          SizedBox(height: healthDp(context, 4)),
                          Text(
                            brandLabel!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _metaMuted,
                              fontSize: healthSp(context, 9),
                              fontFamily: _font,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        SizedBox(height: healthDp(context, 2)),
                        // 제품 이름
                        Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _textDark,
                            fontSize: healthSp(context, 14),
                            fontFamily: _font,
                            fontWeight: FontWeight.w500,
                            letterSpacing: healthSp(context, -1.26),
                          ),
                        ),
                        SizedBox(height: healthDp(context, 8)),
                        Row(
                          children: [
                            Text(
                              '$discount%',
                              style: TextStyle(
                                color: _brandPink,
                                fontSize: healthSp(context, 12),
                                fontFamily: _font,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(width: healthDp(context, 4)),
                            Expanded(
                              child: Text(
                                product.formattedPrice,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _textDark,
                                  fontSize: healthSp(context, 12),
                                  fontFamily: _font,
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (rating != null && rating > 0) ...[
                          SizedBox(height: healthDp(context, 6)),
                          Row(
                            children: [
                              Icon(
                                Icons.star_rounded,
                                size: healthDp(context, 14),
                                color: const Color(0xFFFFC107),
                              ),
                              SizedBox(width: healthDp(context, 2)),
                              Text(
                                '${rating.toStringAsFixed(1)}($reviewCount)',
                                style: TextStyle(
                                  color: _metaMuted,
                                  fontSize: healthSp(context, 10),
                                  fontFamily: _font,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: healthDp(context, 10),
              top: -healthDp(context, 2),
              child: const _WeeklyDealRibbon(),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyDealRibbon extends StatelessWidget {
  const _WeeklyDealRibbon();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        healthDp(context, 8),
        healthDp(context, 4),
        healthDp(context, 7),
        healthDp(context, 4),
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFF5A8D),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(healthDp(context, 3)),
          topRight: Radius.circular(healthDp(context, 2)),
          bottomRight: Radius.circular(healthDp(context, 2)),
          bottomLeft: Radius.circular(healthDp(context, 2)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: healthDp(context, 4),
            offset: Offset(0, healthDp(context, 2)),
          ),
        ],
      ),
      child: Text(
        '이주의 DEAL',
        style: TextStyle(
          color: Colors.white,
          fontSize: healthSp(context, 9),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w300,
          height: 1.1,
          letterSpacing: healthSp(context, -0.36),
        ),
      ),
    );
  }
}

/// MD's Pick — 가로 스크롤 (약 2.1개 노출), [ProductCatalogCard] 사용
class _MdPickSection extends StatelessWidget {
  final List<Product> products;
  final ValueChanged<Product> onProductTap;

  const _MdPickSection({
    required this.products,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    final items = products.take(_kMdPickLimit).toList();
    if (items.isEmpty) return const SizedBox.shrink();

    final hPad = _contentHorizontalPad(context);
    final gap = healthDp(context, 5);
    final viewportW = MediaQuery.sizeOf(context).width - hPad * 2;
    final cardW = viewportW / 2.1;
    final listH = ProductCatalogCard.preferredMainAxisExtent(context);

    return SizedBox(
      height: listH,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: hPad),
        physics: const BouncingScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(width: gap),
        itemBuilder: (context, index) {
          final product = items[index];
          return SizedBox(
            width: cardW,
            child: ProductCatalogCard(
              product: product,
              onTap: () => onProductTap(product),
            ),
          );
        },
      ),
    );
  }
}
