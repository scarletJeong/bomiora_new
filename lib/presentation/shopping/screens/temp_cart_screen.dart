import 'package:flutter/material.dart';

import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../data/models/cart/cart_item_model.dart';
import '../../../data/models/product/product_model.dart';
import '../../../data/repositories/product/product_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/cart_service.dart';
import '../../common/widgets/app_bar.dart';
import '../../common/widgets/login_required_dialog.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../widgets/recommend_product.dart';
import 'prescription_booking/prescription_profile_screen.dart';

class TempCartScreen extends StatefulWidget {
  const TempCartScreen({super.key});

  @override
  State<TempCartScreen> createState() => _TempCartScreenState();
}

class _TempCartScreenState extends State<TempCartScreen> {
  List<CartItem> _tempItems = [];
  List<Product> _recommendedProducts = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await Future.wait([
        CartService.getCart(ctStatus: '임시'),
        ProductRepository.getProductsByCategory(
          categoryId: '10',
          productKind: 'prescription',
          page: 1,
          pageSize: 100,
        ),
        ProductRepository.getProductsByCategory(
          categoryId: '20',
          productKind: 'prescription',
          page: 1,
          pageSize: 100,
        ),
        ProductRepository.getProductsByCategory(
          categoryId: '80',
          productKind: 'prescription',
          page: 1,
          pageSize: 100,
        ),
      ]);

      final tempResult = results[0] as Map<String, dynamic>;
      final diet = results[1] as List<Product>;
      final detox = results[2] as List<Product>;
      final calm = results[3] as List<Product>;
      final recommended = <Product>[...diet, ...detox, ...calm];

      if (tempResult['success'] == true) {
        final rawItems = tempResult['data'];
        final items = (rawItems is List ? rawItems : [])
            .whereType<Map>()
            .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        setState(() {
          _tempItems = items;
          _recommendedProducts = recommended;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = tempResult['message']?.toString() ?? '임시 장바구니 조회 실패';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '임시 장바구니를 불러오는 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  Future<bool> _ensureLoggedIn() async {
    final user = await AuthService.getUser();
    if (user != null && user.id.isNotEmpty) {
      return true;
    }
    if (user == null || user.id.isEmpty) {
      if (!mounted) return false;
      await showLoginRequiredDialog(context, message: '로그인 후 이용할 수 있습니다.');
    }
    return false;
  }

  Future<void> _removeItem(int ctId) async {
    final result = await CartService.removeCartItem(ctId);
    if (result['success'] == true) {
      await _loadData();
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? '삭제 실패')),
    );
  }

  Future<void> _updateQuantity(CartItem item, int quantity) async {
    if (quantity < 1) return;
    final result = await CartService.updateCartQuantity(
      ctId: item.ctId,
      quantity: quantity,
    );
    if (result['success'] == true) {
      await _loadData();
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message']?.toString() ?? '수량 변경 실패')),
    );
  }

  bool _isGeneralKind(String kind) =>
      kind.trim().toLowerCase() == 'general';

  List<Map<String, dynamic>> _selectedOptionsFromPrescItems(
      List<CartItem> items) {
    return items
        .map(
          (item) => <String, dynamic>{
            'it_id': item.itId,
            'it_name': item.itName,
            'id': item.ioId ?? '',
            'name': item.ctOption.isNotEmpty ? item.ctOption : item.itName,
            'price': item.ioPrice ?? 0,
            'quantity': item.ctQty,
            'totalPrice': item.ctPrice,
            'ct_kind': item.ctKind,
          },
        )
        .toList();
  }

  Future<void> _commitToCart() async {
    if (_tempItems.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      if (!await _ensureLoggedIn()) return;

      final generalItems =
          _tempItems.where((e) => _isGeneralKind(e.ctKind)).toList();
      final prescItems =
          _tempItems.where((e) => !_isGeneralKind(e.ctKind)).toList();
      if (!mounted) return;

      if (prescItems.isNotEmpty) {
        if (generalItems.isNotEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('처방 상품 예약을 먼저 진행합니다. 일반 상품은 임시 장바구니에 유지됩니다.'),
            ),
          );
        }
        await Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (context) => PrescriptionProfileScreen(
              productId: prescItems.first.itId,
              productName: prescItems.first.itName,
              selectedOptions: _selectedOptionsFromPrescItems(prescItems),
              tempCartCtIdsToClearOnSuccess:
                  prescItems.map((e) => e.ctId).toList(),
            ),
          ),
        );
        if (mounted) await _loadData();
        return;
      }

      int genSuccess = 0;
      int genFail = 0;
      for (final item in generalItems) {
        final addResult = await CartService.addToCart(
          productId: item.itId,
          quantity: item.ctQty,
          price: item.ctPrice,
          optionId: item.ioId,
          optionText: item.ctOption,
          optionPrice: item.ioPrice,
          odId: item.odId,
          ctKind: item.ctKind,
          ctStatus: '쇼핑',
        );
        if (addResult['success'] == true) {
          genSuccess++;
          await CartService.removeCartItem(item.ctId);
        } else {
          genFail++;
        }
      }

      if (!mounted) return;

      if (genFail > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('일반 상품 $genFail개를 장바구니로 옮기지 못했습니다.'),
          ),
        );
        await _loadData();
        return;
      }

      if (genSuccess > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('선택 항목을 장바구니에 담았습니다.')),
        );
        Navigator.pushReplacementNamed(context, '/cart');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  int get _totalPrice {
    return _tempItems.fold<int>(0, (sum, item) => sum + item.ctPrice);
  }

  String _imageUrl(CartItem item) {
    final normalized =
        ImageUrlHelper.normalizeThumbnailUrl(item.imageUrl, item.itId);
    return normalized ??
        '${ImageUrlHelper.imageBaseUrl}/data/item/${item.itId}/no_img.png';
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: const HealthAppBar(
        title: '진료 예약항목',
        centerTitle: true,
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_tempItems.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 36),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0x7FD2D2D2)),
                          ),
                          child: const Center(
                            child: Text(
                              '임시 장바구니가 비어 있습니다.',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF666666)),
                            ),
                          ),
                        ),
                      ..._tempItems.map(_buildTempItemCard),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _commitToCart,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF5A8D),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
                                  '처방 예약하기',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      RecommendProductSection(
                        excludedProductNames:
                            _tempItems.map((item) => item.itName).toList(),
                        products: _recommendedProducts,
                        hideWhenEmpty: true,
                        topSpacingBefore: 22,
                        onProductTap: (product) async {
                          await Navigator.pushNamed(
                              context, '/product/${product.id}');
                          if (mounted) {
                            _loadData();
                          }
                        },
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildTempItemCard(CartItem item) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0x7FD2D2D2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              InkWell(
                onTap: () => _removeItem(item.ctId),
                child: const Icon(Icons.close, size: 20),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  _imageUrl(item),
                  width: 87,
                  height: 87,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 87,
                    height: 87,
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.ctKind == 'prescription')
                      const Text(
                        '한의약품',
                        style: TextStyle(
                          color: Color(0xFF898686),
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    Text(
                      item.itName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.ctOption.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.ctOption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF898383),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text(
                          '수량',
                          style: TextStyle(
                            color: Color(0xFF1A1A1A),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F6F6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              _qtyButton(
                                icon: Icons.remove,
                                onTap: item.ctQty > 1
                                    ? () =>
                                        _updateQuantity(item, item.ctQty - 1)
                                    : null,
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                child: Text(
                                  '${item.ctQty}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              _qtyButton(
                                icon: Icons.add,
                                onTap: () =>
                                    _updateQuantity(item, item.ctQty + 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 12),
            padding: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: Color(0x7FD2D2D2), width: 0.5),
              ),
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                PriceFormatter.format(item.ctPrice),
                style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton({required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 1.07,
              offset: Offset(0, 0.54),
            )
          ],
        ),
        child: Icon(
          icon,
          size: 13,
          color: const Color(0xFFFF5A8D),
        ),
      ),
    );
  }
}
