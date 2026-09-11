import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../../core/utils/image_url_helper.dart';
import '../../../../core/utils/node_value_parser.dart';
import '../../../../data/models/announcement/announcement_model.dart';
import '../../../../data/services/announcement_service.dart';
import '../../../../data/services/content_service.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import '../../../common/navigation/board_list_navigation.dart';
import '../../../common/widgets/article_adjacent_nav.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../health/health_common/health_responsive_scale.dart';

class AnnouncementDetailScreen extends StatefulWidget {
  final int announcementId;

  const AnnouncementDetailScreen({
    super.key,
    required this.announcementId,
  });

  @override
  State<AnnouncementDetailScreen> createState() => _AnnouncementDetailScreenState();
}

class _AnnouncementDetailScreenState extends State<AnnouncementDetailScreen> {
  static const Color _kText = Color(0xFF1A1A1A);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kBorder = Color(0x7FD2D2D2);
  static const Color _kPink = Color(0xFFFF5A8D);

  bool _loading = true;
  String? _error;
  AnnouncementModel? _item;
  Map<String, dynamic>? _prev;
  Map<String, dynamic>? _next;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await AnnouncementService.getAnnouncementDetail(
      widget.announcementId,
    );
    if (!mounted) return;

    if (result['success'] == true) {
      var prev = result['prev'] as Map<String, dynamic>?;
      var next = result['next'] as Map<String, dynamic>?;
      setState(() {
        _item = result['item'] as AnnouncementModel?;
        _prev = prev;
        _next = next;
        _loading = false;
      });
      if (prev == null && next == null) {
        final listResult = await AnnouncementService.getAnnouncements(
          page: 1,
          size: 80,
        );
        if (!mounted) return;
        final adjacent = _adjacentFromList(
          widget.announcementId,
          (listResult['items'] as List<AnnouncementModel>?) ?? const [],
        );
        setState(() {
          _prev = adjacent.$1;
          _next = adjacent.$2;
        });
      }
    } else {
      setState(() {
        _error = result['message']?.toString() ?? '공지사항을 불러오지 못했습니다.';
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: const HealthAppBar(title: '공지사항'),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: _kMuted,
                      fontSize: healthSp(context, 14),
                      fontFamily: 'Gmarket Sans TTF',
                    ),
                  ),
                )
              : _item == null
                  ? Center(
                      child: Text(
                        '공지사항을 찾을 수 없습니다.',
                        style: TextStyle(
                          color: _kMuted,
                          fontSize: healthSp(context, 14),
                          fontFamily: 'Gmarket Sans TTF',
                        ),
                      ),
                    )
                  : _buildBody(context, _item!),
    );
  }

  Widget _buildBody(BuildContext context, AnnouncementModel item) {
    final hasImage = item.imagePath != null && item.imagePath!.trim().isNotEmpty;
    final formattedTitle = _normalizeTitle(item.title);

    final prevId = _adjacentId(_prev);
    final nextId = _adjacentId(_next);
    final prevTitle = (_prev?['title'] ?? '').toString().trim();
    final nextTitle = (_next?['title'] ?? '').toString().trim();

    return Stack(
      fit: StackFit.expand,
      children: [
        ListView(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(
            healthDp(context, 27),
            healthDp(context, 20),
            healthDp(context, 27),
            healthDp(context, 20),
          ),
          children: [
            Text(
              formattedTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _kText,
                fontSize: healthSp(context, 14),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
                letterSpacing: healthSp(context, -1.44),
              ),
            ),
            SizedBox(height: healthDp(context, 10)),
            Container(height: healthDp(context, 1), color: _kBorder),
            SizedBox(height: healthDp(context, 30)),
            if (hasImage) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(healthDp(context, 12)),
                child: Image.network(
                  ImageUrlHelper.getImageUrl(item.imagePath),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: healthDp(context, 180),
                    alignment: Alignment.center,
                    color: const Color(0xFFF6F6F6),
                    child: Icon(
                      Icons.broken_image_outlined,
                      color: _kMuted,
                      size: healthDp(context, 32),
                    ),
                  ),
                ),
              ),
              SizedBox(height: healthDp(context, 20)),
            ],
            _buildAnnouncementBody(context, item.content),
            SizedBox(height: healthDp(context, 30)),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _kPink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(healthDp(context, 4)),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: healthDp(context, 15),
                    vertical: healthDp(context, 8),
                  ),
                ),
                onPressed: () => popToBoardList(context, '/announcement'),
                child: Text(
                  '목록',
                  style: TextStyle(
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
        ArticleAdjacentNavOverlay(
          controller: _scrollController,
          previous: prevId != null && prevTitle.isNotEmpty
              ? ArticleAdjacentItem(
                  title: prevTitle,
                  onTap: () => _moveToAdjacent(prevId),
                )
              : null,
          next: nextId != null && nextTitle.isNotEmpty
              ? ArticleAdjacentItem(
                  title: nextTitle,
                  onTap: () => _moveToAdjacent(nextId),
                )
              : null,
        ),
      ],
    );
  }

  Widget _buildAnnouncementBody(BuildContext context, String rawHtml) {
    final processed = ContentService.prepareContentHtmlForRender(rawHtml);
    if (processed.trim().isEmpty) {
      final plain = ContentService.normalizeHtmlToText(rawHtml);
      return Text(
        plain,
        style: TextStyle(
          color: _kText,
          fontSize: healthSp(context, 14),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w300,
          height: 1.7,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPad = healthDp(context, 27) * 2;
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - horizontalPad;
        return Html(
          data: processed,
          style: {
            'html': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
            'body': Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              fontFamily: 'Gmarket Sans TTF',
              fontSize: FontSize(healthSp(context, 14)),
              fontWeight: FontWeight.w300,
              lineHeight: const LineHeight(1.7),
              textAlign: TextAlign.start,
              color: _kText,
            ),
            'p': Style(
              margin: Margins.only(bottom: healthDp(context, 8)),
              padding: HtmlPaddings.zero,
            ),
            'img': Style(
              width: Width(maxWidth),
              display: Display.block,
              margin: Margins.symmetric(vertical: healthDp(context, 8)),
            ),
            'div': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
            'span': Style(fontFamily: 'Gmarket Sans TTF'),
          },
        );
      },
    );
  }

  String _normalizeTitle(String raw) {
    return raw
        .replaceAll(r'\n', '\n')
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .trim();
  }

  (Map<String, dynamic>?, Map<String, dynamic>?) _adjacentFromList(
    int id,
    List<AnnouncementModel> items,
  ) {
    final index = items.indexWhere((e) => e.id == id);
    if (index < 0) return (null, null);
    final prev = index > 0
        ? {'id': items[index - 1].id, 'title': items[index - 1].title}
        : null;
    final next = index < items.length - 1
        ? {'id': items[index + 1].id, 'title': items[index + 1].title}
        : null;
    return (prev, next);
  }

  int? _adjacentId(Map<String, dynamic>? raw) {
    if (raw == null) return null;
    return NodeValueParser.asInt(raw['id']);
  }

  void _moveToAdjacent(int? id) {
    if (id == null || id <= 0) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AnnouncementDetailScreen(announcementId: id),
        settings: RouteSettings(name: '/announcement/$id'),
      ),
    );
  }
}
