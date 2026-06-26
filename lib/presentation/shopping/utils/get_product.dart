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

/// @deprecated [ProductCategoryCatalog.prescriptionCategories] 사용 권장
const List<ProductCategoryItem> productPrescriptionCategoryList =
    productPrescriptionCategoryListFallback;

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

/// @deprecated [ProductCategoryCatalog.generalCategories] 사용 권장
const List<ProductCategoryItem> productGeneralCategoryList =
    productGeneralCategoryListFallback;

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

/// [productGeneralCategoryListFallback]에서 홈 카테고리 섹션에 붙일 `ca_id`만
const Set<String> productHomeCategorySectionExtraCategoryIds = {'60', '70'};

/// 홈 [CategorySection] 탭: 처방 전체 + 위 [Set]에 해당하는 일반 항목
List<ProductCategoryItem> buildProductHomeCategorySectionTabList({
  List<ProductCategoryItem> prescriptionCategories =
      productPrescriptionCategoryListFallback,
  required List<ProductCategoryItem> generalCategories,
}) {
  return List<ProductCategoryItem>.unmodifiable(<ProductCategoryItem>[
    ...prescriptionCategories,
    ...generalCategories.where(
      (e) => productHomeCategorySectionExtraCategoryIds.contains(e.categoryId),
    ),
  ]);
}

/// @deprecated [buildProductHomeCategorySectionTabList] 사용 권장
final List<ProductCategoryItem> productHomeCategorySectionTabList =
    buildProductHomeCategorySectionTabList(
  generalCategories: productGeneralCategoryListFallback,
);
