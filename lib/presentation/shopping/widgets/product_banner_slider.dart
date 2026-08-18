import 'package:flutter/material.dart';

import '../../health/health_common/health_responsive_scale.dart';

/// 홈·상품 목록 공통 배너 높이 (375 기준).
const double kSharedBannerHeightBase = 210;

/// 이미지 준비 전 카테고리별 단색 플레이스홀더 (빨→주→노→초→파→남→보).
const List<Color> kProductListBannerRainbow = [
  Color(0xFFE53935), // 빨
  Color(0xFFFB8C00), // 주
  Color(0xFFFDD835), // 노
  Color(0xFF43A047), // 초
  Color(0xFF1E88E5), // 파
  Color(0xFF3949AB), // 남
  Color(0xFF8E24AA), // 보
];

/// 일반상품 — 단백질쉐이크(`a0`) 전용 / 그 외 공통
const Color kGeneralProteinShakeBannerColor = Color(0xFF1E88E5); // 파
const Color kGeneralDefaultBannerColor = Color(0xFF8E24AA); // 보

bool isProteinShakeCategoryId(String categoryId) {
  final id = categoryId.trim().toLowerCase();
  return id == 'a0';
}

/// 상품 목록 배너 색상.
/// - 비대면: 카테고리마다 다름 (탭 순서대로 무지개)
/// - 일반: 단백질쉐이크만 별도, 나머지는 공통 1색
Color resolveProductListBannerColor({
  required String? productKind,
  required String categoryId,
  int categoryIndex = 0,
}) {
  final isGeneral = (productKind ?? '').trim().toLowerCase() == 'general';
  if (isGeneral) {
    if (isProteinShakeCategoryId(categoryId)) {
      return kGeneralProteinShakeBannerColor;
    }
    return kGeneralDefaultBannerColor;
  }

  final i = categoryIndex < 0 ? 0 : categoryIndex;
  return kProductListBannerRainbow[i % kProductListBannerRainbow.length];
}

/// 상품 목록 상단 배너 — 카테고리당 1장 (현재는 단색 플레이스홀더).
class ProductBannerSlider extends StatelessWidget {
  /// 375 기준 배너 높이 — [healthDp]로 스케일.
  final double heightBase;

  /// `general` | 그 외(처방·비대면)
  final String? productKind;

  /// 현재 선택 카테고리 `ca_id`
  final String categoryId;

  /// 비대면 탭 순서 인덱스 (색상 배정용)
  final int categoryIndex;

  const ProductBannerSlider({
    super.key,
    this.heightBase = kSharedBannerHeightBase,
    this.productKind,
    required this.categoryId,
    this.categoryIndex = 0,
  });

  @override
  Widget build(BuildContext context) {
    final bannerH = healthDp(context, heightBase);
    final borderW = healthDp(context, 3);
    final color = resolveProductListBannerColor(
      productKind: productKind,
      categoryId: categoryId,
      categoryIndex: categoryIndex,
    );

    return Container(
      height: bannerH,
      width: double.infinity,
      decoration: BoxDecoration(
        color: color,
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFFFF5A8D),
            width: borderW,
          ),
        ),
      ),
    );
  }
}
