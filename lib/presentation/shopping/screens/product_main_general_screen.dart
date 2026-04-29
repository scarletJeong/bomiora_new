import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../../data/models/product/product_model.dart';
import '../../../data/repositories/product/product_repository.dart';
import '../../common/widgets/app_bar_menu.dart';
import '../../common/widgets/appbar_menutap.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/app_footer.dart';
import '../../common/widgets/navi_bar.dart';
import '../../common/widgets/web_dragscroll.dart';
import '../utils/get_product.dart';

/// 카테고리 칩 라벨 — [productGeneralCategoryList] 순서와 동일
const List<String> _kHealthcareChipShortLabels = [
  '다이어트',
  '디톡스',
  '건강/면역',
  '뷰티/코스메틱',
  '헤어/탈모',
];

/// [productGeneralCategoryList] 순서와 동일한 원형 칩 아이콘 (SVG)
const List<String> _kGeneralMainCategoryIcons = [
  AppAssets.generalMainIcon1,
  AppAssets.generalMainIcon2,
  AppAssets.generalMainIcon3,
  AppAssets.generalMainIcon4,
  AppAssets.generalMainIcon5,
];

/// 헬스케어 스토어 메인 중간 배너 (가로 스와이프)
const List<String> _kMidBannerAssets = [
  AppAssets.generalMainBanner,
  AppAssets.generalMainBanner2,
];

const int _kMaxCategoryProducts = 4;

String _stripHtmlTags(String? raw) {
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

/// 헬스케어 스토어(일반 상품) 메인 — 카테고리별 API 상품 + MD's Pick만 정적 구성.
///
/// 본문 스크롤 구성은 [_buildHealthcareStoreMainSlivers] 한곳에서 순서를 본다
/// (`ProductMainScreen`의 `Column(children: [...])`와 같은 역할).
class ProductMainGeneralScreen extends StatefulWidget {
  const ProductMainGeneralScreen({super.key});

  @override
  State<ProductMainGeneralScreen> createState() => _ProductMainGeneralScreenState();
}

class _ProductMainGeneralScreenState extends State<ProductMainGeneralScreen> {
  static const String _font = 'Gmarket Sans TTF';

  final GlobalKey<ScaffoldState> _pageScaffoldKey = GlobalKey<ScaffoldState>();
  final Map<String, List<Product>> _byCategory = {};
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
      final results = await Future.wait(
        productGeneralCategoryList.map(
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
        _byCategory.clear();
        for (var i = 0; i < productGeneralCategoryList.length; i++) {
          _byCategory[productGeneralCategoryList[i].categoryId] = results[i];
        }
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

  void _openCategoryList(ProductCategoryItem item) {
    Navigator.pushNamed(
      context,
      '/product-general/',
      arguments: {
        'categoryId': item.categoryId,
        'categoryName': item.label,
        'productKind': 'general',
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final scale = (w / 375.0).clamp(0.85, 1.15);

    return MobileAppLayoutWrapper(
      child: Scaffold(
        key: _pageScaffoldKey,
        backgroundColor: Colors.white,
        appBar: AppBarMenu(
          onMenuPressed: () => _pageScaffoldKey.currentState?.openDrawer(),
        ),
        drawer: AppBarMenuTapDrawer(
          onHealthDashboardTap: () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/health');
          },
        ),
        body: DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: _font),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '상품을 불러오지 못했습니다.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15 * scale,
                                color: Colors.grey[800],
                              ),
                            ),
                            const SizedBox(height: 16),
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
                        slivers: _buildHealthcareStoreMainSlivers(scale),
                      ),
                    ),
        ),
        bottomNavigationBar: const FooterBar(),
      ),
    );
  }

  /// 메인 스크롤에 쌓이는 섹션 순서 (상단 → 하단).
  List<Widget> _buildHealthcareStoreMainSlivers(double scale) {
    return [
      // 히어로: 상단 타이틀/이미지 블록
      SliverToBoxAdapter(child: _HeroBlock(scale: scale)),
      // MD's Pick 제목 + 정적 상품 슬라이더
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
          child: Text(
            "MD's Pick",
            style: TextStyle(
              fontSize: 19.29 * scale,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
      ),
      SliverToBoxAdapter(child: _MdPickSection(scale: scale)),
      // 구분선 + 카테고리 원형 칩 (칩 너비에 맞춘 Divider)
      SliverToBoxAdapter(
        child: _HealthcareCategoryHeader(
          scale: scale,
          onChipTap: _openCategoryList,
        ),
      ),
      // 중간 배너 캐러셀
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 20),
          child: const _MidBannerCarousel(),
        ),
      ),
      // 카테고리별 API 상품 그리드(각 섹션: 제목 + 2열 그리드)
      ..._buildCategorySectionSlivers(scale),
      const SliverToBoxAdapter(child: SizedBox(height: 32)),
      const SliverToBoxAdapter(child: AppFooter()),
    ];
  }

  List<Widget> _buildCategorySectionSlivers(double scale) {
    final out = <Widget>[];
    for (var idx = 0; idx < productGeneralCategoryList.length; idx++) {
      final cat = productGeneralCategoryList[idx];
      final all = _byCategory[cat.categoryId] ?? const <Product>[];
      final products = all.take(_kMaxCategoryProducts).toList();
      if (idx > 0) {
        out.add(const SliverToBoxAdapter(child: SizedBox(height: 36)));
      }
      out.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, idx == 0 ? 8 : 0, 20, 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '| ${cat.label.replaceAll(' 제품', '')}',
                    style: TextStyle(
                      fontSize: 19.29 * scale,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
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
          // 비대면 치료 `ProductListScreen` 그리드와 동일 (horizontal 18, ratio 0.66, spacing)
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
          sliver: products.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        '등록된 상품이 없습니다',
                        style: TextStyle(
                          fontSize: 13 * scale,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                )
              : SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.66,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      return _CategoryProductCell(
                        product: products[index],
                        onTap: () => _openProductDetail(products[index]),
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

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      child: SizedBox(
        height: 216 * scale,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              'https://placehold.co/800x450/E8E0D5/6D5F47?text=Healthcare+Store',
              fit: BoxFit.cover,
              alignment: Alignment.center,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFFE8E0D5),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 56 * scale,
              child: Column(
                children: [
                  Text(
                    '당신의 일상에 건강을 더하다.',
                    style: TextStyle(
                      color: const Color(0xFF6D5F47),
                      fontSize: 11.7 * scale,
                      fontWeight: FontWeight.w300,
                      shadows: const [
                        Shadow(
                          color: Colors.white70,
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 4 * scale),
                  Text(
                    '헬스케어 스토어',
                    style: TextStyle(
                      color: const Color(0xFF6D5F47),
                      fontSize: 25.8 * scale,
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

class _MidBannerCarousel extends StatefulWidget {
  const _MidBannerCarousel();

  @override
  State<_MidBannerCarousel> createState() => _MidBannerCarouselState();
}

class _MidBannerCarouselState extends State<_MidBannerCarousel> {
  late final PageController _pageController;
  int _pageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        WebDragScrollConfiguration(
          child: AspectRatio(
            aspectRatio: 374 / 234,
            child: PageView.builder(
              controller: _pageController,
              itemCount: _kMidBannerAssets.length,
              onPageChanged: (i) => setState(() => _pageIndex = i),
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      _kMidBannerAssets[index],
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFF0F0F0),
                        alignment: Alignment.center,
                        child:
                            Icon(Icons.image_outlined, color: Colors.grey[400]),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _kMidBannerAssets.length,
            (i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _pageIndex == i ? 8 : 6,
                height: 6,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  color: _pageIndex == i
                      ? const Color(0xFFFF5A8D)
                      : const Color(0xFFE0E0E0),
                ),
              ),
            ),
          ),
        ),
      ],
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: ShapeDecoration(
            color: const Color(0xFFFF5A8D),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(9999),
            ),
          ),
          child: const Text(
            'More',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final Product product;
  final double scale;

  const _PriceRow({required this.product, required this.scale});

  @override
  Widget build(BuildContext context) {
    final dr = product.discountRate;
    final showRating =
        (product.rating ?? 0) > 0 || (product.reviewCount ?? 0) > 0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (dr != null && dr > 0) ...[
          Text(
            '${dr.round()}%',
            style: TextStyle(
              color: const Color(0xFFFF5A8D),
              fontSize: 12 * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(width: 6 * scale),
        ],
        Text(
          product.formattedPrice,
          style: TextStyle(
            color: const Color(0xFF231F20),
            fontSize: 12 * scale,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (showRating) ...[
          SizedBox(width: 8 * scale),
          Icon(
            Icons.star,
            size: 12 * scale,
            color: const Color(0xFFFF5A8D),
          ),
          SizedBox(width: 2 * scale),
          Text(
            '${(product.rating ?? 0).toStringAsFixed(1)}'
            '(${product.reviewCount ?? 0})',
            style: TextStyle(
              color: const Color(0xFF777777),
              fontSize: 10.5 * scale,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ],
    );
  }
}

/// MD's Pick 아래: 상단 여백 → 칩 행 너비에 맞춘 구분선 → 칩 → 하단 여백
class _HealthcareCategoryHeader extends StatelessWidget {
  final double scale;
  final void Function(ProductCategoryItem) onChipTap;

  const _HealthcareCategoryHeader({
    required this.scale,
    required this.onChipTap,
  });

  static double _chipDiameter(double scale) =>
      (76 * scale).clamp(64.0, 88.0);

  /// 첫 칩 왼쪽 ~ 마지막 칩 오른쪽까지의 가로 길이 (구분선 너비)
  static double chipTrackWidth(double scale) {
    final d = _chipDiameter(scale);
    final gap = 12 * scale;
    final n = productGeneralCategoryList.length;
    return n * d + (n - 1) * gap;
  }

  @override
  Widget build(BuildContext context) {
    final trackW = chipTrackWidth(scale);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        Center(
          child: SizedBox(
            width: trackW,
            child: const Divider(
              height: 1,
              thickness: 1,
              color: Color(0xFFE8E8E8),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
          child: _CategoryChipsRow(
            scale: scale,
            onChipTap: onChipTap,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _CategoryChipsRow extends StatelessWidget {
  final double scale;
  final void Function(ProductCategoryItem) onChipTap;

  const _CategoryChipsRow({
    required this.scale,
    required this.onChipTap,
  });

  @override
  Widget build(BuildContext context) {
    final diameter = _HealthcareCategoryHeader._chipDiameter(scale);
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
                for (var i = 0; i < productGeneralCategoryList.length; i++) ...[
                  if (i > 0) SizedBox(width: 12 * scale),
                  _CategoryIconChip(
                    diameter: diameter,
                    iconAsset: _kGeneralMainCategoryIcons[i],
                    label: _kHealthcareChipShortLabels[i],
                    scale: scale,
                    onTap: () => onChipTap(productGeneralCategoryList[i]),
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
  final double scale;
  final VoidCallback onTap;

  const _CategoryIconChip({
    required this.diameter,
    required this.iconAsset,
    required this.label,
    required this.scale,
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
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(6 * scale, 8 * scale, 6 * scale, 6 * scale),
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
                    fontSize: (8 * scale + 1.5).clamp(8.0, 11.0),
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

/// MD's Pick — 디자인용 정적 카드 3개 (API 비연동)
class _MdPickSection extends StatelessWidget {
  final double scale;

  const _MdPickSection({required this.scale});

  @override
  Widget build(BuildContext context) {
    const items = [
      _MdPickData(
        imageUrl: 'https://placehold.co/204x204/FFE4EC/FF5A8D?text=MD+1',
        brand: '닥터스칼프',
        title: '7, 8, 9단계_보미 다이어트환',
        promo: '[신제품 프로모션]',
        line1: '다이어트의 시작! 보미 다이어트 스텐다드 라',
        line2: '인업으로 쉬워지는 다이어트를 경험하세요.',
        discountPercent: 26,
        priceLabel: '8,888,000원',
        rating: '4.8',
        reviews: '(491)',
      ),
      _MdPickData(
        imageUrl: 'https://placehold.co/204x204/E8F4FF/231F20?text=MD+2',
        brand: '닥터스칼프',
        title: '7, 8, 9단계_보미 다이어트환',
        promo: '[신제품 프로모션]',
        line1: '다이어트의 시작! 보미 다이어트 스텐다드 라',
        line2: '인업으로 쉬워지는 다이어트를 경험하세요.',
        discountPercent: 26,
        priceLabel: '8,888,000원',
        rating: '4.8',
        reviews: '(491)',
      ),
      _MdPickData(
        imageUrl: 'https://placehold.co/204x204/F0FFF4/6D5F47?text=MD+3',
        brand: '닥터스칼프',
        title: '7, 8, 9단계_보미 다이어트환',
        promo: '[신제품 프로모션]',
        line1: '다이어트의 시작! 보미 다이어트 스텐다드 라',
        line2: '인업으로 쉬워지는 다이어트를 경험하세요.',
        discountPercent: 26,
        priceLabel: '8,888,000원',
        rating: '4.8',
        reviews: '(491)',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = (c.maxWidth - 16) / 3;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final d in items)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: _MdPickCard(data: d, scale: scale, imageWidth: w),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _MdPickData {
  final String imageUrl;
  final String brand;
  final String title;
  final String promo;
  final String line1;
  final String line2;
  final int discountPercent;
  final String priceLabel;
  final String rating;
  final String reviews;

  const _MdPickData({
    required this.imageUrl,
    required this.brand,
    required this.title,
    required this.promo,
    required this.line1,
    required this.line2,
    required this.discountPercent,
    required this.priceLabel,
    required this.rating,
    required this.reviews,
  });
}

class _MdPickCard extends StatelessWidget {
  final _MdPickData data;
  final double scale;
  final double imageWidth;

  const _MdPickCard({
    required this.data,
    required this.scale,
    required this.imageWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              data.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFFE8E8E8),
                alignment: Alignment.center,
                child: Icon(Icons.image_outlined, color: Colors.grey[400]),
              ),
            ),
          ),
        ),
        SizedBox(height: 8 * scale),
        Text(
          data.brand,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFFD2D2D2),
            fontSize: 8.77 * scale,
            fontWeight: FontWeight.w300,
          ),
        ),
        SizedBox(height: 2 * scale),
        Text(
          data.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFF231F20),
            fontSize: 11 * scale,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        SizedBox(height: 2 * scale),
        Text(
          data.promo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFF231F20),
            fontSize: 10.5 * scale,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 4 * scale),
        Text(
          data.line1,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFF231F20),
            fontSize: 8.77 * scale,
            fontWeight: FontWeight.w300,
          ),
        ),
        Text(
          data.line2,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: const Color(0xFF231F20),
            fontSize: 8.77 * scale,
            fontWeight: FontWeight.w300,
          ),
        ),
        SizedBox(height: 6 * scale),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${data.discountPercent}',
                style: TextStyle(
                  color: const Color(0xFFFF5A8D),
                  fontSize: 11.7 * scale,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: '%  ',
                style: TextStyle(
                  color: const Color(0xFFFF5A8D),
                  fontSize: 12 * scale,
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: data.priceLabel,
                style: TextStyle(
                  color: const Color(0xFF231F20),
                  fontSize: 10 * scale,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 4 * scale),
        Row(
          children: [
            Text(
              data.rating,
              style: TextStyle(
                color: const Color(0xFF999999),
                fontSize: 7.8 * scale,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: 4 * scale),
            Expanded(
              child: Text(
                data.reviews,
                style: TextStyle(
                  color: const Color(0xFF999999),
                  fontSize: 7.8 * scale,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CategoryProductCell extends StatelessWidget {
  static const String _gmarket = 'Gmarket Sans TTF';

  final Product product;
  final VoidCallback onTap;

  const _CategoryProductCell({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final namePlain = _stripHtmlTags(product.name);
    final subjectPlain = _stripHtmlTags(product.itSubject);
    // `ProductListScreen._buildProductCard`와 동일한 폰트·이미지 비율 (390폭, 이미지 높이 = 셀의 2/3)
    final screenW = MediaQuery.sizeOf(context).width;
    final tScale = (screenW / 390.0).clamp(0.88, 1.18);
    final nameFs = (12.5 * tScale).clamp(11.0, 15.0);
    final subjectFs = (10.0 * tScale).clamp(9.0, 12.0);
    final origFs = (10.5 * tScale).clamp(9.5, 12.5);

    return LayoutBuilder(
      builder: (context, itemConstraints) {
        final imageHeight = itemConstraints.hasBoundedHeight
            ? itemConstraints.maxHeight * 2 / 3
            : 220.0;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: Card(
              elevation: 2,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: imageHeight,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: product.imageUrl != null
                          ? Image.network(
                              product.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _ph(),
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                );
                              },
                            )
                          : _ph(),
                    ),
                  ),
                  Expanded(
                    child: Padding(
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
                              ],
                            ),
                          ),
                          if (product.originalPrice != null &&
                              product.originalPrice! > product.price) ...[
                            SizedBox(height: 4 * tScale),
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
                          FittedBox(
                            alignment: Alignment.centerLeft,
                            fit: BoxFit.scaleDown,
                            child: _PriceRow(
                              product: product,
                              scale: tScale,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _ph() => ColoredBox(
        color: Colors.grey.shade200,
        child: Icon(
          Icons.image_not_supported,
          size: 40,
          color: Colors.grey[400],
        ),
      );
}
