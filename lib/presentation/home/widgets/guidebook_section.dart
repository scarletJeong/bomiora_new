import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../data/models/content/content_post.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../data/services/content_service.dart';
import '../../common/widgets/app_clickable.dart';
import '../../common/widgets/app_network_image.dart';
import '../../common/widgets/centered_empty_state.dart';
import '../../common/widgets/web_dragscroll.dart';
import '../../health/health_common/health_responsive_scale.dart';
import 'btn_more.dart';
import 'home_big_card.dart';
import 'home_section_widgets.dart';

class GuidebookSection extends StatefulWidget {
  const GuidebookSection({super.key});

  @override
  State<GuidebookSection> createState() => _GuidebookSectionState();
}

class _GuidebookSectionState extends State<GuidebookSection> {
  late final Future<List<ContentPost>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadLatest();
  }

  Future<List<ContentPost>> _loadLatest() async {
    final result = await ContentService.getHomePreviewList();
    if (!result.failed) {
      return result.items.take(3).toList();
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final m = HomeBigCardLayout.fromWidth(w);
    final titleH = m.titleFs * 1.25;
    final listH = m.imageH + m.columnGap + titleH;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.zero,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: healthDp(context, 20)),
            child: HomeSectionTitleRow(
              line1: '건강',
              line2: '컨텐츠',
              trailing: BtnMore(
                onTap: () => Navigator.pushNamed(context, '/content'),
              ),
            ),
          ),
          SizedBox(height: healthDp(context, 20)),
          SizedBox(
            height: listH,
            child: FutureBuilder<List<ContentPost>>(
              future: _future,
              builder: (context, snapshot) {
                final items = snapshot.data ?? const [];
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: const Color(0xFFFF5A8D), strokeWidth: 2),
                    ),
                  );
                }
                if (items.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: healthDp(context, 20)),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CenteredEmptyState.assetIcon(
                            context,
                            AppAssets.emptyContentIcon,
                            slot: 56,
                          ),
                          SizedBox(height: healthDp(context, 8)),
                          Text(
                            '등록된 콘텐츠가 없습니다.',
                            style: TextStyle(
                              color: const Color(0x665B3F43),
                              fontSize: healthSp(context, 12),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return WebDragScrollConfiguration(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: healthDp(context, 20)),
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(width: m.rowGapBetweenCards),
                    itemBuilder: (context, index) {
                      final it = items[index];
                      return _GuidebookCard(
                        m: m,
                        titleH: titleH,
                        item: it,
                        onTap: () {
                          final id = it.id;
                          if (id == null) return;
                          final cat = it.category;
                          Navigator.pushNamed(
                            context,
                            '/content/detail',
                            arguments: {
                              'id': id,
                              if (cat.isNotEmpty) 'category': cat,
                            },
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
  final HomeBigCardLayout m;
  final double titleH;
  final ContentPost item;
  final VoidCallback? onTap;

  const _GuidebookCard({
    required this.m,
    required this.titleH,
    required this.item,
    this.onTap,
  });

  String _t(String? v) => (v ?? '').trim();

  @override
  Widget build(BuildContext context) {
    final title = _t(item.title);
    final thumbRaw = item.thumbnailUrl;
    final resolved = ContentService.resolveThumbnailUrl(thumbRaw, fallback: '');
    final thumb = resolved.isEmpty
        ? ''
        : ImageUrlHelper.contentListThumbUrl(resolved, width: 480);

    return SizedBox(
      width: m.cardW,
      height: m.imageH + m.columnGap + titleH,
      child: AppClickable(
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
                    ? AppNetworkImage(
                        url: thumb,
                        fit: BoxFit.cover,
                        width: m.cardW,
                        height: m.imageH,
                        decodeWidthLogical: m.cardW,
                        decodeHeightLogical: m.imageH,
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
              height: titleH,
              child: Text(
                title.isEmpty ? '(제목 없음)' : title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF231F20),
                  fontSize: m.titleFs,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
