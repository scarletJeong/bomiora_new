import 'package:flutter/material.dart';

import '../../../../data/services/content_service.dart';
import '../../../common/widgets/app_bar.dart';
import '../../../common/widgets/appbar_menutap.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../../data/services/category_service.dart';
import '../widgets/content_bottom_nav_bar.dart';

/// 건강 콘텐츠 대시보드 (Figma 기반 UI)
class ContentDashboardScreen extends StatefulWidget {
  const ContentDashboardScreen({super.key});

  @override
  State<ContentDashboardScreen> createState() => _ContentDashboardScreenState();
}

class _ContentDashboardScreenState extends State<ContentDashboardScreen> {
  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _pink = Color(0xFFFF5A8D);

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final Future<List<String>> _categoriesFuture = _loadCategories();
  late final Future<List<Map<String, dynamic>>> _featuredFuture =
      _loadFeaturedPosts();

  Future<List<String>> _loadCategories() async {
    final result = await CategoryService.getCategoriesByGroup('content');
    final dynamic list = result['categories'];
    if (result['success'] == true && list is List && list.isNotEmpty) {
      final categories = list
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (categories.isNotEmpty) return categories;
    }
    return const [];
  }

  Future<List<Map<String, dynamic>>> _loadFeaturedPosts() async {
    final result = await ContentService.getContentList(size: 5);
    if (result['success'] == true && result['data'] is List) {
      final list = (result['data'] as List)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
      return list;
    }
    return const [];
  }

  Future<List<Map<String, dynamic>>> _loadCategoryPosts(String category) async {
    final result = await ContentService.getContentList(
      category: category,
      size: 4,
    );
    if (result['success'] == true && result['data'] is List) {
      return (result['data'] as List)
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      scaffoldKey: _scaffoldKey,
      appBar: HealthAppBar(
        title: '건강 콘텐츠',
        centerTitle: true,
        leadingType: HealthAppBarLeadingType.menu,
        onBack: () => _scaffoldKey.currentState?.openDrawer(),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black),
            onPressed: () => Navigator.pushNamed(context, '/content/list'),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      drawer: AppBarMenuTapDrawer(
        onHealthDashboardTap: () {
          Navigator.pushReplacementNamed(context, '/health');
        },
      ),
      backgroundColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: FutureBuilder<List<String>>(
              future: _categoriesFuture,
              builder: (context, snapshot) {
                final categories = snapshot.data ?? const <String>[];
                return SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 27, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFeaturedCarousel(),
                      const SizedBox(height: 10),
                      if (categories.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            '노출할 콘텐츠 카테고리가 없습니다.',
                            style: TextStyle(
                              color: Color(0xFF898686),
                              fontSize: 14,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      else
                        for (final category in categories) ...[
                          _buildSection(
                            context,
                            category: category,
                          ),
                          const SizedBox(height: 10),
                        ],
                      const SizedBox(height: 20),
                    ],
                  ),
                );
              },
            ),
          ),
          const ContentBottomNavBar(),
        ],
      ),
    );
  }

  Widget _buildFeaturedCarousel() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _featuredFuture,
      builder: (context, snapshot) {
        final posts = snapshot.data ?? const <Map<String, dynamic>>[];
        if (posts.isEmpty) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: 248,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: posts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final post = posts[index];
              return SizedBox(
                width: 321,
                child: _FeaturedCard(
                  imageUrl: _resolveContentImageUrl(
                    thumbnail: post['thumbnail_url'],
                    contentHtml: post['content_html'],
                    fallback: 'https://placehold.co/321x172',
                  ),
                  title: _safeText(post['title']) ?? '',
                  subtitle: _safeText(post['summary']) ?? '',
                  onTap: () => _openDetail(context, post),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String category,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '| $category',
                style: const TextStyle(
                  color: _textDark,
                  fontSize: 16,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                  letterSpacing: -1.44,
                ),
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pushNamed(
                context,
                '/content/list',
                arguments: {'category': category},
              ),
              child: Container(
                width: 42,
                height: 17,
                padding: const EdgeInsets.all(3),
                decoration: ShapeDecoration(
                  color: _pink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'More',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _loadCategoryPosts(category),
          builder: (context, snapshot) {
            final items = snapshot.data ?? const <Map<String, dynamic>>[];
            if (items.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: Text(
                    '게시글이 없습니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF898686),
                      fontSize: 13,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }
            return _buildTwoColumnGrid(context, items.take(4).toList());
          },
        ),
      ],
    );
  }

  Widget _buildTwoColumnGrid(
    BuildContext context,
    List<Map<String, dynamic>> items,
  ) {
    final rows = <List<Map<String, dynamic>>>[];
    for (var i = 0; i < items.length; i += 2) {
      rows.add(
        items.sublist(i, i + 2 > items.length ? items.length : i + 2),
      );
    }

    return Column(
      children: List.generate(rows.length, (rowIndex) {
        final rowItems = rows[rowIndex];
        return Padding(
          padding: EdgeInsets.only(bottom: rowIndex == rows.length - 1 ? 0 : 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SmallTile(
                  imageUrl: _resolveContentImageUrl(
                    thumbnail: rowItems[0]['thumbnail_url'],
                    contentHtml: rowItems[0]['content_html'],
                    fallback: 'https://placehold.co/150x150',
                  ),
                  label: _safeText(rowItems[0]['title']) ?? '',
                  onTap: () => _openDetail(context, rowItems[0]),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: rowItems.length > 1
                    ? _SmallTile(
                        imageUrl: _resolveContentImageUrl(
                          thumbnail: rowItems[1]['thumbnail_url'],
                          contentHtml: rowItems[1]['content_html'],
                          fallback: 'https://placehold.co/150x150',
                        ),
                        label: _safeText(rowItems[1]['title']) ?? '',
                        onTap: () => _openDetail(context, rowItems[1]),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      }),
    );
  }

  String? _safeText(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  String _resolveContentImageUrl({
    required dynamic thumbnail,
    required dynamic contentHtml,
    required String fallback,
  }) {
    return ContentService.resolveDisplayImageUrl(
      thumbnail: thumbnail?.toString(),
      contentHtml: contentHtml?.toString(),
      fallback: fallback,
    );
  }

  void _openDetail(BuildContext context, Map<String, dynamic> post) {
    final idRaw = post['id'];
    final id = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw');
    if (id == null) return;
    Navigator.pushNamed(
      context,
      '/content/detail',
      arguments: {'id': id},
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String imageUrl;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _textMuted = Color(0xFF898383);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: 172,
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
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _textDark,
                        fontSize: 16,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1.44,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallTile extends StatelessWidget {
  const _SmallTile({
    required this.imageUrl,
    required this.label,
    required this.onTap,
  });

  final String imageUrl;
  final String label;
  final VoidCallback onTap;

  static const Color _textDark = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
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
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Text(
                label,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _textDark,
                  fontSize: 10,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                  height: 1.50,
                  letterSpacing: -0.90,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
