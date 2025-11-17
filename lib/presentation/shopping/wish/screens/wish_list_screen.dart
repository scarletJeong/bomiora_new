import 'package:flutter/material.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../data/services/wish_service.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../screens/product_detail_screen.dart';

class WishListScreen extends StatefulWidget {
  const WishListScreen({super.key});

  @override
  State<WishListScreen> createState() => _WishListScreenState();
}

class _WishListScreenState extends State<WishListScreen> {
  List<dynamic> _wishList = [];
  List<dynamic> _filteredWishList = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _currentCategory = 'all';

  @override
  void initState() {
    super.initState();
    _loadWishList();
  }

  void _handleCategoryChange(String category) {
    setState(() {
      _currentCategory = category;
      _filterWishList();
    });
  }

  void _filterWishList() {
    if (_currentCategory == 'all') {
      _filteredWishList = _wishList;
    } else {
      _filteredWishList = _wishList.where((item) {
        final productKind = item['product_kind']?.toString() ?? '';
        if (_currentCategory == 'prescription') {
          return productKind == 'prescription';
        } else if (_currentCategory == 'product') {
          return productKind == 'general';
        }
        return false;
      }).toList();
    }
  }

  Future<void> _loadWishList() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final wishList = await WishService.getWishList();
      if (!mounted) return;
      
      setState(() {
        _wishList = wishList;
        _filterWishList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _errorMessage = '찜 목록을 불러오는데 실패했습니다: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _removeWishItem(String productId) async {
    try {
      await WishService.removeFromWish(productId);
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('찜 목록에서 삭제되었습니다.'),
          duration: Duration(seconds: 2),
        ),
      );
      _loadWishList();
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('삭제 실패: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: AppBar(
         centerTitle: true,
        title: const Text(
          '찜목록',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      child: Column(
        children: [
          _buildCategoryFilter(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Flexible(
            child: _buildRadioButton('전체', 'all'),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: _buildRadioButton('비대면 진료', 'prescription'),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: _buildRadioButton('제품', 'product'),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioButton(String label, String value) {
    final isSelected = _currentCategory == value;
    return GestureDetector(
      onTap: () => _handleCategoryChange(value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.black : Colors.grey[400]!,
                width: isSelected ? 5 : 2,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? Colors.black : Colors.grey[700],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
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
              onPressed: _loadWishList,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_filteredWishList.isEmpty) {
      String emptyMessage = '찜한 상품이 없습니다.';
      if (_currentCategory == 'prescription') {
        emptyMessage = '찜한 비대면 진료가 없습니다.';
      } else if (_currentCategory == 'product') {
        emptyMessage = '찜한 제품이 없습니다.';
      }
      
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.7,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _filteredWishList.length,
      itemBuilder: (context, index) {
        final item = _filteredWishList[index];
        return _buildWishItem(item);
      },
    );
  }

  Widget _buildWishItem(dynamic item) {
    final productId = item['it_id'] ?? '';
    final productName = item['product_name'] ?? '';
    final productPrice = item['product_price']?.toString() ?? '0';
    final productImage = item['image_url'] ?? item['it_img1'] ?? item['it_img'] ?? '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Stack(
        children: [
          InkWell(
            onTap: () {
              Navigator.pushNamed(
                context,
                '/product/$productId',
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상품 이미지
                AspectRatio(
                  aspectRatio: 1.0,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                    child: Image.network(
                      ImageUrlHelper.getImageUrl(productImage),
                      fit: BoxFit.cover,
                      cacheWidth: 300,
                      cacheHeight: 300,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.image_not_supported, size: 40),
                        );
                      },
                    ),
                  ),
                ),
                
                // 상품 정보
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        productName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${_formatPrice(productPrice)}원',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // 삭제 버튼 (오른쪽 상단)
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('찜 삭제'),
                      content: const Text('찜 목록에서 삭제하시겠습니까?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('취소'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            _removeWishItem(productId);
                          },
                          child: const Text(
                            '삭제',
                            style: TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: Colors.black54,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(String price) {
    try {
      final number = int.parse(price);
      return number.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (Match m) => '${m[1]},',
          );
    } catch (e) {
      return price;
    }
  }
}

