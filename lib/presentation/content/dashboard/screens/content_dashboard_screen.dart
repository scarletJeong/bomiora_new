import 'package:flutter/material.dart';

import '../../../../core/utils/image_url_helper.dart';
import '../../../../data/repositories/content/content_category_catalog.dart';
import '../../../../data/services/content_service.dart';
import '../../../common/widgets/app_bar_menu.dart';
import '../../../common/widgets/appbar_menutap.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/navi_bar.dart';
import '../../../common/widgets/app_footer.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../user/myPage/widgets/my_page_common.dart';

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
  late final Future<List<String>> _categoriesFuture =
      ContentCategoryCatalog.categories();
  late final Future<List<Map<String, dynamic>>> _featuredFuture =
      _loadFeaturedPosts();

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
      appBar: AppBarMenu(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
        onSearchPressed: () =>
            Navigator.pushNamed(context, '/content/list'),
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
                  padding: EdgeInsets.only(top: healthDp(context, 10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: healthDp(context, 27),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildFeaturedCarousel(context),
                            SizedBox(height: healthDp(context, 10)),
                            if (categories.isEmpty)
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: healthDp(context, 24),
                                ),
                                child: Text(
                                  '노출할 콘텐츠 카테고리가 없습니다.',
                                  style: TextStyle(
                                    color: const Color(0xFF898686),
                                    fontSize: healthSp(context, 14),
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
                                SizedBox(height: healthDp(context, 10)),
                              ],
                            SizedBox(height: healthDp(context, 20)),
                            SizedBox(height: healthDp(context, 100)),
                          ],
                        ),
                      ),
                      const AppFooter(),
                    ],
                  ),
                );
              },
            ),
          ),
          const FooterBar(),
        ],
      ),
    );
  }

  Widget _buildFeaturedCarousel(BuildContext context) {
    final cardW = healthDp(context, 321);
    final cardH = healthDp(context, 248);
    final imageH = healthDp(context, 172);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _featuredFuture,
      builder: (context, snapshot) {
        final posts = snapshot.data ?? const <Map<String, dynamic>>[];
        if (posts.isEmpty) {
          return const SizedBox.shrink();
        }
        return SizedBox(
          height: cardH,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: posts.length,
            separatorBuilder: (_, __) =>
                SizedBox(width: healthDp(context, 10)),
            itemBuilder: (context, index) {
              final post = posts[index];
              return SizedBox(
                width: cardW,
                child: _FeaturedCard(
                  imageHeight: imageH,
                  imageUrl: _resolveContentImageUrl(
                    thumbnail: post['thumbnail_url'],
                    contentHtml: post['content_html'],
                    fallback: ImageUrlHelper.placeholdCo(
                      cardW.round(),
                      imageH.round(),
                    ),
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
              child: Row(
                children: [
                  myPageLeadingBar(context),
                  SizedBox(width: healthDp(context, 10)),
                  Expanded(
                    child: Text(
                      category,
                      style: myPageLineTitleStyle(context),
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.pushNamed(
                context,
                '/content/list',
                arguments: {'category': category},
              ),
              child: Container(
                width: healthDp(context, 47),
                height: healthDp(context, 20),
                padding: EdgeInsets.all(healthDp(context, 4)),
                decoration: ShapeDecoration(
                  color: _pink,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(healthDp(context, 16)),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+More',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: healthSp(context, 10),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: healthDp(context, 10)),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _loadCategoryPosts(category),
          builder: (context, snapshot) {
            final items = snapshot.data ?? const <Map<String, dynamic>>[];
            if (items.isEmpty) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: healthDp(context, 12)),
                child: Center(
                  child: Text(
                    '게시글이 없습니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF898686),
                      fontSize: healthSp(context, 12),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
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
    final thumbSize = healthDp(context, 150).round();
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
          padding: EdgeInsets.only(
            bottom: rowIndex == rows.length - 1 ? 0 : healthDp(context, 10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _SmallTile(
                  imageUrl: _resolveContentImageUrl(
                    thumbnail: rowItems[0]['thumbnail_url'],
                    contentHtml: rowItems[0]['content_html'],
                    fallback: ImageUrlHelper.placeholdCo(thumbSize, thumbSize),
                  ),
                  label: _safeText(rowItems[0]['title']) ?? '',
                  onTap: () => _openDetail(context, rowItems[0]),
                ),
              ),
              SizedBox(width: healthDp(context, 10)),
              Expanded(
                child: rowItems.length > 1
                    ? _SmallTile(
                        imageUrl: _resolveContentImageUrl(
                          thumbnail: rowItems[1]['thumbnail_url'],
                          contentHtml: rowItems[1]['content_html'],
                          fallback:
                              ImageUrlHelper.placeholdCo(thumbSize, thumbSize),
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
    final cat = (post['category'] ?? '').toString().trim();
    Navigator.pushNamed(
      context,
      '/content/detail',
      arguments: {
        'id': id,
        if (cat.isNotEmpty) 'category': cat,
      },
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.imageHeight,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final double imageHeight;
  final String imageUrl;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _textMuted = Color(0xFF898383);

  @override
  Widget build(BuildContext context) {
    final radius = healthDp(context, 10);


    // 맨 위 콘텐츠 카드 (고정 콘텐츠 카드)
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: SizedBox(
                height: imageHeight,
                width: double.infinity,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFF2F2F2),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.broken_image_outlined,
                      size: healthDp(context, 32),
                      color: const Color(0xFFBDBDBD),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: healthDp(context, 5)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textDark,
                        fontSize: healthSp(context, 14),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                        letterSpacing: healthSp(context, -1.26),
                      ),
                    ),
                    SizedBox(height: healthDp(context, 3)),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _textMuted,
                        fontSize: healthSp(context, 12),
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
    final radius = healthDp(context, 5);
    final thumbSize = healthDp(context, 150);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: thumbSize,
              height: thumbSize,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(radius),
                child: Image.network(
                  imageUrl,
                  width: thumbSize,
                  height: thumbSize,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFF2F2F2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: healthDp(context, 12)),
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: healthSp(context, 12),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                  letterSpacing: healthSp(context, -1.08),
                ),
              ),
            ),
          ],
        ),
    );
  }
}
