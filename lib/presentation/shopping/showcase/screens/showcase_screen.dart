import 'package:flutter/material.dart';
import '../../../../data/models/product/product_model.dart';
import '../../../../data/repositories/product/product_repository.dart';
import '../../screens/product_detail_screen.dart';
import '../../../common/widgets/app_footer.dart';

class ShowcaseScreen extends StatefulWidget {
  const ShowcaseScreen({super.key});

  @override
  State<ShowcaseScreen> createState() => _ShowcaseScreenState();
}

class _ShowcaseScreenState extends State<ShowcaseScreen> {
  List<Product> _dietProducts = [];
  List<Product> _detoxProducts = [];
  List<Product> _calmProducts = [];
  List<Product> _dietSupplementProducts = [];
  
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 카테고리별 제품 로드
      final dietFuture = ProductRepository.getProductsByCategory(
        categoryId: '10',
        productKind: 'prescription',
        page: 1,
        pageSize: 50,
      );
      final detoxFuture = ProductRepository.getProductsByCategory(
        categoryId: '20',
        productKind: 'prescription',
        page: 1,
        pageSize: 50,
      );
      final calmFuture = ProductRepository.getProductsByCategory(
        categoryId: '80',
        productKind: 'prescription',
        page: 1,
        pageSize: 50,
      );
      final dietSupplementFuture = ProductRepository.getProductsByCategory(
        categoryId: '10',
        productKind: 'general',
        page: 1,
        pageSize: 50,
      );

      final results = await Future.wait([dietFuture, detoxFuture, calmFuture, dietSupplementFuture]);

      if (!mounted) return;

      setState(() {
        _dietProducts = results[0];
        _detoxProducts = results[1];
        _calmProducts = results[2];
        _dietSupplementProducts = results[3];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _errorMessage = '제품을 불러오는데 실패했습니다: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadProducts,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            
            // 다이어트환 섹션
            _buildProductSection(
              title: '다이어트환',
              subtitle: '건강한 다이어트를 위한 맞춤 처방',
              products: _dietProducts,
              color: const Color(0xFFFFE5F0),
            ),
            
            const SizedBox(height: 24),
            
            // 디톡스환 섹션
            _buildProductSection(
              title: '디톡스환',
              subtitle: '장운동과 독소배출을 위한 처방',
              products: _detoxProducts,
              color: const Color(0xFFE8F5E9),
            ),
            
            const SizedBox(height: 24),
            
            // 심신안정 섹션
            _buildProductSection(
              title: '심신안정',
              subtitle: '불안, 스트레스 개선을 위한 마음케어 처방',
              products: _calmProducts,
              color: const Color(0xFFE3F2FD),
            ),
            
            const SizedBox(height: 24),
            
            // 다이어트 보조제 섹션
            _buildProductSection(
              title: '다이어트 보조제',
              subtitle: '다이어트를 도와주는 건강 보조 식품',
              products: _dietSupplementProducts,
              color: const Color(0xFFFFF3E0),
            ),
            
            const SizedBox(height: 300),
            
            // Footer
            const AppFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildProductSection({
    required String title,
    required String subtitle,
    required List<Product> products,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 섹션 헤더
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 12),
        
        // 제품 목록 (가로 스크롤)
        if (products.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text(
                '제품이 없습니다.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
            ),
          )
        else
          SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: products.length,
              itemBuilder: (context, index) {
                return _buildProductCard(products[index], color);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildProductCard(Product product, Color backgroundColor) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          '/product/${product.id}',
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Card(
          elevation: 2,
          color: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 제품 이미지
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: product.imageUrl != null && product.imageUrl!.isNotEmpty
                      ? Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey[200],
                              child: Icon(
                                Icons.image_not_supported,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.grey[200],
                          child: Icon(
                            Icons.image,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                        ),
                ),
              ),
              
              // 제품 정보
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 제품명
                    Text(
                      product.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    
                    // 가격
                    Row(
                      children: [
                        if ((product.discountRate ?? 0) > 0) ...[
                          Text(
                            '${product.discountRate!.toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF3787),
                            ),
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            '${_formatPrice(product.price)}원',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    
                    if ((product.discountRate ?? 0) > 0 && product.originalPrice != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${_formatPrice(product.originalPrice!)}원',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPrice(int price) {
    return price.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}

