import 'package:flutter/material.dart';

import '../../../data/services/content_service.dart';
import '../../common/widgets/web_drag_scroll_configuration.dart';
import '../../content/dashboard/screens/content_detail_screen.dart';

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
    return Container(
      width: double.infinity,
      padding: EdgeInsets.zero,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 2,
                  height: 40,
                  color: const Color(0xFF28171A),
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      '건강',  
                      style: TextStyle(
                        color: Color(0x665B3F43),
                        fontSize: 10,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                        letterSpacing: 1,
                      ),
                    ),
                    Text(
                      '가이드북',
                      style: TextStyle(
                        color: Color(0xFF28171A),
                        fontSize: 20,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                InkWell(
                  onTap: () => Navigator.pushNamed(context, '/content'),
                  borderRadius: BorderRadius.circular(9999),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: ShapeDecoration(
                      color: const Color(0xFFFF5A8D),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9999),
                      ),
                    ),
                    child: const Text(
                      '+ More',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 278,
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
                  return const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24),
                    child: Center(
                      child: Text(
                        '등록된 콘텐츠가 없습니다.',
                        style: TextStyle(
                          color: Color(0x665B3F43),
                          fontSize: 12,
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
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, index) {
                      final it = items[index];
                      return _GuidebookCard(
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

  final Map<String, dynamic> item;
  final VoidCallback? onTap;

  const _GuidebookCard({required this.item, this.onTap});

  String _t(String? v) => (v ?? '').trim();

  @override
  Widget build(BuildContext context) {
    final title = _t(item['title']?.toString());
    final bodyHtml = _t(item['content_html']?.toString());
    final bodyPlain = ContentService.normalizeHtmlToText(bodyHtml);
    final description = bodyPlain.isNotEmpty ? bodyPlain : _fallbackDescription;
    final thumbRaw = item['thumbnail_url']?.toString();
    final thumb = ContentService.resolveThumbnailUrl(thumbRaw, fallback: '');

    return Container(
      // 카드 너비
      width: 320, 
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        shadows: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 2,
            offset: Offset(0, 1),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 160,
                width: double.infinity,
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
            Expanded(
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title.isEmpty ? '(제목 없음)' : title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF28171A),
                          fontSize: 12,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w600,
                          height: 1.33,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Text(
                          description,
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0x665B3F43),
                            fontSize: 10,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                          ),
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
    );
  }
}
