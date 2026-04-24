import 'package:flutter/material.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../core/utils/node_value_parser.dart';
import '../../../../data/services/wish_service.dart';
import '../../../../data/services/content_service.dart';
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
  static const Color _divider = Color(0xFFD2D2D2);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _textMuted = Color(0xFF898686);
  static const Color _textSub = Color(0xFF898383);
  static const Color _chipFill = Color(0x0CFF5A8D);

  List<Map<String, dynamic>> _wishList = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _requiresLogin = false;
  int _visibleCount = 5;
  /// 0: 비대면 진료, 1: 스토어, 2: 콘텐츠
  int _selectedTabIndex = 0;

  /// 콘텐츠 찜 항목 메타 캐시 (bm_content)
  final Map<int, Map<String, dynamic>> _contentCache = {};
  final Set<int> _contentLoadingIds = {};

  /// API `it_kind` 기준 — 비대면: prescription, 스토어: general (우선 it_kind)
  String _itKindLower(Map<String, dynamic> item) {
    return (NodeValueParser.asString(item['wi_it_kind']) ??
            NodeValueParser.asString(item['it_kind']) ??
            NodeValueParser.asString(item['product_kind']) ??
            NodeValueParser.asString(item['productKind']) ??
            NodeValueParser.asString(item['ct_kind']) ??
            '')
        .toLowerCase()
        .trim();
  }

  List<Map<String, dynamic>> get _telemedWishes => _wishList
      .where((e) => !_isContentWish(e) && _itKindLower(e) == 'prescription')
      .toList();

  /// 스토어: `general` + `it_kind` 비어 있음 + 그 외 prescription·콘텐츠가 아닌 상품(폴백)
  /// API에 `it_kind`가 없으면 여기로 모여 목록이 비지 않도록 함
  List<Map<String, dynamic>> get _storeWishes => _wishList
      .where((e) => !_isContentWish(e) && _itKindLower(e) != 'prescription')
      .toList();

  List<Map<String, dynamic>> get _contentWishes =>
      _wishList.where(_isContentWish).toList();

  List<Map<String, dynamic>> get _currentTabList {
    switch (_selectedTabIndex) {
      case 0:
        return _telemedWishes;
      case 1:
        return _storeWishes;
      case 2:
        return _contentWishes;
      default:
        return [];
    }
  }

  /// 콘텐츠 찜 — `wi_it_kind`·`product_kind` 또는 wish_type / wr_id / content_id
  bool _isContentWish(Map<String, dynamic> item) {
    if (_itKindLower(item) == 'content') return true;
    final wt = NodeValueParser.asString(item['wish_type']) ??
        NodeValueParser.asString(item['item_type']) ??
        '';
    if (wt.toLowerCase().contains('content')) return true;
    if (item['wr_id'] != null &&
        '${item['wr_id']}'.trim().isNotEmpty &&
        '${item['wr_id']}' != '0') {
      return true;
    }
    if (item['content_id'] != null &&
        '${item['content_id']}'.trim().isNotEmpty &&
        '${item['content_id']}' != '0') {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadWishList();
  }

  void _syncVisibleCount() {
    final n = _currentTabList.length;
    _visibleCount = n < 5 ? n : 5;
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

      final list = raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      setState(() {
        _wishList = list;
        _isLoading = false;
        _syncVisibleCount();
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
      final len = _currentTabList.length;
      if (_visibleCount > len) {
        _visibleCount = len;
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
    final list = _currentTabList;
    if (list.isEmpty) return [];
    final end = _visibleCount > list.length ? list.length : _visibleCount;
    return list.sublist(0, end);
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

  String _emptyMessageForTab() {
    switch (_selectedTabIndex) {
      case 0:
        return '비대면 진료 찜 상품이 없습니다.';
      case 1:
        return '스토어 찜 상품이 없습니다.';
      case 2:
        return '찜한 콘텐츠가 없습니다.';
      default:
        return '찜한 항목이 없습니다.';
    }
  }

  Widget _buildContent() {
    final list = _currentTabList;
    final hasMore = _visibleCount < list.length;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 27, right: 27, bottom: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          _buildTabs(),
          const SizedBox(height: 20),
          _buildHeader(),
          const SizedBox(height: 20),
          if (list.isEmpty) ...[
            const SizedBox(height: 40),
            Icon(Icons.favorite_border, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _emptyMessageForTab(),
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
          ] else ...[
            ..._visibleItems.map(_buildWishCard),
            if (hasMore) ...[
              const SizedBox(height: 20),
              _buildLoadMoreButton(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTabs() {
    const sepW = 0.5;

    Widget vSep() => Container(
          width: sepW,
          height: 11,
          color: _divider,
        );

    Widget tabCell({
      required int index,
      required String label,
    }) {
      final selected = _selectedTabIndex == index;
      return GestureDetector(
        onTap: () => setState(() {
          _selectedTabIndex = index;
          _syncVisibleCount();
        }),
        behavior: HitTestBehavior.opaque,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.only(top: 4, bottom: 10),
          alignment: Alignment.center,
          child: Center(
            // 탭 영역은 Expanded로 넓게 유지하되, underline은 텍스트 폭만큼만 그려지게.
            child: IntrinsicWidth(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? _pink : _textSub,
                      fontSize: 14,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    height: 1,
                    color: selected ? _pink : Colors.transparent,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: tabCell(index: 0, label: '비대면 진료')),
        vSep(),
        Expanded(child: tabCell(index: 1, label: '스토어')),
        vSep(),
        Expanded(child: tabCell(index: 2, label: '콘텐츠')),
      ],
    );
  }

  Widget _buildHeader() {
    final count = _currentTabList.length;
    final title = switch (_selectedTabIndex) {
      0 => '찜한 상품 $count개',
      1 => '찜한 상품 $count개',
      2 => '찜한 목록 $count개',
      _ => '찜한 항목 $count개',
    };
    return SizedBox(
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
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
    if (_isContentWish(item)) {
      return _buildContentWishCard(item);
    }

    final productId = item['it_id']?.toString() ?? '';
    final productName = item['product_name']?.toString() ??
        item['it_name']?.toString() ??
        '';
    final subject = item['it_subject']?.toString() ?? '';
    final descriptionLine = (item['it_basic']?.toString() ?? '').trim();
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
                          Text(
                            subject.trim().isNotEmpty ? subject.trim() : '보미오라',
                            style: const TextStyle(
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
                          if (descriptionLine.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              descriptionLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: _textSub,
                                fontSize: 12,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w500,
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

  int? _contentIdFromWish(Map<String, dynamic> item) {
    final raw = item['content_id'] ?? item['wr_id'] ?? item['it_id'] ?? item['itId'];
    if (raw is num) return raw.toInt();
    return int.tryParse('${raw ?? ''}');
  }

  void _ensureContentLoaded(int contentId) {
    if (_contentCache.containsKey(contentId)) return;
    if (_contentLoadingIds.contains(contentId)) return;
    _contentLoadingIds.add(contentId);
    Future.microtask(() async {
      try {
        final r = await ContentService.getContentDetail(contentId);
        final data = (r['data'] is Map) ? Map<String, dynamic>.from(r['data'] as Map) : <String, dynamic>{};
        if (!mounted) return;
        setState(() {
          _contentCache[contentId] = data;
        });
      } finally {
        _contentLoadingIds.remove(contentId);
      }
    });
  }

  Widget _buildContentWishCard(Map<String, dynamic> item) {
    final contentId = _contentIdFromWish(item);
    final idStr = contentId?.toString() ?? (item['it_id']?.toString() ?? '');
    final cached = contentId != null ? _contentCache[contentId] : null;
    if (contentId != null) {
      _ensureContentLoaded(contentId);
    }

    final category = (cached?['category'] ?? item['category'] ?? '').toString().trim();
    final title = (cached?['title'] ?? item['title'] ?? '').toString().trim();
    final thumbRaw = (cached?['thumbnail'] ?? cached?['thumbnail_url'] ?? item['thumbnail'] ?? item['thumbnail_url'])
        ?.toString();
    final imageUrl = ContentService.resolveThumbnailUrl(
      thumbRaw,
      fallback: 'https://placehold.co/321x200',
    );

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
                onTap: contentId == null
                    ? null
                    : () {
                        Navigator.pushNamed(
                          context,
                          '/content/detail',
                          arguments: {'id': contentId},
                        );
                      },
                behavior: HitTestBehavior.opaque,
                child: AspectRatio(
                  aspectRatio: 1.4,
                  child: Image.network(
                    imageUrl,
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
                      onTap: contentId == null
                          ? null
                          : () {
                              Navigator.pushNamed(
                                context,
                                '/content/detail',
                                arguments: {'id': contentId},
                              );
                            },
                      behavior: HitTestBehavior.opaque,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            category.isNotEmpty ? category : '콘텐츠',
                            style: const TextStyle(
                              color: _textMain,
                              fontSize: 12,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            title.isNotEmpty ? title : '제목 없음',
                            style: const TextStyle(
                              color: _textMain,
                              fontSize: 16,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w700,
                              letterSpacing: -1.44,
                              height: 1.25,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: idStr.isEmpty ? null : () => _removeWishItem(idStr),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          decoration: ShapeDecoration(
                            color: const Color(0x0CFF5A8D),
                            shape: RoundedRectangleBorder(
                              side: const BorderSide(width: 1, color: Color(0xFFFF5A8D)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Center(
                                  child: Icon(
                                    Icons.favorite,
                                    size: 20,
                                    color: const Color(0xFFFF5A8D),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 5),
                              const Text(
                                '찜 해제',
                                style: TextStyle(
                                  color: Color(0xFFFF5A8D),
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
