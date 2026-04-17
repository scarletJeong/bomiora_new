import 'package:flutter/material.dart';

import '../../../../data/services/content_service.dart';
import '../../../common/widgets/app_bar.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../widgets/content_bottom_nav_bar.dart';

/// 콘텐츠 상세 (본문, 이전/다음 글, 하단 액션)
class ContentDetailScreen extends StatefulWidget {
  const ContentDetailScreen({
    super.key,
    this.contentId,
    this.categoryLabel = '건강상식',
    this.title = '다이어트 성공의 열쇠,\n이 음식들 알고 계셨나요?',
    this.body =
        '안녕하세요.\n오늘은 다이어트에 도움이 되는\n슈퍼푸드를 소개해드리려고 해요.\n체중감량을 하면서도 건강은 챙기고 싶으신 분들을 위한\n특별한 정보를 준비했답니다.\n자,  그럼 시작해볼까요?',
    this.imageUrl = 'https://placehold.co/321x200',
    this.prevTitle = '건강한 다이어트 5가지 핵심 원칙',
    this.nextTitle = '따듯한 물, 왜 다이어트에 효과적일까?',
  });

  final int? contentId;
  final String categoryLabel;
  final String title;
  final String body;
  final String imageUrl;
  final String prevTitle;
  final String nextTitle;

  static ContentDetailScreen fromArgs(Object? args) {
    if (args is Map<String, dynamic>) {
      final idRaw = args['id'];
      final id = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw');
      return ContentDetailScreen(
        contentId: id,
        categoryLabel: args['category']?.toString() ?? '건강상식',
        title: args['title']?.toString() ?? '다이어트 성공의 열쇠,\n이 음식들 알고 계셨나요?',
        body: args['body']?.toString() ??
            '안녕하세요.\n오늘은 다이어트에 도움이 되는\n슈퍼푸드를 소개해드리려고 해요.\n체중감량을 하면서도 건강은 챙기고 싶으신 분들을 위한\n특별한 정보를 준비했답니다.\n자,  그럼 시작해볼까요?',
        imageUrl: args['imageUrl']?.toString() ?? 'https://placehold.co/321x200',
        prevTitle: args['prevTitle']?.toString() ?? '건강한 다이어트 5가지 핵심 원칙',
        nextTitle: args['nextTitle']?.toString() ?? '따듯한 물, 왜 다이어트에 효과적일까?',
      );
    }
    return const ContentDetailScreen();
  }

  @override
  State<ContentDetailScreen> createState() => _ContentDetailScreenState();
}

class _ContentDetailScreenState extends State<ContentDetailScreen> {
  static const Color _textDark = Color(0xFF1A1A1A);
  static const Color _textMuted = Color(0xFF898686);
  static const Color _pink = Color(0xFFFF5A8D);

  late String _categoryLabel = widget.categoryLabel;
  late String _title = widget.title;
  late String _body = ContentService.normalizeHtmlToText(widget.body);
  late String _imageUrl = ContentService.resolveDisplayImageUrl(
    thumbnail: widget.imageUrl,
    contentHtml: widget.body,
    fallback: 'https://placehold.co/321x200',
  );
  String? _bodyImageUrl;
  String? _prevTitle;
  int? _prevId;
  String? _nextTitle;
  int? _nextId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _prevTitle = widget.prevTitle;
    _nextTitle = widget.nextTitle;
    _bodyImageUrl = ContentService.resolveFirstBodyImageUrl(widget.body);
    if (widget.contentId != null) {
      _fetchDetail(widget.contentId!);
    }
  }

  Future<void> _fetchDetail(int id) async {
    setState(() => _isLoading = true);
    final result = await ContentService.getContentDetail(id);
    if (!mounted) return;
    if (result['success'] == true) {
      final data = result['data'] as Map<String, dynamic>? ?? const {};
      final prev = result['prev'] as Map<String, dynamic>?;
      final next = result['next'] as Map<String, dynamic>?;
      setState(() {
        _categoryLabel = data['category']?.toString().trim().isNotEmpty == true
            ? data['category'].toString()
            : _categoryLabel;
        _title = data['title']?.toString().trim().isNotEmpty == true
            ? data['title'].toString()
            : _title;
        _body = data['content_html']?.toString().trim().isNotEmpty == true
            ? ContentService.normalizeHtmlToText(data['content_html'].toString())
            : _body;
        final thumb = data['thumbnail_url']?.toString();
        final contentHtml = data['content_html']?.toString();
        _bodyImageUrl = ContentService.resolveFirstBodyImageUrl(contentHtml);
        _imageUrl = ContentService.resolveDisplayImageUrl(
          thumbnail: thumb,
          contentHtml: contentHtml,
          fallback: _imageUrl,
        );
        _prevTitle = prev?['title']?.toString();
        _prevId = _toInt(prev?['id']);
        _nextTitle = next?['title']?.toString();
        _nextId = _toInt(next?['id']);
      });
    }
    setState(() => _isLoading = false);
  }

  int? _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v');

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: const HealthAppBar(
        title: '건강 콘텐츠',
        centerTitle: true,
        leadingType: HealthAppBarLeadingType.back,
      ),
      backgroundColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildArticleHeader(),
                  const SizedBox(height: 20),
                  Container(height: 1, color: const Color(0x7FD2D2D2)),
                  const SizedBox(height: 20),
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(
                        color: Color(0xFFFF5A8D),
                      ),
                    ),
                  Text(
                    _body,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: _textDark,
                      fontSize: 12,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                      height: 2.08,
                      letterSpacing: -1.08,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      _imageUrl,
                      width: double.infinity,
                      fit: BoxFit.fitWidth,
                      errorBuilder: (_, __, ___) => Container(
                        height: 200,
                        color: const Color(0xFFF2F2F2),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          color: Color(0xFFBDBDBD),
                        ),
                      ),
                    ),
                  ),
                  if (_bodyImageUrl != null &&
                      _bodyImageUrl!.isNotEmpty &&
                      _bodyImageUrl != _imageUrl) ...[
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        _bodyImageUrl!,
                        width: double.infinity,
                        fit: BoxFit.fitWidth,
                        errorBuilder: (_, __, ___) => Container(
                          height: 200,
                          color: const Color(0xFFF2F2F2),
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: Color(0xFFBDBDBD),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 100),
                  if (_prevId != null && (_prevTitle?.trim().isNotEmpty ?? false))
                    _buildPrevNextRow(
                      context: context,
                      label: '이전글',
                      articleTitle: _prevTitle!,
                      icon: Icons.chevron_left,
                      targetId: _prevId!,
                    ),
                  if (_prevId != null && (_prevTitle?.trim().isNotEmpty ?? false))
                    const SizedBox(height: 10),
                  if (_nextId != null && (_nextTitle?.trim().isNotEmpty ?? false))
                    _buildPrevNextRow(
                      context: context,
                      label: '다음글',
                      articleTitle: _nextTitle!,
                      icon: Icons.chevron_right,
                      targetId: _nextId!,
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          _buildBottomActionBar(context),
          const ContentBottomNavBar(),
        ],
      ),
    );
  }

  Widget _buildArticleHeader() {
    return Column(
      children: [
        Text(
          _categoryLabel,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _textMuted,
            fontSize: 12,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
            height: 1.67,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _textDark,
            fontSize: 16,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w700,
            letterSpacing: -1.44,
          ),
        ),
      ],
    );
  }

  Widget _buildPrevNextRow({
    required BuildContext context,
    required String label,
    required IconData icon,
    required String articleTitle,
    required int targetId,
  }) {
    return InkWell(
      onTap: () => Navigator.pushReplacementNamed(
        context,
        '/content/detail',
        arguments: {'id': targetId},
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: _textMuted),
              const SizedBox(width: 2),
              Text(
                label,
                style: const TextStyle(
                  color: _textMuted,
                  fontSize: 14,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              articleTitle,
              maxLines: 2,
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
    );
  }

  Widget _buildBottomActionBar(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 27, vertical: 10),
      decoration: const ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(width: 1, color: Color(0x33E0BEC4)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: const Icon(Icons.favorite_border, size: 24, color: _textDark),
                onPressed: () {},
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                icon: const Icon(Icons.share_outlined, size: 24, color: _textDark),
                onPressed: () {},
              ),
            ],
          ),
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: _pink,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/content/list'),
            child: const Text(
              '목록',
              style: TextStyle(
                fontSize: 14,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
