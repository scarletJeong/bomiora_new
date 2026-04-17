import 'package:flutter/material.dart';

import '../../../../data/services/content_service.dart';
import '../../../../data/services/category_service.dart';
import '../../../common/widgets/app_bar.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../widgets/content_bottom_nav_bar.dart';

/// 콘텐츠 목록 (카테고리 칩, 검색, 리스트, 글쓰기 FAB)
class ContentListScreen extends StatefulWidget {
  const ContentListScreen({super.key});

  @override
  State<ContentListScreen> createState() => _ContentListScreenState();
}

class _ContentListScreenState extends State<ContentListScreen> {
  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _textMuted = Color(0xFF898686);
  static const Color _pink = Color(0xFFFF5B8C);
  static const Color _chipInactive = Color(0xFF898686);

  int _tabIndex = 0;
  bool _appliedRouteCategory = false;
  String? _requestedCategoryName;
  late final Future<List<String>> _categoriesFuture = _loadCategories();
  final TextEditingController _searchController = TextEditingController();
  List<String> _categories = const [];
  List<Map<String, dynamic>> _posts = const [];
  int _totalCount = 0;
  bool _isLoading = true;

  Future<List<String>> _loadCategories() async {
    final result = await CategoryService.getCategoriesByGroup('content');
    final dynamic list = result['categories'];
    if (result['success'] == true && list is List && list.isNotEmpty) {
      final categories = list
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (categories.isNotEmpty) {
        return categories;
      }
    }
    return const [];
  }

  @override
  void initState() {
    super.initState();
    _categoriesFuture.then((categories) {
      if (!mounted) return;
      setState(() {
        _categories = categories;
      });
      _applyRequestedCategory();
      _loadPosts();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appliedRouteCategory) return;
    _appliedRouteCategory = true;
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic>) {
      final selectedCategory = args['category']?.toString().trim();
      if (selectedCategory != null && selectedCategory.isNotEmpty) {
        _requestedCategoryName = selectedCategory;
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _applyRequestedCategory() {
    if (_requestedCategoryName == null) return;
    final index = _categories.indexOf(_requestedCategoryName!);
    if (index >= 0) {
      _tabIndex = index + 1;
    }
    _requestedCategoryName = null;
  }

  Future<void> _loadPosts() async {
    setState(() => _isLoading = true);
    final selectedCategory = (_tabIndex > 0 && _tabIndex - 1 < _categories.length)
        ? _categories[_tabIndex - 1]
        : null;
    final result = await ContentService.getContentList(
      size: 50,
      category: selectedCategory,
      query: _searchController.text,
    );
    if (!mounted) return;
    final data = (result['data'] as List?)?.whereType<Map<String, dynamic>>().toList() ??
        const <Map<String, dynamic>>[];
    final pagination = result['pagination'] as Map<String, dynamic>? ?? const {};
    final total = pagination['total'] is num
        ? (pagination['total'] as num).toInt()
        : data.length;
    setState(() {
      _posts = data;
      _totalCount = total;
      _isLoading = false;
    });
  }

  Future<void> _onSearchSubmitted() async {
    await _loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: const HealthAppBar(
        title: '건강 콘텐츠',
        centerTitle: true,
        leadingType: HealthAppBarLeadingType.back,
      ),
      backgroundColor: Colors.white,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCategoryChips(_categories),
                      const SizedBox(height: 10),
                      _buildSearchBox(),
                      const SizedBox(height: 10),
                      _buildCountRow(),
                      const SizedBox(height: 10),
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFFFF5B8C),
                            ),
                          ),
                        )
                      else if (_posts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              '게시글이 없습니다.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _textMuted,
                                fontSize: 14,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        )
                      else
                        ..._posts.map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: _buildListCard(context, e),
                            )),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
              const ContentBottomNavBar(),
            ],
          ),
          Positioned(
            right: 20,
            bottom: 53 + 16,
            child: _WriteFab(onTap: () {}),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(List<String> categories) {
    final tabs = ['전체', ...categories];
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 5),
        itemBuilder: (context, i) {
          final selected = i == _tabIndex;
          return GestureDetector(
            onTap: () async {
              setState(() => _tabIndex = i);
              await _loadPosts();
            },
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: selected ? 10 : 5, vertical: selected ? 2 : 4),
              decoration: ShapeDecoration(
                color: selected ? _pink : Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              alignment: Alignment.center,
              child: Text(
                tabs[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : _chipInactive,
                  fontSize: selected ? 14 : 12,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                  height: selected ? 1.43 : 1.67,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: Color(0xFFD2D2D2)),
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              onSubmitted: (_) => _onSearchSubmitted(),
              decoration: const InputDecoration(
                hintText: '검색',
                hintStyle: TextStyle(
                  color: _textMuted,
                  fontSize: 14,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w300,
                ),
                border: InputBorder.none,
              ),
              style: const TextStyle(
                color: _textDark,
                fontSize: 14,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          IconButton(
            onPressed: _onSearchSubmitted,
            icon: const Icon(Icons.search, size: 18, color: _textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildCountRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: const Color(0x7FD2D2D2)),
        const SizedBox(height: 5),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '총 ',
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 12,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextSpan(
                text: '$_totalCount',
                style: const TextStyle(
                  color: Color(0xFFFF5A8D),
                  fontSize: 12,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: '건',
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 12,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Container(height: 1, color: const Color(0x7FD2D2D2)),
      ],
    );
  }

  Widget _buildListCard(BuildContext context, Map<String, dynamic> item) {
    final idRaw = item['id'];
    final contentId = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw');
    final title = item['title']?.toString().trim() ?? '';
    final imageUrl = _resolveContentImageUrl(
      thumbnail: item['thumbnail_url'],
      contentHtml: item['content_html'],
    );
    return InkWell(
      onTap: () {
        if (contentId == null) return;
        Navigator.pushNamed(
          context,
          '/content/detail',
          arguments: {'id': contentId},
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 200,
              width: double.infinity,
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFFF2F2F2),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    color: Color(0xFFBDBDBD),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              title,
              style: const TextStyle(
                color: _textDark,
                fontSize: 16,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
                height: 0.94,
                letterSpacing: -1.44,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _resolveContentImageUrl({
    required dynamic thumbnail,
    required dynamic contentHtml,
  }) {
    return ContentService.resolveDisplayImageUrl(
      thumbnail: thumbnail?.toString(),
      contentHtml: contentHtml?.toString(),
      fallback: 'https://placehold.co/321x200',
    );
  }
}

class _WriteFab extends StatelessWidget {
  const _WriteFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          width: 55,
          height: 55,
          decoration: ShapeDecoration(
            color: const Color(0xFFFF5B8C),
            shape: RoundedRectangleBorder(
              side: BorderSide(width: 2, color: Colors.white.withValues(alpha: 0.20)),
              borderRadius: BorderRadius.circular(16),
            ),
            shadows: const [
              BoxShadow(
                color: Color(0x66FF5B8C),
                blurRadius: 10,
                offset: Offset(0, 8),
                spreadRadius: -6,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              '글쓰기',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
                height: 1.25,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
