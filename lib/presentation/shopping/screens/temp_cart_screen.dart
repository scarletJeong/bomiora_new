import 'package:flutter/material.dart';

import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../data/models/cart/cart_item_model.dart';
import '../../../data/models/product/product_model.dart';
import '../../../data/repositories/product/product_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/cart_service.dart';
import '../../common/widgets/login_required_dialog.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../widgets/recommend_product.dart';
import 'prescription_booking/prescription_profile_screen.dart';

const String _kGmarketSans = 'Gmarket Sans TTF';

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
  Set<int> _selectedItems = {};
  bool _selectAll = true;

  Set<int> get _itemIds => _tempItems.map((item) => item.ctId).toSet();

  void _syncSelectionAfterLoad(List<CartItem> items) {
    final existingIds = items.map((e) => e.ctId).toSet();
    _selectedItems = _selectedItems.where(existingIds.contains).toSet();
    if (_selectAll) {
      _selectedItems.addAll(existingIds);
    }
    _selectAll = items.isNotEmpty &&
        existingIds.difference(_selectedItems).isEmpty;
  }

  List<CartItem> get _selectedTempItems => _tempItems
      .where((item) => _selectedItems.contains(item.ctId))
      .toList();

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
          _syncSelectionAfterLoad(items);
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
      if (mounted) {
        setState(() => _selectedItems.remove(ctId));
      }
      await _loadData();
      return;
    }
  }

  Future<void> _deleteSelectedItems() async {
    if (_selectedItems.isEmpty) return;

    final itemsToDelete = List<int>.from(_selectedItems);
    for (final ctId in itemsToDelete) {
      await CartService.removeCartItem(ctId);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${itemsToDelete.length}개 상품 삭제 완료'),
        duration: const Duration(seconds: 2),
      ),
    );
    await _loadData();
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
    final selectedItems = _selectedTempItems;
    if (selectedItems.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try {
      if (!await _ensureLoggedIn()) return;

      final generalItems =
          selectedItems.where((e) => _isGeneralKind(e.ctKind)).toList();
      final prescItems =
          selectedItems.where((e) => !_isGeneralKind(e.ctKind)).toList();
      if (!mounted) return;

      if (prescItems.isNotEmpty) {
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
        await _loadData();
        return;
      }

      if (genSuccess > 0) {
        Navigator.pushReplacementNamed(context, '/cart');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
        title: '진료 예약 항목',
        centerTitle: false,
      ),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(fontSize: healthSp(context, 14)),
                  ),
                )
              : SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    healthDp(context, 27),
                    healthDp(context, 20),
                    healthDp(context, 27),
                    healthDp(context, 20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_tempItems.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.symmetric(
                            vertical: healthDp(context, 10),
                          ),
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(healthDp(context, 10)),
                            border: Border.all(
                              color: const Color(0x7FD2D2D2),
                              width: healthDp(context, 1),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '임시 장바구니가 비어 있습니다.',
                              style: TextStyle(
                                fontSize: healthSp(context, 12),
                                color: const Color(0xFF666666),
                                fontFamily: _kGmarketSans,
                              ),
                            ),
                          ),
                        ),
                      if (_tempItems.isNotEmpty) ...[
                        _buildSelectAllRow(),
                        ..._tempItems.map(_buildTempItemCard),
                        SizedBox(height: healthDp(context, 10)),
                        SizedBox(
                          width: double.infinity,
                          height: healthDp(context, 40),
                          child: ElevatedButton(
                            onPressed: _selectedTempItems.isEmpty || _isSubmitting
                                ? null
                                : _commitToCart,
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(
                                double.infinity,
                                healthDp(context, 40),
                              ),
                              maximumSize: Size(
                                double.infinity,
                                healthDp(context, 40),
                              ),
                              padding: EdgeInsets.zero,
                              backgroundColor: const Color(0xFFFF5A8D),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(healthDp(context, 10)),
                              ),
                              disabledBackgroundColor: Colors.grey[300],
                            ),
                            child: _isSubmitting
                                ? SizedBox(
                                    height: healthDp(context, 18),
                                    width: healthDp(context, 18),
                                    child: CircularProgressIndicator(
                                      strokeWidth: healthDp(context, 2),
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    '처방 예약 하기',
                                    style: TextStyle(
                                      fontSize: healthSp(context, 16),
                                      fontWeight: FontWeight.w500,
                                      fontFamily: _kGmarketSans,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                      SizedBox(height: healthDp(context, 10)),
                      RecommendProductSection(
                        excludedProductNames:
                            _tempItems.map((item) => item.itName).toList(),
                        products: _recommendedProducts,
                        hideWhenEmpty: true,
                        useGrid2: true,
                        topSpacingBefore: healthDp(context, 22),
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

  Widget _buildSelectAllRow() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(bottom: healthDp(context, 8)),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[300]!,
            width: healthDp(context, 1),
          ),
        ),
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _lightCheckbox(
                value: _tempItems.isNotEmpty &&
                    _itemIds.difference(_selectedItems).isEmpty,
                onChanged: (bool? value) {
                  setState(() {
                    final shouldSelect = value ?? false;
                    if (shouldSelect) {
                      _selectedItems.addAll(_itemIds);
                    } else {
                      _selectedItems.removeAll(_itemIds);
                    }
                    _selectAll = _tempItems.isNotEmpty &&
                        _itemIds.difference(_selectedItems).isEmpty;
                  });
                },
              ),
              SizedBox(width: healthDp(context, 4)),
              Text(
                '전체선택',
                style: TextStyle(
                  fontSize: healthSp(context, 13),
                  fontFamily: _kGmarketSans,
                  fontWeight: FontWeight.w300,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const Spacer(),
          TextButton(
            onPressed:
                _selectedItems.isEmpty ? null : _deleteSelectedItems,
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: healthDp(context, 8),
                vertical: healthDp(context, 4),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '선택삭제',
              style: TextStyle(
                fontSize: healthSp(context, 12),
                fontFamily: _kGmarketSans,
                fontWeight: FontWeight.w300,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lightCheckbox({
    required bool value,
    required ValueChanged<bool?> onChanged,
  }) {
    const double checkboxBase = 18;
    final boxSize = healthDp(context, checkboxBase);
    final scale = boxSize / checkboxBase;

    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: Center(
        child: Transform.scale(
          scale: scale,
          child: Theme(
            data: Theme.of(context).copyWith(
              checkboxTheme: CheckboxThemeData(
                side: BorderSide(
                  color: const Color(0xFFD2D2D2),
                  width: healthDp(context, 1),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 4)),
                ),
              ),
            ),
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: const Color(0xFFFF5A8D),
              checkColor: Colors.white,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTempItemCard(CartItem item) {
    final isSelected = _selectedItems.contains(item.ctId);
    final thumbSize = healthDp(context, 87);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: healthDp(context, 10)),
      padding: EdgeInsets.all(healthDp(context, 10)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
        border: Border.all(
          color: const Color(0x7FD2D2D2),
          width: healthDp(context, 1),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: healthDp(context, 20),
                height: healthDp(context, 20),
                child: Center(
                  child: _lightCheckbox(
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value ?? false) {
                          _selectedItems.add(item.ctId);
                        } else {
                          _selectedItems.remove(item.ctId);
                        }
                        _selectAll = _tempItems.isNotEmpty &&
                            _itemIds.difference(_selectedItems).isEmpty;
                      });
                    },
                  ),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _removeItem(item.ctId),
                borderRadius: BorderRadius.circular(healthDp(context, 4)),
                child: Icon(
                  Icons.close,
                  size: healthDp(context, 20),
                  color: const Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(healthDp(context, 4)),
                child: Image.network(
                  _imageUrl(item),
                  width: thumbSize,
                  height: thumbSize,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: thumbSize,
                    height: thumbSize,
                    color: Colors.grey[200],
                    child: Icon(
                      Icons.image_not_supported,
                      size: healthDp(context, 24),
                    ),
                  ),
                ),
              ),
              SizedBox(width: healthDp(context, 14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.ctKind == 'prescription')
                      Text(
                        '한의약품',
                        style: TextStyle(
                          color: const Color(0xFF898686),
                          fontSize: healthSp(context, 8),
                          fontWeight: FontWeight.w500,
                          fontFamily: _kGmarketSans,
                        ),
                      ),
                    Text(
                      item.itName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: const Color(0xFF1A1A1A),
                        fontSize: healthSp(context, 14),
                        fontWeight: FontWeight.w500,
                        fontFamily: _kGmarketSans,
                      ),
                    ),
                    if (item.ctOption.isNotEmpty) ...[
                      SizedBox(height: healthDp(context, 4)),
                      Text(
                        item.ctOption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF898383),
                          fontSize: healthSp(context, 10),
                          fontWeight: FontWeight.w500,
                          fontFamily: _kGmarketSans,
                        ),
                      ),
                    ],
                    SizedBox(height: healthDp(context, 8)),
                    Row(
                      children: [
                        Text(
                          '수량',
                          style: TextStyle(
                            color: const Color(0xFF1A1A1A),
                            fontSize: healthSp(context, 14),
                            fontWeight: FontWeight.w500,
                            fontFamily: _kGmarketSans,
                          ),
                        ),
                        SizedBox(width: healthDp(context, 8)),
                        Container(
                          padding: EdgeInsets.all(healthDp(context, 4)),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF6F6F6),
                            borderRadius:
                                BorderRadius.circular(healthDp(context, 20)),
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
                                padding: EdgeInsets.symmetric(
                                  horizontal: healthDp(context, 6),
                                ),
                                child: Text(
                                  '${item.ctQty}',
                                  style: TextStyle(
                                    fontSize: healthSp(context, 12),
                                    fontWeight: FontWeight.w600,
                                    fontFamily: _kGmarketSans,
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
            margin: EdgeInsets.only(top: healthDp(context, 12)),
            padding: EdgeInsets.only(top: healthDp(context, 12)),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: const Color(0x7FD2D2D2),
                  width: healthDp(context, 0.5),
                ),
              ),
            ),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                PriceFormatter.format(item.ctPrice),
                style: TextStyle(
                  color: const Color(0xFF1A1A1A),
                  fontSize: healthSp(context, 16),
                  fontWeight: FontWeight.w500,
                  fontFamily: _kGmarketSans,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qtyButton({required IconData icon, VoidCallback? onTap}) {
    final buttonSize = healthDp(context, 20);
    final buttonRadius = healthDp(context, 10);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(buttonRadius),
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(buttonRadius),
          boxShadow: [
            BoxShadow(
              color: const Color(0x0C000000),
              blurRadius: healthDp(context, 1.07),
              offset: Offset(0, healthDp(context, 0.54)),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: healthDp(context, 13),
          color: onTap == null
              ? Colors.grey[300]
              : const Color(0xFFFF5A8D),
        ),
      ),
    );
  }
}
