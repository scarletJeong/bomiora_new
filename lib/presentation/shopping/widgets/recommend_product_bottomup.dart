import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../data/models/product/product_model.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/product_card.dart';
import '../../health/health_common/health_responsive_scale.dart';
import 'recommend_product.dart';

/// 가로 한 화면에 보이는 정사각형 카드 수
const double kRecommendBottomSheetItemsPerViewport = 2.2;

/// 카드 너비 대비 이미지 정사각형 비율 (살짝 작게)
const double kRecommendBottomSheetImageScale = 0.9;

/// 바텀시트 추천 카드 레이아웃 (인라인 행과 동일 크기)
({
  double cardWidth,
  double imageSize,
  double listHeight,
  double crossGap,
  double textBlockHeight,
}) computeRecommendBottomSheetCardLayout(
  BuildContext context,
  double innerWidth, {
  double itemsPerViewport = kRecommendBottomSheetItemsPerViewport,
}) {
  final crossGap = healthDp(context, 12);
  final imageGap = healthDp(context, 6);
  final textBlockH = healthDp(context, 52);
  final cardWidth = innerWidth > crossGap
      ? (innerWidth - crossGap) / itemsPerViewport
      : innerWidth * 0.42;
  final imageSize = cardWidth * kRecommendBottomSheetImageScale;
  final listHeight = imageSize + imageGap + textBlockH;
  return (
    cardWidth: cardWidth,
    imageSize: imageSize,
    listHeight: listHeight,
    crossGap: crossGap,
    textBlockHeight: textBlockH,
  );
}

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
  String headline = '장바구니에 상품을 담았어요.',
  String title = '함께 구매하기 좋은 상품',
  String primaryButtonLabel = '처방 예약 바로가기',
}) async {
  if (products.isEmpty) return;

  final contentW = MobileLayoutWrapper.contentWidthOf(context);

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.45),
    constraints: BoxConstraints(maxWidth: contentW),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(50),
        topRight: Radius.circular(50),
      ),
    ),
    builder: (context) {
      return _dismissibleBottomSheetShell(
        context: context,
        child: SizedBox(
          width: contentW,
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: Size(contentW, MediaQuery.sizeOf(context).height),
            ),
            child: RecommendProductBottomSheet(
              products: products.take(4).toList(),
              headline: headline,
              title: title,
              primaryButtonLabel: primaryButtonLabel,
              onProductTap: onProductTap,
              onGoToCart: onGoToCart,
            ),
          ),
        ),
      );
    },
  );
}

class RecommendProductBottomSheet extends StatelessWidget {
  final List<Product> products;
  final String headline;
  final String title;
  final String primaryButtonLabel;
  final ValueChanged<Product> onProductTap;
  final VoidCallback? onGoToCart;

  const RecommendProductBottomSheet({
    super.key,
    required this.products,
    required this.headline,
    required this.title,
    required this.primaryButtonLabel,
    required this.onProductTap,
    this.onGoToCart,
  });

  @override
  Widget build(BuildContext context) {
    final sheetPadding = healthDp(context, 30);

    return LayoutBuilder(
      builder: (context, constraints) {
        final innerWidth = constraints.maxWidth - sheetPadding * 2;
        final layout = computeRecommendBottomSheetCardLayout(context, innerWidth);

        return ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(healthDp(context, 30)),
            topRight: Radius.circular(healthDp(context, 30)),
          ),
          child: Container(
            width: double.infinity,
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
                        Expanded(
                          child: Text(
                            headline,
                            style: TextStyle(
                              color: const Color(0xFF1A1A1E),
                              fontSize: healthSp(context, 16),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                            ),
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
                    SizedBox(height: healthDp(context, 10)),
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
                      ],
                    ),
                    SizedBox(height: healthDp(context, 12)),
                    SizedBox(
                      height: layout.listHeight,
                      child: ScrollConfiguration(
                        behavior: const _HorizontalDragScrollBehavior(),
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          physics: const BouncingScrollPhysics(),
                          itemCount: products.length,
                          separatorBuilder: (_, __) =>
                              SizedBox(width: layout.crossGap),
                          itemBuilder: (context, index) {
                            return SizedBox(
                              width: layout.cardWidth,
                              child: RecommendSquareProductCard(
                                product: products[index],
                                imageSize: layout.imageSize,
                                textBlockHeight: layout.textBlockHeight,
                                onTap: () => onProductTap(products[index]),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (onGoToCart != null) ...[
                      SizedBox(height: healthDp(context, 20)),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop();
                          onGoToCart!();
                        },
                        child: Container(
                          width: double.infinity,
                          height: healthDp(context, 40),
                          padding: EdgeInsets.all(healthDp(context, 10)),
                          clipBehavior: Clip.antiAlias,
                          decoration: ShapeDecoration(
                            color: const Color(0xFFFF5A8D),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(healthDp(context, 10)),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            primaryButtonLabel,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: healthSp(context, 16),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
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

/// 인라인 정사각형 추천 행 — 바텀시트와 동일 카드 크기
class RecommendProductSquareRow extends StatelessWidget {
  final List<Product> products;
  final ValueChanged<Product> onProductTap;

  const RecommendProductSquareRow({
    super.key,
    required this.products,
    required this.onProductTap,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final innerWidth = constraints.maxWidth.clamp(0.0, double.infinity);
        final layout = computeRecommendBottomSheetCardLayout(context, innerWidth);

        return SizedBox(
          height: layout.listHeight,
          child: ScrollConfiguration(
            behavior: const _HorizontalDragScrollBehavior(),
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: products.length,
              separatorBuilder: (_, __) => SizedBox(width: layout.crossGap),
              itemBuilder: (context, index) {
                return SizedBox(
                  width: layout.cardWidth,
                  child: RecommendSquareProductCard(
                    product: products[index],
                    imageSize: layout.imageSize,
                    textBlockHeight: layout.textBlockHeight,
                    onTap: () => onProductTap(products[index]),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class RecommendSquareProductCard extends StatelessWidget {
  static const Color _brandPink = Color(0xFFFF5A8D);
  static const Color _textDark = Color(0xFF1A1A1E);
  static const String _gmarket = 'Gmarket Sans TTF';

  final Product product;
  final double imageSize;
  final double textBlockHeight;
  final VoidCallback onTap;

  const RecommendSquareProductCard({
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
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
                ),
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
