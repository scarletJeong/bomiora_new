import 'package:flutter/material.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../data/services/wish_service.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/app_bar.dart';

class WishListScreen extends StatefulWidget {
  const WishListScreen({super.key});

  @override
  State<WishListScreen> createState() => _WishListScreenState();
}

class _WishListScreenState extends State<WishListScreen> {
  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _border = Color(0x7FD2D2D2);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _textMuted = Color(0xFF898686);
  static const Color _textSub = Color(0xFF898383);
  static const Color _chipFill = Color(0x0CFF5A8D);

  List<Map<String, dynamic>> _wishList = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _requiresLogin = false;
  int _visibleCount = 5;

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
      _requiresLogin = false;
    });

    try {
      final raw = await WishService.getWishList();
      if (!mounted) return;

      final list = raw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        _wishList = list;
        _visibleCount = list.length < 5 ? list.length : 5;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      setState(() {
        if (message.contains('로그인')) {
          _requiresLogin = true;
          _errorMessage = null;
        } else {
          _errorMessage = '찜 목록을 불러오는데 실패했습니다: $e';
        }
        _isLoading = false;
      });
    }
  }

  void _loadMore() {
    setState(() {
      _visibleCount += 5;
      if (_visibleCount > _wishList.length) {
        _visibleCount = _wishList.length;
      }
    });
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
      await _loadWishList();
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

  List<Map<String, dynamic>> get _visibleItems {
    if (_wishList.isEmpty) return [];
    final end = _visibleCount > _wishList.length ? _wishList.length : _visibleCount;
    return _wishList.sublist(0, end);
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: const HealthAppBar(
        title: '찜목록',
      ),
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
        child: ColoredBox(
          color: Colors.white,
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: _pink),
                )
              : _requiresLogin
                  ? _buildLoginMessage()
                  : _errorMessage != null
                  ? _buildError()
                  : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 27),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _loadWishList,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginMessage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.favorite_border, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            '로그인 후 이용 가능합니다.',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_wishList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              '찜한 상품이 없습니다.',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    final hasMore = _visibleCount < _wishList.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 27, right: 27, bottom: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          _buildHeader(),
          const SizedBox(height: 20),
          ..._visibleItems.map(_buildWishCard),
          if (hasMore) ...[
            const SizedBox(height: 20),
            _buildLoadMoreButton(),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      const Icon(Icons.favorite, size: 16, color: _textMain),
                      const SizedBox(width: 6),
                      const Text(
                        '찜목록',
                        style: TextStyle(
                          color: _textMain,
                          fontSize: 16,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '찜한 상품 ${_wishList.length}개',
                  style: const TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWishCard(Map<String, dynamic> item) {
    final productId = item['it_id']?.toString() ?? '';
    final productName = item['product_name']?.toString() ??
        item['it_name']?.toString() ??
        '';
    final description = item['it_basic']?.toString() ??
        item['it_explan']?.toString() ??
        item['product_description']?.toString() ??
        '';
    final productImage =
        item['image_url']?.toString() ?? item['it_img1']?.toString() ?? item['it_img']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SizedBox(
        width: double.infinity,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(width: 1, color: _border),
            borderRadius: BorderRadius.circular(10),
            color: Colors.white,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: productId.isEmpty
                    ? null
                    : () {
                        Navigator.pushNamed(context, '/product/$productId');
                      },
                behavior: HitTestBehavior.opaque,
                child: AspectRatio(
                  // 상품품 이미지 카드 높이 비율
                  aspectRatio: 1.4,
                  child: Image.network(
                    ImageUrlHelper.getImageUrl(productImage),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey[100],
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _pink,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10, left: 10, right: 10, bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: productId.isEmpty
                          ? null
                          : () {
                              Navigator.pushNamed(context, '/product/$productId');
                            },
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '보미오라',
                            style: TextStyle(
                              color: _textMain,
                              fontSize: 12,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            productName.isNotEmpty ? productName : '상품',
                            style: const TextStyle(
                              color: _textMain,
                              fontSize: 16,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.44,
                              height: 1.25,
                            ),
                          ),
                          if (description.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              description,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _textSub,
                                fontSize: 12,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w500,
                                height: 1.35,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: productId.isEmpty ? null : () => _removeWishItem(productId),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          decoration: ShapeDecoration(
                            color: _chipFill,
                            shape: RoundedRectangleBorder(
                              side: const BorderSide(width: 1, color: _pink),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.favorite, size: 24, color: _pink.withValues(alpha: 0.9)),
                              const SizedBox(width: 5),
                              const Text(
                                '찜 해제',
                                style: TextStyle(
                                  color: _pink,
                                  fontSize: 12,
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: OutlinedButton(
        onPressed: _loadMore,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(width: 0.5, color: Color(0xFFD2D2D2)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Colors.white,
          padding: const EdgeInsets.all(10),
        ),
        child: const Text(
          '더보기',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textMuted,
            fontSize: 16,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
