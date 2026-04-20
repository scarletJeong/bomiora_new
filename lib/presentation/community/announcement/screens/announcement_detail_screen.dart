import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../../core/utils/image_url_helper.dart';
import '../../../../data/models/announcement/announcement_model.dart';
import '../../../../data/services/announcement_service.dart';
import '../../../../data/services/content_service.dart';
import '../../../common/widgets/app_bar.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';

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

    final result = await AnnouncementService.getAnnouncementDetail(widget.announcementId);
    if (!mounted) return;

    if (result['success'] == true) {
      setState(() {
        _item = result['item'] as AnnouncementModel?;
        _prev = result['prev'] as Map<String, dynamic>?;
        _next = result['next'] as Map<String, dynamic>?;
      });
    } else {
      setState(() => _error = result['message']?.toString() ?? '공지사항을 불러오지 못했습니다.');
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: const HealthAppBar(title: '공지사항', centerTitle: true),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: _kMuted,
                      fontSize: 14,
                      fontFamily: 'Gmarket Sans TTF',
                    ),
                  ),
                )
              : _item == null
                  ? const Center(
                      child: Text(
                        '공지사항을 찾을 수 없습니다.',
                        style: TextStyle(
                          color: _kMuted,
                          fontSize: 14,
                          fontFamily: 'Gmarket Sans TTF',
                        ),
                      ),
                    )
                  : _buildBody(_item!),
    );
  }

  Widget _buildBody(AnnouncementModel item) {
    final hasImage = item.imagePath != null && item.imagePath!.trim().isNotEmpty;
    final formattedTitle = _normalizeTitle(item.title);

    return ListView(
      padding: const EdgeInsets.fromLTRB(27, 16, 27, 24),
      children: [
        Text(
          formattedTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _kText,
            fontSize: 20,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Container(height: 1, color: _kBorder),
        const SizedBox(height: 20),
        if (hasImage) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              ImageUrlHelper.getImageUrl(item.imagePath),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 180,
                alignment: Alignment.center,
                color: const Color(0xFFF6F6F6),
                child: const Icon(Icons.broken_image_outlined, color: _kMuted),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
        _buildAnnouncementBody(item.content),
        const SizedBox(height: 20),
        Container(height: 1, color: _kBorder),
        const SizedBox(height: 14),
        if (_prev != null) ...[
          _buildAdjacentRow(
            label: '이전글',
            title: (_prev?['title'] ?? '').toString(),
            isPrev: true,
            onTap: () => _moveToAdjacent((_prev?['id'] as num?)?.toInt()),
          ),
          Container(height: 1, color: _kBorder),
        ],
        if (_next != null) ...[
          _buildAdjacentRow(
            label: '다음글',
            title: (_next?['title'] ?? '').toString(),
            isPrev: false,
            onTap: () => _moveToAdjacent((_next?['id'] as num?)?.toInt()),
          ),
          Container(height: 1, color: _kBorder),
        ],
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: _kPink,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            ),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
                return;
              }
              Navigator.pushNamed(context, '/announcement');
            },
            child: const Text(
              '목록',
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnnouncementBody(String rawHtml) {
    final processed = ContentService.prepareContentHtmlForRender(rawHtml);
    if (processed.trim().isEmpty) {
      final plain = ContentService.normalizeHtmlToText(rawHtml);
      return Text(
        plain,
        style: const TextStyle(
          color: _kText,
          fontSize: 14,
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
          height: 1.7,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 54;
        return Html(
          data: processed,
          style: {
            'html': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
            'body': Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              fontFamily: 'Gmarket Sans TTF',
              fontSize: FontSize(14),
              fontWeight: FontWeight.w500,
              lineHeight: const LineHeight(1.7),
              textAlign: TextAlign.start,
              color: _kText,
            ),
            'p': Style(
              margin: Margins.only(bottom: 8),
              padding: HtmlPaddings.zero,
            ),
            'img': Style(
              width: Width(maxWidth),
              display: Display.block,
              margin: Margins.symmetric(vertical: 8),
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

  Widget _buildAdjacentRow({
    required String label,
    required String title,
    required bool isPrev,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Transform.rotate(
              angle: isPrev ? 1.57 : -1.57,
              child: const Icon(
                Icons.chevron_left_rounded,
                size: 16,
                color: _kMuted,
              ),
            ),
            const SizedBox(width: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _kMuted,
                fontSize: 14,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
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
