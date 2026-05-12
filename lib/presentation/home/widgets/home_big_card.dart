import '../../common/responsive_scale.dart';

/// 홈 가로 스크롤용 큰 카드(신상품·가이드북 등) 공통 치수.
///
/// Figma **375** 기준. 넓은 레일(650)까지는 **375↔650만** 선형 보간(450 없음).
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

  double get descLetterSpacing => homeCardBodyLetterSpacing(descFs);

  factory HomeBigCardLayout.fromWidth(double w) {
    final titleFs = lerpByWidth375_650(
      width: w,
      v375: 14,
      v650: 25,
    );
    final descFs = lerpByWidth375_650(
      width: w,
      v375: 10,
      v650: 17,
    );
    return HomeBigCardLayout(
      cardW: lerpByWidth375_650(
        width: w,
        v375: 317.31,
        v650: 550,
      ),
      imageH: lerpByWidth375_650(
        width: w,
        v375: 172.43,
        v650: 299.01,
      ),
      textPanelHeight: lerpByWidth375_650(
        width: w,
        v375: 50.68,
        v650: 87.86,
      ),
      radius: lerpByWidth375_650(
        width: w,
        v375: 11.54,
        v650: 20,
      ),
      columnGap: lerpByWidth375_650(
        width: w,
        v375: 12,
        v650: 20,
      ),
      titleDescGap: lerpByWidth375_650(
        width: w,
        v375: 6.92,
        v650: 12,
      ),
      rowGapBetweenCards: lerpByWidth375_650(
        width: w,
        v375: 12,
        v650: 20,
      ),
      titleFs: titleFs,
      descFs: descFs,
    );
  }

  double get listItemHeight => imageH + columnGap + textPanelHeight;
}
