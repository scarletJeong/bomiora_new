import 'package:flutter/material.dart';

import '../../../../data/models/product/product_model.dart';
import '../../../../data/repositories/product/product_repository.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import '../../../shopping/widgets/recommend_product.dart';

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

  List<Product> _recommendedProducts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRecommended();
  }

  Future<void> _loadRecommended() async {
    try {
      final results = await Future.wait([
        ProductRepository.getProductsByCategory(
          categoryId: '10',
          productKind: 'prescription',
          page: 1,
          pageSize: 100,
        ),
        ProductRepository.getProductsByCategory(
          categoryId: '20',
          productKind: 'prescription',
          page: 1,
          pageSize: 100,
        ),
        ProductRepository.getProductsByCategory(
          categoryId: '80',
          productKind: 'prescription',
          page: 1,
          pageSize: 100,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _recommendedProducts = results.expand((e) => e).toList();
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
    final textScale =
        healthTextScaleByWidth(MediaQuery.sizeOf(context).width);

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
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
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
                          height: 1.60,
                        ),
                      ),
                      SizedBox(height: healthDp(context, 8)),
                      Text(
                        '문진표의 정보 입력이 완료되었습니다.\n해당 데이터는 비대면 진료에 활용됩니다',
                        style: TextStyle(
                          color: _muted,
                          fontSize: healthSp(context, 12),
                          fontFamily: _font,
                          fontWeight: FontWeight.w500,
                          height: 1.67,
                        ),
                      ),
                      SizedBox(height: healthDp(context, 20)),

                      // 내 문진표 다시보기 카드
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _goToProfile,
                          borderRadius:
                              BorderRadius.circular(healthDp(context, 16)),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          height: 1.65,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: _pfPink,
                                  size: healthDp(context, 28),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      SizedBox(height: healthDp(context, 22)),

                      // 추천상품
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
                      else
                        RecommendProductSection(
                          excludedProductNames: const [],
                          products: _recommendedProducts,
                          title: '추천상품',
                          showLeadingBar: false,
                          hideWhenEmpty: true,
                          onProductTap: (product) {
                            Navigator.pushNamed(
                                context, '/product/${product.id}');
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
