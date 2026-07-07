import '../../../core/constants/app_assets.dart';

class ProductCategoryItem {
  final String label;
  final String categoryId;
  /// API `it_kind` 등 (`prescription`, `general`).
  final String productKind;

  const ProductCategoryItem({
    required this.label,
    required this.categoryId,
    this.productKind = 'prescription',
  });
}

/// 비대면 치료(처방) — API 실패 시 폴백
const List<ProductCategoryItem> productPrescriptionCategoryListFallback = [
  ProductCategoryItem(label: '다이어트환', categoryId: '10'),
  ProductCategoryItem(label: '디톡스환', categoryId: '20'),
  ProductCategoryItem(label: '심신안정환', categoryId: '80'),
  ProductCategoryItem(label: '건강/면역', categoryId: '50'),
];

/// 헬스케어 스토어(일반) — API 실패 시 폴백
const List<ProductCategoryItem> productGeneralCategoryListFallback = [
  ProductCategoryItem(
    label: '다이어트 제품',
    categoryId: '11',
    productKind: 'general',
  ),
  ProductCategoryItem(
    label: '디톡스 제품',
    categoryId: '21',
    productKind: 'general',
  ),
  ProductCategoryItem(
    label: '건강 / 면역',
    categoryId: '51',
    productKind: 'general',
  ),
  ProductCategoryItem(
    label: '뷰티 / 코스메틱',
    categoryId: '60',
    productKind: 'general',
  ),
  ProductCategoryItem(
    label: '헤어 / 탈모',
    categoryId: '70',
    productKind: 'general',
  ),
];

/// `ca_id` → 비대면 진료 칩 아이콘 (신규 카테고리는 기본 아이콘)
String productPrescriptionCategoryIconAsset(String categoryId) {
  switch (categoryId) {
    case '10':
      return AppAssets.generalMainIcon1;
    case '20':
      return AppAssets.generalMainIcon2;
    case '50':
      return AppAssets.generalMainIcon3;
    case '80':
      return AppAssets.generalMainIcon4;
    default:
      return AppAssets.generalMainIcon1;
  }
}

/// 비대면 진료 > 다이어트(다이어트환) 상품 목록 라우트 인자
const Map<String, dynamic> kPrescriptionDietProductListArguments = {
  'categoryId': '10',
  'categoryName': '다이어트환',
  'productKind': 'prescription',
};

Map<String, dynamic> prescriptionDietProductListArguments({
  String categoryId = '10',
  String categoryName = '다이어트환',
}) =>
    {
      'categoryId': categoryId,
      'categoryName': categoryName,
      'productKind': 'prescription',
    };

/// 드로어·메뉴용 짧은 라벨
String productPrescriptionCategoryMenuLabel(String categoryName) {
  return categoryName.replaceAll('환', '').trim();
}

/// `ca_id` → 헬스케어 스토어 칩 아이콘 (신규 카테고리는 기본 아이콘)
String productGeneralCategoryIconAsset(String categoryId) {
  switch (categoryId) {
    case '11':
      return AppAssets.generalMainIcon1;
    case '21':
      return AppAssets.generalMainIcon2;
    case '51':
      return AppAssets.generalMainIcon3;
    case '60':
      return AppAssets.generalMainIcon4;
    case '70':
      return AppAssets.generalMainIcon5;
    default:
      return AppAssets.generalMainIcon1;
  }
}

/// 칩·탭용 짧은 라벨
String productGeneralCategoryChipLabel(String categoryName) {
  return categoryName
      .replaceAll(' 제품', '')
      .replaceAll(' / ', '/')
      .trim();
}
