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

/// 비대면 치료(처방) 카테고리 탭/메뉴 소스
const List<ProductCategoryItem> productPrescriptionCategoryList = [
  ProductCategoryItem(label: '다이어트환', categoryId: '10'),
  ProductCategoryItem(label: '디톡스환', categoryId: '20'),
  ProductCategoryItem(label: '심신안정환', categoryId: '80'),
  ProductCategoryItem(label: '건강/면역', categoryId: '50'),
];

/// 헬스케어 스토어(일반) 카테고리 탭/메뉴 소스
const List<ProductCategoryItem> productGeneralCategoryList = [
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

/// [productGeneralCategoryList]에서 홈 카테고리 섹션에 붙일 `ca_id`만 (라벨·종류는 리스트가 단일 소스).
const Set<String> productHomeCategorySectionExtraCategoryIds = {'60', '70'};

/// 홈 [CategorySection] 탭: 처방 전체 + 위 [Set]에 해당하는 일반 항목(동일 항목 참조).
final List<ProductCategoryItem> productHomeCategorySectionTabList =
    List<ProductCategoryItem>.unmodifiable(<ProductCategoryItem>[
  ...productPrescriptionCategoryList,
  ...productGeneralCategoryList.where(
    (e) => productHomeCategorySectionExtraCategoryIds.contains(e.categoryId),
  ),
]);
