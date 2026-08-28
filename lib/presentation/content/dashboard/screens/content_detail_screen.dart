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
    // 상세 진입 시 문진표 전체 API를 타지 않음 (추천 시에만 pfNo 조회)
    const int pfNo = 0;
    try {
      final u = await AuthService.getUser();
      if (u != null) {
        mbId = u.id;
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _recommendPfNo = pfNo);
    }
    final results = await Future.wait([
      ContentService.getContentDetail(id, mbId: mbId, pfNo: pfNo),
      WishService.isWished('$id'),
    ]);
    final result = results[0] as Map<String, dynamic>;
    final wished = results[1] as bool;
    if (!mounted) return;
    setState(() => _isWished = wished);
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
    } else {
      setState(() {
        _fetchError = result['message']?.toString();
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _toggleWish() async {
    final id = _currentContentId;
    if (id == null || _wishBusy) return;
    final user = await AuthService.getUser();
    if (!mounted) return;
    if (user == null) {
      return;
    }
    final prev = _isWished == true;
    setState(() {
      _wishBusy = true;
      _isWished = !prev; // 즉시 채워진/테두리 아이콘 반영
    });
    try {
      final r = await WishService.addToWish('$id', wiItKind: 'content');
      final wished = r['is_wished'] == true;
      if (mounted) setState(() => _isWished = wished);
    } catch (e) {
      if (mounted) setState(() => _isWished = prev);
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
    if (pfNo <= 0) {
      try {
        final hp = await HealthProfileService.getHealthProfile(user.id);
        pfNo = hp?.pfNo ?? 0;
        if (pfNo < 0) pfNo = 0;
      } catch (_) {}
      if (mounted) setState(() => _recommendPfNo = pfNo);
    }
    final prevCount = _recommendCount;
    setState(() {
      _recommendBusy = true;
      _userRecommended = true; // 즉시 채워진 아이콘 반영
      _recommendCount = prevCount + 1;
    });
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
            : int.tryParse('$c') ?? _recommendCount;
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
        } else {
          setState(() {
            _userRecommended = false;
            _recommendCount = prevCount;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _userRecommended = false;
          _recommendCount = prevCount;
        });
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

  static const String _heartFilledSvg =
      '<svg width="42" height="42" viewBox="0 0 42 42" xmlns="http://www.w3.org/2000/svg">'
      '<path fill="#FF5A8D" d="M21.4202 11.1386L19.7037 9.42208C18.1103 7.82873 15.9493 6.93359 13.6959 6.93359C11.4426 6.93359 9.28154 7.82873 7.68819 9.42208C6.09485 11.0154 5.19971 13.1765 5.19971 15.4298C5.19971 17.6831 6.09485 19.8442 7.68819 21.4376L16.2335 29.9828C16.2458 29.9953 16.2582 30.0077 16.2706 30.0202L20.5619 34.3114C20.7988 34.5484 21.1095 34.6669 21.4202 34.6669C21.7309 34.6669 22.0416 34.5484 22.2785 34.3114L35.1522 21.4376C36.7455 19.8442 37.6407 17.6831 37.6407 15.4298C37.6407 13.1765 36.7455 11.0154 35.1522 9.42208C33.5588 7.82873 31.3978 6.93359 29.1444 6.93359C26.8911 6.93359 24.7301 7.82873 23.1367 9.42208L21.4202 11.1386Z"/>'
      '</svg>';

  static const String _thumbFilledSvg =
      '<svg width="24" height="24" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg">'
      '<path fill="#FF5A8D" d="M2 12.5C2 11.3954 2.89543 10.5 4 10.5C5.65685 10.5 7 11.8431 7 13.5V17.5C7 19.1569 5.65685 20.5 4 20.5C2.89543 20.5 2 19.6046 2 18.5V12.5Z"/>'
      '<path fill="#FF5A8D" d="M15.4787 7.80626L15.2124 8.66634C14.9942 9.37111 14.8851 9.72349 14.969 10.0018C15.0369 10.2269 15.1859 10.421 15.389 10.5487C15.64 10.7065 16.0197 10.7065 16.7791 10.7065H17.1831C19.7532 10.7065 21.0382 10.7065 21.6452 11.4673C21.7145 11.5542 21.7762 11.6467 21.8296 11.7437C22.2965 12.5921 21.7657 13.7351 20.704 16.0211C19.7297 18.1189 19.2425 19.1678 18.338 19.7852C18.2505 19.8449 18.1605 19.9013 18.0683 19.9541C17.116 20.5 15.9362 20.5 13.5764 20.5H13.0646C10.2057 20.5 8.77628 20.5 7.88814 19.6395C7 18.7789 7 17.3939 7 14.6239V13.6503C7 12.1946 7 11.4668 7.25834 10.8006C7.51668 10.1344 8.01135 9.58664 9.00069 8.49112L13.0921 3.96056C13.1947 3.84694 13.246 3.79012 13.2913 3.75075C13.7135 3.38328 14.3652 3.42464 14.7344 3.84235C14.774 3.8871 14.8172 3.94991 14.9036 4.07554C15.0388 4.27205 15.1064 4.37031 15.1654 4.46765C15.6928 5.33913 15.8524 6.37436 15.6108 7.35715C15.5838 7.46692 15.5488 7.5801 15.4787 7.80626Z"/>'
      '</svg>';

  Widget _buildActionIcon({
    required double size,
    required bool filled,
    required String outlineAsset,
    required String filledAsset,
    required String filledSvg,
  }) {
    // 활성 → 채워진 SVG / 비활성 → 테두리 SVG
    // filled 에셋이 아직 번들에 없으면 string으로 폴백
    if (filled) {
      return SvgPicture.string(
        filledSvg,
        key: ValueKey('filled_$filledAsset'),
        width: size,
        height: size,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(_pink, BlendMode.srcIn),
      );
    }
    return SvgPicture.asset(
      outlineAsset,
      key: ValueKey('outline_$outlineAsset'),
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: const ColorFilter.mode(_textDark, BlendMode.srcIn),
    );
  }

  Widget _buildDetailPostNavActions(BuildContext context) {
    final iconSz = healthDp(context, 24);
    final wished = _isWished == true;
    final recommended = _userRecommended == true;

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
              child: _buildActionIcon(
                size: iconSz,
                filled: wished,
                outlineAsset: AppAssets.heartIcon,
                filledAsset: AppAssets.heartIconFilled,
                filledSvg: _heartFilledSvg,
              ),
            ),
          ),
          SizedBox(width: healthDp(context, 10)),
          IgnorePointer(
            ignoring: recommended,
            child: GestureDetector(
              onTap: (_recommendBusy ||
                      _currentContentId == null ||
                      recommended)
                  ? null
                  : _onRecommend,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: EdgeInsets.all(healthDp(context, 0)),
                child: (_recommendBusy && !recommended)
                    ? SizedBox(
                        width: iconSz,
                        height: iconSz,
                        child: const CircularProgressIndicator(
                          strokeWidth: 1,
                          color: _pink,
                        ),
                      )
                    : _buildActionIcon(
                        size: iconSz,
                        filled: recommended,
                        outlineAsset: AppAssets.thumbUpIcon,
                        filledAsset: AppAssets.thumbUpIconFilled,
                        filledSvg: _thumbFilledSvg,
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
