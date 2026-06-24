import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/content_service.dart';
import '../../../../data/services/health_profile_service.dart';
import '../../../../data/services/wish_service.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';

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
        ),
        backgroundColor: Colors.white,
        child: Center(
          child: Icon(
            Icons.error_outline,
            size: healthDp(context, 48),
            color: _textMuted,
          ),
        ),
      );
    }

    if (_fetchError != null && !_isLoading) {
      return MobileAppLayoutWrapper(
        appBar: HealthAppBar(
          title: _appBarTitle,
          centerTitle: false,
        ),
        backgroundColor: Colors.white,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: healthDp(context, 27)),
            child: Text(
              _fetchError!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _textDark,
                fontSize: healthSp(context, 14),
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
      ),
      backgroundColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                healthDp(context, 27),
                healthDp(context, 10),
                healthDp(context, 27),
                healthDp(context, 16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildArticleHeader(context),
                  SizedBox(height: healthDp(context, 20)),
                  Container(
                    height: healthDp(context, 1),
                    color: const Color(0x7FD2D2D2),
                  ),
                  SizedBox(height: healthDp(context, 20)),
                  if (_isLoading)
                    Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: healthDp(context, 24),
                      ),
                      child: const CircularProgressIndicator(
                        color: Color(0xFFFF5A8D),
                      ),
                    ),
                  SizedBox(height: healthDp(context, 16)),
                  _buildBodyContent(context),
                  SizedBox(height: healthDp(context, 24)),
                  if (_prevId != null &&
                      (_prevTitle?.trim().isNotEmpty ?? false))
                    _buildPrevNextRow(
                      context: context,
                      label: '이전글',
                      articleTitle: _prevTitle!,
                      icon: Icons.keyboard_arrow_up,
                      targetId: _prevId!,
                    ),
                  if (_prevId != null &&
                      (_prevTitle?.trim().isNotEmpty ?? false))
                    SizedBox(height: healthDp(context, 10)),
                  if (_nextId != null &&
                      (_nextTitle?.trim().isNotEmpty ?? false))
                    _buildPrevNextRow(
                      context: context,
                      label: '다음글',
                      articleTitle: _nextTitle!,
                      icon: Icons.keyboard_arrow_down,
                      targetId: _nextId!,
                    ),
                ],
              ),
            ),
          ),
          if (_currentContentId != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: healthDp(context, 1),
                  color: const Color(0x33E0BEC4),
                ),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: healthDp(context, 27)),
                  child: _buildDetailPostNavActions(context),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildDetailPostNavActions(BuildContext context) {
    final iconSz = healthDp(context, 24);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: healthDp(context, 5)),
      color: Colors.white,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: (_wishBusy || _currentContentId == null)
                ? null
                : _toggleWish,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: EdgeInsets.all(healthDp(context, 0)),
              child: SvgPicture.asset(
                AppAssets.heartIcon,
                width: iconSz,
                height: iconSz,
                fit: BoxFit.contain,
                colorFilter: ColorFilter.mode(
                  _isWished == true ? _pink : _textDark,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          SizedBox(width: healthDp(context, 10)),
          IgnorePointer(
            ignoring: _userRecommended == true,
            child: GestureDetector(
              onTap: (_recommendBusy ||
                      _currentContentId == null ||
                      _userRecommended == true)
                  ? null
                  : _onRecommend,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.all(healthDp(context, 0)),
                child: (_recommendBusy && _userRecommended != true)
                    ? SizedBox(
                        width: iconSz,
                        height: iconSz,
                        child: const CircularProgressIndicator(
                          strokeWidth: 1,
                          color: _pink,
                        ),
                      )
                    : SvgPicture.asset(
                        AppAssets.thumbUpIcon,
                        width: iconSz,
                        height: iconSz,
                        fit: BoxFit.contain,
                        colorFilter: ColorFilter.mode(
                          _userRecommended == true ? _pink : _textDark,
                          BlendMode.srcIn,
                        ),
                      ),
              ),
            ),
          ),
          if (_recommendCount > 0) ...[
            SizedBox(width: healthDp(context, 3)),
            Text(
              '$_recommendCount',
              style: TextStyle(
                fontSize: healthSp(context, 14),
                color: _textMuted,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const Spacer(),
          GestureDetector(
            onTap: () =>
                Navigator.pushReplacementNamed(context, '/content/list'),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: healthDp(context, 15),
                vertical: healthDp(context, 6),
              ),
              decoration: BoxDecoration(
                color: _pink,
                borderRadius: BorderRadius.circular(healthDp(context, 4)),
              ),
              child: Text(
                '목록',
                style: TextStyle(
                  fontSize: healthSp(context, 14),
                  color: Colors.white,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArticleHeader(BuildContext context) {
    if (_title.isEmpty) return const SizedBox.shrink();
    return Text(
      _title,
      textAlign: TextAlign.start,
      style: TextStyle(
        color: const Color(0xFF1A1A1A),
        fontSize: healthSp(context, 16),
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: FontWeight.w500,
        letterSpacing: healthSp(context, -1.44),
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
              Icon(icon, size: healthDp(context, 16), color: _textMuted),
              SizedBox(width: healthDp(context, 2)),
              Text(
                label,
                style: TextStyle(
                  color: _textMuted,
                  fontSize: healthSp(context, 12),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(width: healthDp(context, 5)),
          Expanded(
            child: Text(
              articleTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.black,
                fontSize: healthSp(context, 12),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(BuildContext context) {
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
        style: TextStyle(
          color: _textDark,
          fontSize: healthSp(context, 12),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
          height: 2.08,
          letterSpacing: healthSp(context, -1.08),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final hPad = healthDp(context, 27);
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width - hPad * 2;
        final bodyFontSize = healthSp(context, 12);

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
                fontSize: FontSize(bodyFontSize),
                fontWeight: FontWeight.w500,
                lineHeight: const LineHeight(1.8),
                textAlign: TextAlign.center,
                color: _textDark,
              ),
              'p': Style(
                margin: Margins.only(bottom: healthDp(context, 10)),
                padding: HtmlPaddings.zero,
                textAlign: TextAlign.center,
              ),
              'img': Style(
                width: Width(maxWidth),
                display: Display.block,
                margin: Margins.symmetric(vertical: healthDp(context, 8)),
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
