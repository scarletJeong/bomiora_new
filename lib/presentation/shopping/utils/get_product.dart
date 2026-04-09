class ProductCategoryItem {
  final String label;
  final String categoryId;

  const ProductCategoryItem({
    required this.label,
    required this.categoryId,
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
  ProductCategoryItem(label: '다이어트 제품', categoryId: '11'),
  ProductCategoryItem(label: '디톡스 제품', categoryId: '21'),
  ProductCategoryItem(label: '건강/면역', categoryId: '51'),
  ProductCategoryItem(label: '뷰티/코스메틱', categoryId: '60'),
  ProductCategoryItem(label: '헤어/탈모', categoryId: '70'),
];
