import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../../data/services/auth_service.dart';
import '../../../../data/services/content_service.dart';
import '../../../../data/services/wish_service.dart';
import '../../../common/widgets/app_bar.dart';
import '../../../common/widgets/bottom_bar.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';

/// 콘텐츠 상세 (본문, 이전/다음 글, 찜·추천·목록)
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

  bool? _isWished;
  int _recommendCount = 0;
  bool _wishBusy = false;
  bool _recommendBusy = false;

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
      final rc = data['recommend_count'];
      final recCount = rc is num
          ? rc.toInt()
          : int.tryParse('$rc') ?? 0;
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
        _recommendCount = recCount;
      });
      await _loadWishState();
    }
    setState(() => _isLoading = false);
  }

  Future<void> _loadWishState() async {
    final id = _currentContentId;
    if (id == null || !mounted) return;
    final wished = await WishService.isWished('$id');
    if (mounted) setState(() => _isWished = wished);
  }

  Future<void> _toggleWish() async {
    final id = _currentContentId;
    if (id == null || _wishBusy) return;
    final user = await AuthService.getUser();
    if (!mounted) return;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인 후 찜할 수 있습니다.')),
      );
      return;
    }
    setState(() => _wishBusy = true);
    try {
      final r = await WishService.addToWish('$id', wiItKind: 'content');
      final wished = r['is_wished'] == true;
      if (mounted) setState(() => _isWished = wished);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('찜 처리에 실패했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _wishBusy = false);
    }
  }

  Future<void> _onRecommend() async {
    final id = _currentContentId;
    if (id == null || _recommendBusy) return;
    setState(() => _recommendBusy = true);
    try {
      final r = await ContentService.recommendContent(id);
      if (!mounted) return;
      if (r['success'] == true) {
        final c = r['recommend_count'];
        final n = c is num
            ? c.toInt()
            : int.tryParse('$c') ?? _recommendCount + 1;
        setState(() => _recommendCount = n);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              r['message']?.toString().trim().isNotEmpty == true
                  ? r['message'].toString()
                  : '추천해 주셔서 감사합니다.',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(r['message']?.toString() ?? '추천에 실패했습니다.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _recommendBusy = false);
    }
  }

  int? _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v');

  /// 진입 탭·글 카테고리 기준 앱바 제목 (API `category` 반영)
  String get _appBarTitle {
    final t = _categoryLabel.trim();
    if (t.isEmpty) return '콘텐츠';
    return t;
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: HealthAppBar(
        title: _appBarTitle,
        centerTitle: false,
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
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  if (_currentContentId != null) ...[
                    const SizedBox(height: 20),
                    _buildDetailPostNavActions(context),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          const BottomBar(),
        ],
      ),
    );
  }

  Widget _buildDetailPostNavActions(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(width: 1, color: Color(0x33E0BEC4))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            tooltip: '찜',
            icon: Icon(
              _isWished == true ? Icons.favorite : Icons.favorite_border,
              size: 24,
              color: _isWished == true ? _pink : _textDark,
            ),
            onPressed: (_wishBusy || _currentContentId == null) ? null : _toggleWish,
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            tooltip: '이 글 추천',
            icon: _recommendBusy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _pink,
                    ),
                  )
                : const Icon(Icons.thumb_up_outlined, size: 24, color: _textDark),
            onPressed:
                (_recommendBusy || _currentContentId == null) ? null : _onRecommend,
          ),
          if (_recommendCount > 0)
            Text(
              '$_recommendCount',
              style: const TextStyle(
                fontSize: 13,
                color: _textMuted,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          const Spacer(),
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

  Widget _buildArticleHeader() {
    return Text(
      _title,
      textAlign: TextAlign.start,
      style: const TextStyle(
        color: _textDark,
        fontSize: 16,
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: FontWeight.w700,
        letterSpacing: -1.44,
      ),
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
        arguments: {
          'id': targetId,
          'category': _categoryLabel,
        },
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
}
