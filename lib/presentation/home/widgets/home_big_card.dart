import 'package:bomiora_app/presentation/health/health_common/health_responsive_scale.dart';

/// 홈 가로 스크롤용 큰 카드(신상품·가이드북 등) 공통 치수.
///
/// Figma **375** 기준 수치에 [healthTextScaleByWidth]를 곱합니다
/// ([healthDp]/[healthSp]와 동일 규칙).
///
/// - 이미지: `317.31 × 172.43`, 모서리 `11.54`, `BoxFit.cover`
/// - 이미지 ↔ 텍스트 블록: `12`
/// - 텍스트 블록: 폭 `317.31`, 고정 높이 `50.68`
/// - 제목 ↔ 본문: `6.92`
/// - 제목 `14` / 본문 `10`
/// - 카드 간격: `12`
class HomeBigCardLayout {
  HomeBigCardLayout({
    required this.cardW,
    required this.imageH,
    required this.textPanelHeight,
    required this.radius,
    required this.columnGap,
    required this.titleDescGap,
    required this.rowGapBetweenCards,
    required this.titleFs,
    required this.descFs,
  });

  /// 카드·이미지 가로(375에서 이미지·텍스트 영역 동일 폭).
  final double cardW;
  final double imageH;
  /// 제목+간격+본문을 담는 하단 박스 높이.
  final double textPanelHeight;
  final double radius;
  final double columnGap;
  final double titleDescGap;
  final double rowGapBetweenCards;
  final double titleFs;
  final double descFs;

  double get descLetterSpacing => -0.05 * descFs;

  factory HomeBigCardLayout.fromWidth(double w) {
    final s = healthTextScaleByWidth(w);
    double sc(double base375) => base375 * s;

    return HomeBigCardLayout(
      cardW: sc(317.31),
      imageH: sc(172.43),
      textPanelHeight: sc(50.68),
      radius: sc(11.54),
      columnGap: sc(12),
      titleDescGap: sc(6.92),
      rowGapBetweenCards: sc(12),
      titleFs: sc(14),
      descFs: sc(10),
    );
  }

  double get listItemHeight => imageH + columnGap + textPanelHeight;
}
