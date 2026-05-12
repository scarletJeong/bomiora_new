import 'package:flutter/material.dart';

import '../../../data/services/content_service.dart';
import '../../common/widgets/web_dragscroll.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../content/dashboard/screens/content_detail_screen.dart';
import 'btn_more.dart';
import 'home_big_card.dart';
import 'home_section_widgets.dart';

class GuidebookSection extends StatefulWidget {
  const GuidebookSection({super.key});

  @override
  State<GuidebookSection> createState() => _GuidebookSectionState();
}

class _GuidebookSectionState extends State<GuidebookSection> {
  late final Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadLatest();
  }

  Future<List<Map<String, dynamic>>> _loadLatest() async {
    final result = await ContentService.getContentList(page: 1, size: 3);
    if (result['success'] == true) {
      final list = (result['data'] as List<Map<String, dynamic>>?) ?? const [];
      return list.take(3).toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final m = HomeBigCardLayout.fromWidth(w);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.zero,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: healthDp(context, 24)),
            child: HomeSectionTitleRow(
              line1: '건강',
              line2: '가이드북',
              trailing: BtnMore(
                onTap: () => Navigator.pushNamed(context, '/content'),
              ),
            ),
          ),
          SizedBox(height: healthDp(context, 12)),
          SizedBox(
            height: m.listItemHeight,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                final items = snapshot.data ?? const [];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                if (items.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: healthDp(context, 24)),
                    child: Center(
                      child: Text(
                        '등록된 콘텐츠가 없습니다.',
                        style: TextStyle(
                          color: const Color(0x665B3F43),
                          fontSize: healthSp(context, 12),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }
                return WebDragScrollConfiguration(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: healthDp(context, 24)),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(width: m.rowGapBetweenCards),
                    itemBuilder: (context, index) {
                      final it = items[index];
                      return _GuidebookCard(
                        m: m,
                        item: it,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ContentDetailScreen.fromArgs(it),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _GuidebookCard extends StatelessWidget {
  static const String _fallbackDescription = '건강 콘텐츠를 확인해보세요.';

  final HomeBigCardLayout m;
  final Map<String, dynamic> item;
  final VoidCallback? onTap;

  const _GuidebookCard({
    required this.m,
    required this.item,
    this.onTap,
  });

  String _t(String? v) => (v ?? '').trim();

  @override
  Widget build(BuildContext context) {
    final title = _t(item['title']?.toString());
    final bodyHtml = _t(item['content_html']?.toString());
    final bodyPlain = ContentService.normalizeHtmlToText(bodyHtml);
    final description =
        bodyPlain.isNotEmpty ? bodyPlain : _fallbackDescription;
    final thumbRaw = item['thumbnail_url']?.toString();
    final thumb = ContentService.resolveThumbnailUrl(thumbRaw, fallback: '');

    return SizedBox(
      width: m.cardW,
      height: m.listItemHeight,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(m.radius),
              child: SizedBox(
                width: m.cardW,
                height: m.imageH,
                child: thumb.isNotEmpty
                    ? Image.network(
                        thumb,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Color(0xFFFFE9EA),
                        ),
                      )
                    : const ColoredBox(color: Color(0xFFFFE9EA)),
              ),
            ),
            SizedBox(height: m.columnGap),
            SizedBox(
              width: m.cardW,
              height: m.textPanelHeight,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.isEmpty ? '(제목 없음)' : title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: const Color(0xFF231F20),
                      fontSize: m.titleFs,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                  ),
                  SizedBox(height: m.titleDescGap),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Text(
                        description,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: const Color(0xFF231F20),
                          fontSize: m.descFs,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                          letterSpacing: m.descLetterSpacing,
                          height: 1.35,
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
    );
  }
}
