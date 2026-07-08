import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../data/models/product/product_model.dart';
import '../../common/widgets/product_card.dart';
import '../../health/health_common/health_responsive_scale.dart';
import 'recommend_product.dart';

/// 가로 한 화면에 보이는 정사각형 카드 수
const double kRecommendBottomSheetItemsPerViewport = 2.2;

/// 카드 너비 대비 이미지 정사각형 비율 (살짝 작게)
const double kRecommendBottomSheetImageScale = 0.9;

Widget _dismissibleBottomSheetShell({
  required BuildContext context,
  required Widget child,
}) {
  return GestureDetector(
    onTap: () => Navigator.of(context).pop(),
    behavior: HitTestBehavior.opaque,
    child: Align(
      alignment: Alignment.bottomCenter,
      child: GestureDetector(
        onTap: () {},
        behavior: HitTestBehavior.deferToChild,
        child: child,
      ),
    ),
  );
}

/// 진료담기 후 추천 상품 바텀시트
Future<void> showRecommendProductBottomup({
  required BuildContext context,
  required List<Product> products,
  required ValueChanged<Product> onProductTap,
  VoidCallback? onGoToCart,
  String title = '이것도 같이 구매하면 좋아요',
}) async {
  if (products.isEmpty) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(50),
        topRight: Radius.circular(50),
      ),
    ),
    builder: (context) {
      final screenWidth = MediaQuery.sizeOf(context).width;
      return _dismissibleBottomSheetShell(
        context: context,
        child: SizedBox(
          width: screenWidth,
          child: RecommendProductBottomSheet(
            products: products.take(4).toList(),
            title: title,
            onProductTap: onProductTap,
            onGoToCart: onGoToCart,
          ),
        ),
      );
    },
  );
}

class RecommendProductBottomSheet extends StatelessWidget {
  final List<Product> products;
  final String title;
  final ValueChanged<Product> onProductTap;
  final VoidCallback? onGoToCart;

  const RecommendProductBottomSheet({
    super.key,
    required this.products,
    required this.title,
    required this.onProductTap,
    this.onGoToCart,
  });

  @override
  Widget build(BuildContext context) {
    final sheetPadding = healthDp(context, 30);
    final crossGap = healthDp(context, 12);
    final imageGap = healthDp(context, 6);
    final textBlockH = healthDp(context, 52);

    return LayoutBuilder(
      builder: (context, constraints) {
        final innerWidth = constraints.maxWidth - sheetPadding * 2;
        final cardWidth = innerWidth > crossGap
            ? (innerWidth - crossGap) / kRecommendBottomSheetItemsPerViewport
            : innerWidth * 0.42;
        final imageSize = cardWidth * kRecommendBottomSheetImageScale;
        final listHeight = imageSize + imageGap + textBlockH;

        return ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(healthDp(context, 30)),
            topRight: Radius.circular(healthDp(context, 30)),
          ),
          child: Container(
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  sheetPadding,
                  healthDp(context, 10),
                  sheetPadding,
                  sheetPadding,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: healthDp(context, 40),
                        height: healthDp(context, 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius:
                              BorderRadius.circular(healthDp(context, 2)),
                        ),
                      ),
                    ),
                    SizedBox(height: healthDp(context, 16)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: healthDp(context, 1),
                          height: healthDp(context, 14),
                          margin: EdgeInsets.only(right: healthDp(context, 6)),
                          color: const Color(0xFF1A1A1A),
                        ),
                        Expanded(
                          child: Text(
                            title,
                            style: shoppingSectionTitleStyle(context),
                          ),
                        ),
                        if (onGoToCart != null)
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pop();
                              onGoToCart!();
                            },
                            behavior: HitTestBehavior.opaque,
                            child: Padding(
                              padding: EdgeInsets.only(
                                left: healthDp(context, 8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '바로가기',
                                    style: TextStyle(
                                      color: const Color(0xFF898686),
                                      fontSize: healthSp(context, 11),
                                      fontFamily: 'Gmarket Sans TTF',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right,
                                    size: healthDp(context, 15),
                                    color: const Color(0xFF898686),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: healthDp(context, 12)),
                    SizedBox(
                      height: listHeight,
                      child: ScrollConfiguration(
                        behavior: const _HorizontalDragScrollBehavior(),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: products.length,
                          separatorBuilder: (_, __) =>
                              SizedBox(width: crossGap),
                          itemBuilder: (context, index) {
                            return SizedBox(
                              width: cardWidth,
                              child: _RecommendSquareProductCard(
                                product: products[index],
                                imageSize: imageSize,
                                textBlockHeight: textBlockH,
                                onTap: () => onProductTap(products[index]),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RecommendSquareProductCard extends StatelessWidget {
  static const Color _brandPink = Color(0xFFFF5A8D);
  static const Color _textDark = Color(0xFF1A1A1E);
  static const String _gmarket = 'Gmarket Sans TTF';

  final Product product;
  final double imageSize;
  final double textBlockHeight;
  final VoidCallback onTap;

  const _RecommendSquareProductCard({
    required this.product,
    required this.imageSize,
    required this.textBlockHeight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = stripProductCatalogHtml(product.name);
    final imageRadius = healthDp(context, 8);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(imageRadius),
            child: SizedBox(
              width: imageSize,
              height: imageSize,
              child: ColoredBox(
                color: const Color(0xFFF3F3F3),
                child: product.displayImageUrl.isNotEmpty
                    ? Image.network(
                        product.displayImageUrl,
                        width: imageSize,
                        height: imageSize,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.image_not_supported,
                          color: Colors.grey[400],
                          size: healthDp(context, 28),
                        ),
                      )
                    : Icon(
                        Icons.image_not_supported,
                        color: Colors.grey[400],
                        size: healthDp(context, 28),
                      ),
              ),
            ),
          ),
          SizedBox(height: healthDp(context, 6)),
          SizedBox(
            height: textBlockHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _textDark,
                    fontSize: healthSp(context, 11),
                    fontFamily: _gmarket,
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Text(
                      '${(product.discountRate ?? 0).round()}%',
                      style: TextStyle(
                        color: _brandPink,
                        fontSize: healthSp(context, 11),
                        fontFamily: _gmarket,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: healthDp(context, 3)),
                    Expanded(
                      child: Text(
                        product.formattedPrice,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _textDark,
                          fontSize: healthSp(context, 12),
                          fontFamily: _gmarket,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalDragScrollBehavior extends MaterialScrollBehavior {
  const _HorizontalDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}
