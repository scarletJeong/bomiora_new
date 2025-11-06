import 'package:flutter/material.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  // 대분류: 비대면진료, 상품
  final List<MainCategory> _mainCategories = [
    MainCategory(
      id: 'telemedicine',
      name: '비대면진료',
      subCategories: [
        SubCategory(
          id: 'diet',
          name: '다이어트',
          smallCategories: [
            SmallCategory(id: 'trial', name: '체험판'),
            SmallCategory(id: 'regular', name: '본품'),
          ],
        ),
        SubCategory(
          id: 'detox',
          name: '디톡스',
          smallCategories: [
            SmallCategory(id: 'trial', name: '체험판'),
            SmallCategory(id: 'regular', name: '본품'),
          ],
        ),
        SubCategory(
          id: 'mental',
          name: '정신안정',
          smallCategories: [
            SmallCategory(id: 'trial', name: '체험판'),
            SmallCategory(id: 'regular', name: '본품'),
          ],
        ),
        SubCategory(
          id: 'health',
          name: '건강/면역',
          smallCategories: [
            SmallCategory(id: 'trial', name: '체험판'),
            SmallCategory(id: 'regular', name: '본품'),
          ],
        ),
      ],
    ),
    MainCategory(
      id: 'product',
      name: '상품',
      subCategories: [
        SubCategory(
          id: 'diet',
          name: '다이어트',
          smallCategories: [],
        ),
        SubCategory(
          id: 'detox',
          name: '디톡스',
          smallCategories: [],
        ),
        SubCategory(
          id: 'health',
          name: '건강/면역',
          smallCategories: [],
        ),
        SubCategory(
          id: 'beauty',
          name: '뷰티/코스메틱',
          smallCategories: [],
        ),
        SubCategory(
          id: 'hair',
          name: '헤어/탈모',
          smallCategories: [],
        ),
      ],
    ),
  ];

  String? _selectedMainCategoryId;
  String? _selectedSubCategoryId;

  @override
  void initState() {
    super.initState();
    // �?번째 ?�분류 ?�택
    if (_mainCategories.isNotEmpty) {
      _selectedMainCategoryId = _mainCategories[0].id;
    }
  }

  MainCategory? get _selectedMainCategory {
    if (_selectedMainCategoryId == null) return null;
    return _mainCategories.firstWhere(
      (cat) => cat.id == _selectedMainCategoryId,
      orElse: () => _mainCategories[0],
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobileLayoutWrapper(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('카테고리'),
          backgroundColor: Colors.white,
          elevation: 0,
          foregroundColor: Colors.black,
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                // 검??기능
              },
            ),
            IconButton(
              icon: const Icon(Icons.shopping_cart),
              onPressed: () {
                // ?�바구니�??�동
              },
            ),
          ],
        ),
        body: Row(
          children: [
            // ?�쪽: ?�분류 리스??
            _buildMainCategoryList(),
            // ?�른�? 중분�??�분�?콘텐�?
            Expanded(
              child: _buildSubCategoryContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainCategoryList() {
    return Container(
      width: 100,
      color: Colors.grey[50],
      child: ListView.builder(
        itemCount: _mainCategories.length,
        itemBuilder: (context, index) {
          final category = _mainCategories[index];
          final isSelected = _selectedMainCategoryId == category.id;
          
          return InkWell(
            onTap: () {
              setState(() {
                _selectedMainCategoryId = category.id;
                _selectedSubCategoryId = null;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.transparent,
                border: Border(
                  right: BorderSide(
                    color: isSelected ? Colors.blue : Colors.grey[300]!,
                    width: isSelected ? 3 : 1,
                  ),
                ),
              ),
              child: Text(
                category.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.blue : Colors.black,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubCategoryContent() {
    final mainCategory = _selectedMainCategory;
    if (mainCategory == null) {
      return const Center(child: Text('카테고리�??�택?�주?�요.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 중분�??�션??
          ...mainCategory.subCategories.map((subCategory) {
            return _buildSubCategorySection(subCategory);
          }),
        ],
      ),
    );
  }

  Widget _buildSubCategorySection(SubCategory subCategory) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 중분�??�더
          Row(
            children: [
              Icon(
                _getCategoryIcon(subCategory.id),
                size: 24,
                color: Colors.blue,
              ),
              const SizedBox(width: 8),
              Text(
                subCategory.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // ?�분�?그리??(?�는 경우)
          if (subCategory.smallCategories.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 3,
              ),
              itemCount: subCategory.smallCategories.length,
              itemBuilder: (context, index) {
                final smallCategory = subCategory.smallCategories[index];
                return InkWell(
                  onTap: () {
                    // ?�분�??�택 ???�품 목록?�로 ?�동
                    _navigateToProductList(
                      mainCategoryId: _selectedMainCategoryId!,
                      subCategoryId: subCategory.id,
                      smallCategoryId: smallCategory.id,
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Center(
                      child: Text(
                        smallCategory.name,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              },
            )
          else
            // ?�분류�? ?�으�?중분류�? 직접 ?�릭 가?�하�?
            InkWell(
              onTap: () {
                _navigateToProductList(
                  mainCategoryId: _selectedMainCategoryId!,
                  subCategoryId: subCategory.id,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: const Center(
                  child: Text(
                    '?�체 보기',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String categoryId) {
    switch (categoryId) {
      case 'diet':
        return Icons.fitness_center;
      case 'detox':
        return Icons.cleaning_services;
      case 'mental':
        return Icons.psychology;
      case 'health':
        return Icons.health_and_safety;
      case 'beauty':
        return Icons.face;
      case 'hair':
        return Icons.content_cut;
      default:
        return Icons.category;
    }
  }

  void _navigateToProductList({
    required String mainCategoryId,
    required String subCategoryId,
    String? smallCategoryId,
  }) {
    // ?�품 목록 ?�면?�로 ?�동
    // TODO: ?�제 ?�비게이??구현
    print('카테고리 ?�택: $mainCategoryId > $subCategoryId ${smallCategoryId != null ? '> $smallCategoryId' : ''}');
  }
}

// ?�이??모델
class MainCategory {
  final String id;
  final String name;
  final List<SubCategory> subCategories;

  MainCategory({
    required this.id,
    required this.name,
    required this.subCategories,
  });
}

class SubCategory {
  final String id;
  final String name;
  final List<SmallCategory> smallCategories;

  SubCategory({
    required this.id,
    required this.name,
    required this.smallCategories,
  });
}

class SmallCategory {
  final String id;
  final String name;

  SmallCategory({
    required this.id,
    required this.name,
  });
}

