import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/logging/failure_log.dart';
import '../../../data/models/content/content_post.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../data/services/auth_service.dart';
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
  int _loadGen = 0;
  bool _loading = true;
  bool _failed = false;
  List<ContentPost> _items = const [];

  @override
  void initState() {
    super.initState();
    _loadLatest();
  }

  Future<void> _loadLatest({bool showLoading = false}) async {
    final gen = ++_loadGen;
    if (showLoading && mounted) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }
    final result = await ContentService.getHomePreviewList();
    if (!mounted || gen != _loadGen) return;
    if (result.failed) {
      setState(() {
        _loading = false;
        _failed = true;
        _items = const [];
      });
      final user = await AuthService.getUser();
      await FailureLog.record(
        code: 'home.content',
        mbId: user?.id ?? '',
        reason: '건강 컨텐츠를 불러오지 못했습니다.',
      );
      return;
    }
    setState(() {
      _loading = false;
      _failed = false;
      _items = result.items.take(3).toList();
    });
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
            child: Builder(
              builder: (context) {
                final items = _items;
                if (_loading) {
                  return const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: const Color(0xFFFF5A8D), strokeWidth: 2),
                    ),
                  );
                }
                if (_failed) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '콘텐츠를 불러오지 못했습니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF898686),
                            fontSize: healthSp(context, 14),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: healthDp(context, 12)),
                        SizedBox(
                          height: healthDp(context, 36),
                          child: ElevatedButton(
                            onPressed: () => _loadLatest(showLoading: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFF5A8D),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: EdgeInsets.symmetric(
                                horizontal: healthDp(context, 16),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  healthDp(context, 10),
                                ),
                              ),
                            ),
                            child: Text(
                              '다시 시도',
                              style: TextStyle(
                                fontSize: healthSp(context, 13),
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
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
                              color: const Color(0xFF898686),
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
                          final resolved = ContentService.resolveThumbnailUrl(
                            it.thumbnailUrl,
                            fallback: '',
                          );
                          final imageUrl = resolved.isEmpty
                              ? ''
                              : ImageUrlHelper.contentListThumbUrl(
                                  resolved,
                                  width: 480,
                                );
                          Navigator.pushNamed(
                            context,
                            '/content/detail',
                            arguments: {
                              'id': id,
                              if (cat.isNotEmpty) 'category': cat,
                              if (imageUrl.isNotEmpty) 'imageUrl': imageUrl,
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
                  color: const Color(0xFF1A1A1A),
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
