import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:share_plus/share_plus.dart';

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
  late String _bodyHtml = widget.body;
  String? _prevTitle;
  int? _prevId;
  String? _nextTitle;
  int? _nextId;
  bool _isLoading = false;
  int? _currentContentId;

  @override
  void initState() {
    super.initState();
    _currentContentId = widget.contentId;
    _prevTitle = widget.prevTitle;
    _nextTitle = widget.nextTitle;
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
        _bodyHtml = data['content_html']?.toString().trim().isNotEmpty == true
            ? data['content_html'].toString()
            : _bodyHtml;
        _currentContentId = _toInt(data['id']) ?? id;
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
                  const SizedBox(height: 16),
                  _buildBodyContent(),
                  const SizedBox(height: 100),
                  if (_prevId != null && (_prevTitle?.trim().isNotEmpty ?? false))
                    _buildPrevNextRow(
                      context: context,
                      label: '이전글',
                      articleTitle: _prevTitle!,
                      icon: Icons.keyboard_arrow_up,
                      targetId: _prevId!,
                    ),
                  if (_prevId != null && (_prevTitle?.trim().isNotEmpty ?? false))
                    const SizedBox(height: 10),
                  if (_nextId != null && (_nextTitle?.trim().isNotEmpty ?? false))
                    _buildPrevNextRow(
                      context: context,
                      label: '다음글',
                      articleTitle: _nextTitle!,
                      icon: Icons.keyboard_arrow_down,
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
                  fontSize: 12,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 12,
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
                onPressed: () => _shareContent(context),
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

  Widget _buildBodyContent() {
    final processedHtml = ContentService.prepareContentHtmlForRender(_bodyHtml);
    if (processedHtml.trim().isEmpty) {
      final bodyText = ContentService.normalizeHtmlToText(_bodyHtml);
      return Text(
        bodyText,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _textDark,
          fontSize: 12,
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
          height: 2.08,
          letterSpacing: -1.08,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width - 54;
        return SizedBox(
          width: maxWidth,
          child: Html(
            data: processedHtml,
            style: {
              'html': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
              'body': Style(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
                fontFamily: 'Gmarket Sans TTF',
                fontSize: FontSize(12),
                fontWeight: FontWeight.w500,
                lineHeight: const LineHeight(1.8),
                textAlign: TextAlign.center,
                color: _textDark,
              ),
              'p': Style(
                margin: Margins.only(bottom: 10),
                padding: HtmlPaddings.zero,
                textAlign: TextAlign.center,
              ),
              'img': Style(
                width: Width(maxWidth),
                display: Display.block,
                margin: Margins.symmetric(vertical: 8),
              ),
              'div': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
              'span': Style(fontFamily: 'Gmarket Sans TTF'),
            },
          ),
        );
      },
    );
  }

  Future<void> _shareContent(BuildContext anchorContext) async {
    final currentUrl = Uri.base.toString();
    final shareUrl = _currentContentId != null
        ? '$currentUrl${currentUrl.contains('?') ? '&' : '?'}contentId=$_currentContentId'
        : currentUrl;
    final text = '$_title\n$shareUrl';

    // Flutter Web에서 share_plus가 window.dart assertion을 유발하는 환경이 있어
    // 웹은 클립보드 복사로 안정적으로 공유 UX를 제공합니다.
    if (kIsWeb) {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공유 링크를 복사했습니다.')),
      );
      return;
    }

    final box = anchorContext.findRenderObject() as RenderBox?;
    final Rect? origin =
        box != null && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: text,
          title: _title,
          subject: _title,
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('공유를 지원하지 않아 링크를 복사했습니다.')),
      );
    }
  }
}
