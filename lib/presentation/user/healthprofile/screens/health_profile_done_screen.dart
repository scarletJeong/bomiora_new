import 'package:flutter/material.dart';

import '../../../../data/models/product/product_model.dart';
import '../../../../data/repositories/product/product_repository.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import '../../../shopping/widgets/recommend_product.dart';
import '../../../shopping/widgets/recommend_product_bottomup.dart';

class HealthProfileDoneScreen extends StatefulWidget {
  const HealthProfileDoneScreen({super.key});

  @override
  State<HealthProfileDoneScreen> createState() => _HealthProfileDoneScreenState();
}

class _HealthProfileDoneScreenState extends State<HealthProfileDoneScreen> {
  static const String _font = 'Gmarket Sans TTF';
  static const Color _ink = Color(0xFF1A1A1A);
  static const Color _muted = Color(0xFF898686);
  static const Color _pfPink = Color(0xFFFF3787);
  static const Color _pfPinkSoft = Color(0x14FF3787);

  static const String _dietCategoryId = '10';
  static const String _detoxCategoryId = '20';

  List<Product> _recommendedProducts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecommended();
  }

  bool _isTrialProduct(Product product) {
    final name = product.name.replaceAll(' ', '');
    return name.contains('체험분') || name.contains('체험');
  }

  Product? _pickFirstFullProduct(List<Product> products) {
    for (final product in products) {
      if (!_isTrialProduct(product)) return product;
    }
    return null;
  }

  Product? _pickFirstTrialProduct(List<Product> products) {
    for (final product in products) {
      if (_isTrialProduct(product)) return product;
    }
    return null;
  }

  void _addUniqueProduct(List<Product> target, Product? product) {
    if (product == null) return;
    if (target.any((item) => item.id == product.id)) return;
    target.add(product);
  }

  Future<void> _loadRecommended() async {
    try {
      final results = await Future.wait([
        ProductRepository.getProductsByCategory(
          categoryId: _dietCategoryId,
          productKind: 'prescription',
          page: 1,
          pageSize: 100,
        ),
        ProductRepository.getProductsByCategory(
          categoryId: _detoxCategoryId,
          productKind: 'prescription',
          page: 1,
          pageSize: 100,
        ),
      ]);
      if (!mounted) return;

      final dietProducts = results[0];
      final detoxProducts = results[1];
      final ordered = <Product>[];
      _addUniqueProduct(ordered, _pickFirstFullProduct(dietProducts));
      _addUniqueProduct(ordered, _pickFirstFullProduct(detoxProducts));
      _addUniqueProduct(ordered, _pickFirstTrialProduct(dietProducts));
      _addUniqueProduct(ordered, _pickFirstTrialProduct(detoxProducts));

      setState(() {
        _recommendedProducts = ordered;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recommendedProducts = [];
        _loading = false;
      });
    }
  }

  void _goToProfile() {
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/profile',
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
    );

    return Theme(
      data: gmarketTheme,
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: _font),
        child: MobileAppLayoutWrapper(
          appBar: HealthAppBar(
            title: '문진표',
            centerTitle: false,
            titleFontSize: healthSp(context, 18),
            leadingIconSize: healthDp(context, 24),
          ),
          child: Scaffold(
            backgroundColor: Colors.white,
            body: SafeArea(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: healthDp(context, 27),
                  vertical: healthDp(context, 20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '문진표 정보 작성 완료 !',
                      style: TextStyle(
                        color: _ink,
                        fontSize: healthSp(context, 20),
                        fontFamily: _font,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: healthDp(context, 10)),
                    Text(
                      '문진표의 정보 입력이 완료되었습니다.\n해당 데이터는 비대면 진료에 활용됩니다',
                      style: TextStyle(
                        color: _muted,
                        fontSize: healthSp(context, 12),
                        fontFamily: _font,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: healthDp(context, 20)),

                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: _goToProfile,
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 10)),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(healthDp(context, 16)),
                          decoration: ShapeDecoration(
                            color: _pfPinkSoft,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(healthDp(context, 16)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '내 문진표 다시보기',
                                      style: TextStyle(
                                        color: _ink,
                                        fontSize: healthSp(context, 16),
                                        fontFamily: _font,
                                        fontWeight: FontWeight.w500,
                                        letterSpacing: -1.44,
                                      ),
                                    ),
                                    SizedBox(height: healthDp(context, 4)),
                                    Text(
                                      '정확한 진단을 위해 입력한 내용을 확인하세요',
                                      style: TextStyle(
                                        color: _muted,
                                        fontSize: healthSp(context, 10),
                                        fontFamily: _font,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.chevron_right,
                                color: Colors.black,
                                size: healthDp(context, 20),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: healthDp(context, 48)),

                    if (_loading)
                      Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: healthDp(context, 20)),
                          child: SizedBox(
                            width: healthDp(context, 36),
                            height: healthDp(context, 36),
                            child: const CircularProgressIndicator(
                              color: _pfPink,
                            ),
                          ),
                        ),
                      )
                    else if (_recommendedProducts.isNotEmpty) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 1,
                            height: 14,
                            margin: const EdgeInsets.only(right: 6),
                            color: const Color(0xFF1A1A1A),
                          ),
                          Text(
                            '추천 상품',
                            style: shoppingSectionTitleStyle(context),
                          ),
                        ],
                      ),
                      SizedBox(height: healthDp(context, 12)),
                      RecommendProductSquareRow(
                        products: _recommendedProducts,
                        onProductTap: (product) {
                          Navigator.pushNamed(
                            context,
                            '/product/${product.id}',
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
