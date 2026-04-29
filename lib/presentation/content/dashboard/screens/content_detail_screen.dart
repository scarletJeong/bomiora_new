import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../../data/services/auth_service.dart';
import '../../../../data/services/content_service.dart';
import '../../../../data/services/health_profile_service.dart';
import '../../../../data/services/wish_service.dart';
import '../../../common/widgets/app_bar.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';

/// 콘텐츠 상세 (본문, 이전/다음 글, 찜·추천·목록) — 본문·제목 등은 API로만 표시
class ContentDetailScreen extends StatefulWidget {
  const ContentDetailScreen({super.key, this.contentId});

  final int? contentId;

  static ContentDetailScreen fromArgs(Object? args) {
    if (args is Map<String, dynamic>) {
      final idRaw = args['id'];
      final id = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw');
      return ContentDetailScreen(contentId: id);
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

  String _categoryLabel = '';
  String _title = '';
  String _bodyHtml = '';
  String? _prevTitle;
  int? _prevId;
  String? _nextTitle;
  int? _nextId;
  bool _isLoading = false;
  int? _currentContentId;
  String? _fetchError;

  bool? _isWished;
  int _recommendCount = 0;
  /// 서버 `user_recommended` — 로그인·문진 기준(프로필당 글 1회)
  bool? _userRecommended;
  int _recommendPfNo = 0;
  bool _wishBusy = false;
  bool _recommendBusy = false;

  @override
  void initState() {
    super.initState();
    _currentContentId = widget.contentId;
    final id = widget.contentId;
    if (id != null) {
      _fetchDetail(id);
    } else {
      _isLoading = false;
    }
  }

  Future<void> _fetchDetail(int id) async {
    setState(() {
      _isLoading = true;
      _fetchError = null;
    });
    String? mbId;
    int pfNo = 0;
    try {
      final u = await AuthService.getUser();
      if (u != null) {
        mbId = u.id;
        final hp = await HealthProfileService.getHealthProfile(u.id);
        pfNo = hp?.pfNo ?? 0;
        if (pfNo < 0) pfNo = 0;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _recommendPfNo = pfNo);
    }
    final result = await ContentService.getContentDetail(
      id,
      mbId: mbId,
      pfNo: pfNo,
    );
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
        _fetchError = null;
        _categoryLabel = data['category']?.toString().trim() ?? '';
        _title = data['title']?.toString().trim() ?? '';
        _bodyHtml = data['content_html']?.toString() ?? '';
        _currentContentId = _toInt(data['id']) ?? id;
        _prevTitle = prev?['title']?.toString();
        _prevId = _toInt(prev?['id']);
        _nextTitle = next?['title']?.toString();
        _nextId = _toInt(next?['id']);
        _recommendCount = recCount;
        if (data.containsKey('user_recommended')) {
          final ur = data['user_recommended'];
          _userRecommended = ur is bool
              ? ur
              : ur == true || ur == 1 || ur == '1' || ur == 'true';
        } else {
          _userRecommended = null;
        }
      });
      await _loadWishState();
    } else {
      setState(() {
        _fetchError = result['message']?.toString();
      });
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
      return;
    }
    setState(() => _wishBusy = true);
    try {
      final r = await WishService.addToWish('$id', wiItKind: 'content');
      final wished = r['is_wished'] == true;
      if (mounted) setState(() => _isWished = wished);
    } catch (e) {
    } finally {
      if (mounted) setState(() => _wishBusy = false);
    }
  }

  Future<void> _onRecommend() async {
    final id = _currentContentId;
    if (id == null || _recommendBusy) return;
    if (_userRecommended == true) return;
    final user = await AuthService.getUser();
    if (!mounted) return;
    if (user == null) {
      return;
    }
    int pfNo = _recommendPfNo;
    try {
      final hp = await HealthProfileService.getHealthProfile(user.id);
      pfNo = hp?.pfNo ?? 0;
      if (pfNo < 0) pfNo = 0;
    } catch (_) {}
    if (mounted) setState(() => _recommendPfNo = pfNo);
    setState(() => _recommendBusy = true);
    try {
      final r = await ContentService.recommendContent(
        id,
        mbId: user.id,
        pfNo: pfNo,
      );
      if (!mounted) return;
      if (r['success'] == true) {
        final c = r['recommend_count'];
        final n = c is num
            ? c.toInt()
            : int.tryParse('$c') ?? _recommendCount + 1;
        setState(() {
          _recommendCount = n;
          _userRecommended = true;
        });
      } else {
        if (r['already_recommended'] == true) {
          final c = r['recommend_count'];
          final n = c is num
              ? c.toInt()
              : int.tryParse('$c') ?? _recommendCount;
          setState(() {
            _recommendCount = n;
            _userRecommended = true;
          });
        }
      }
    } finally {
      if (mounted) setState(() => _recommendBusy = false);
    }
  }

  int? _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v');

  String get _appBarTitle => _categoryLabel.trim();

  @override
  Widget build(BuildContext context) {
    if (widget.contentId == null) {
      return MobileAppLayoutWrapper(
        appBar: HealthAppBar(
          title: _appBarTitle,
          centerTitle: false,
          leadingType: HealthAppBarLeadingType.back,
        ),
        backgroundColor: Colors.white,
        child: const Center(
          child: Icon(Icons.error_outline, size: 48, color: _textMuted),
        ),
      );
    }

    if (_fetchError != null && !_isLoading) {
      return MobileAppLayoutWrapper(
        appBar: HealthAppBar(
          title: _appBarTitle,
          centerTitle: false,
          leadingType: HealthAppBarLeadingType.back,
        ),
        backgroundColor: Colors.white,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              _fetchError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _textDark,
                fontSize: 14,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

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
                : Icon(
                    _userRecommended == true
                        ? Icons.thumb_up
                        : Icons.thumb_up_outlined,
                    size: 24,
                    color: _userRecommended == true ? _pink : _textDark,
                  ),
            onPressed: (_recommendBusy ||
                    _currentContentId == null ||
                    _userRecommended == true)
                ? null
                : _onRecommend,
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
    if (_title.isEmpty) return const SizedBox.shrink();
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
          if (_categoryLabel.isNotEmpty) 'category': _categoryLabel,
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
    if (_isLoading) return const SizedBox.shrink();
    final processedHtml = ContentService.prepareContentHtmlForRender(_bodyHtml);
    if (processedHtml.trim().isEmpty) {
      final bodyText = ContentService.normalizeHtmlToText(_bodyHtml);
      if (bodyText.trim().isEmpty) {
        return const SizedBox.shrink();
      }
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
