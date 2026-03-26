import 'package:flutter/material.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../data/services/wish_service.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/app_footer.dart';

class WishListScreen extends StatefulWidget {
  const WishListScreen({super.key});

  @override
  State<WishListScreen> createState() => _WishListScreenState();
}

class _WishListScreenState extends State<WishListScreen> {
  static const int _initialLimit = 10;

  List<dynamic> _wishList = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadWishList();
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
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '\uCC1C \uBAA9\uB85D\uC744 \uBD88\uB7EC\uC624\uB294\uB370 \uC2E4\uD328\uD588\uC2B5\uB2C8\uB2E4: $e';
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
          content: Text('\uCC1C \uBAA9\uB85D\uC5D0\uC11C \uC0AD\uC81C\uB418\uC5C8\uC2B5\uB2C8\uB2E4.'),
          duration: Duration(seconds: 2),
        ),
      );
      _loadWishList();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('\uC0AD\uC81C \uC2E4\uD328: $e'),
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
          '\uCC1C\uBAA9\uB85D',
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
      child: _buildBody(),
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
              child: const Text('\uB2E4\uC2DC \uC2DC\uB3C4'),
            ),
          ],
        ),
      );
    }

    if (_wishList.isEmpty) {
      return SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 100),
            Icon(
              Icons.favorite_border,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '\uCC1C\uD55C \uC0C1\uD488\uC774 \uC5C6\uC2B5\uB2C8\uB2E4.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 300),
            const AppFooter(),
          ],
        ),
      );
    }

    final displayedItems = _wishList.take(_initialLimit).toList();
    final rowCount = displayedItems.length * 2 - 1;

    return RefreshIndicator(
      onRefresh: _loadWishList,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index.isOdd) {
                    return Divider(height: 1, color: Colors.grey[200]);
                  }
                  final item = displayedItems[index ~/ 2];
                  return _buildWishRow(item);
                },
                childCount: rowCount,
              ),
            ),
          ),
          const SliverToBoxAdapter(
            child: Column(
              children: [
                SizedBox(height: 300),
                AppFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishRow(dynamic item) {
    final productId = item['it_id']?.toString() ?? '';
    final productName = item['product_name']?.toString() ?? '\uC0C1\uD488\uBA85 \uC5C6\uC74C';
    final productImage = item['image_url'] ?? item['it_img1'] ?? item['it_img'] ?? '';

    return InkWell(
      onTap: () {
        if (productId.isEmpty) return;
        Navigator.pushNamed(context, '/product/$productId');
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        color: Colors.white,
        child: Row(
          children: [
            Image.network(
              ImageUrlHelper.getImageUrl(productImage),
              width: 92,
              height: 92,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 92,
                  height: 92,
                  color: Colors.grey[200],
                  child: const Icon(Icons.image_not_supported, size: 24),
                );
              },
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                productName,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              onPressed: productId.isEmpty ? null : () => _removeWishItem(productId),
              icon: const Icon(Icons.favorite, size: 22),
              color: const Color(0xFFFF4081),
              tooltip: '\uCC1C \uD574\uC81C',
            ),
          ],
        ),
      ),
    );
  }
}
