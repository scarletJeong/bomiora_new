import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../data/models/content/content_post.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/content_service.dart';
import '../../../../data/services/wish_service.dart';
import '../../../common/navigation/board_list_navigation.dart';
import '../../../common/widgets/app_network_image.dart';
import '../../../common/widgets/centered_empty_state.dart';
import '../../../common/widgets/load_failure_notice.dart';
import '../../../common/widgets/login_required_dialog.dart';
import '../../../common/widgets/article_adjacent_nav.dart';
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
  static const Color _pink = Color(0xFFFF5A8D);

  String _categoryLabel = '';
  String _title = '';
  String _bodyHtml = '';
  String _thumbnailUrl = '';
  String? _prevTitle;
  int? _prevId;
  String? _nextTitle;
  int? _nextId;
  bool _isLoading = true;
  bool _loadFailed = false;
  int? _currentContentId;

  bool? _isWished;
  int _wishLoadToken = 0;
  int _recommendCount = 0;
  bool? _userRecommended;
  bool _wishBusy = false;
  bool _recommendBusy = false;
  String? _userId;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _currentContentId = widget.contentId;
    final id = widget.contentId;
    if (id != null) {
      _isLoading = true;
      _fetchDetail(id);
    } else {
      _isLoading = false;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _applyDetailResult(ContentDetailResult result, int id) {
    final post = result.post;
    if (!result.success || post == null) return;
    _loadFailed = false;
    _categoryLabel = post.category;
    _title = post.title;
    _bodyHtml = post.contentHtml;
    _thumbnailUrl = post.thumbnailUrl;
    _currentContentId = post.id ?? id;
    _prevTitle = result.previous?.title;
    _prevId = result.previous?.id;
    _nextTitle = result.next?.title;
    _nextId = result.next?.id;
    _recommendCount = post.recommendCount;
    final recommended = post.userRecommended;
    if (recommended != null) {
      _userRecommended = recommended;
    }
  }

  Future<void> _fetchDetail(int id) async {
    final cached = ContentService.peekDetail(id);
    if (cached != null && mounted) {
      setState(() {
        _applyDetailResult(cached, id);
        _isLoading = false;
      });
    } else if (mounted && !_isLoading) {
      setState(() {
        _isLoading = true;
        _loadFailed = false;
      });
    }

    String? mbId = _userId ?? AuthService.currentUser?.id;
    if (mbId == null) {
      try {
        mbId = (await AuthService.getUser())?.id;
      } catch (_) {}
    }
    if (mounted) {
      setState(() => _userId = mbId);
    }
    if (mbId != null && mbId.isNotEmpty) {
      _loadWishState(id, mbId);
    }
    final result = await ContentService.getContentDetail(
      id,
      mbId: mbId,
    );
    if (!mounted) return;
    if (result.success) {
      setState(() {
        _applyDetailResult(result, id);
        _loadFailed = false;
        _isLoading = false;
      });
    } else {
      setState(() {
        _loadFailed = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _retryDetail() async {
    final id = widget.contentId;
    if (id == null || _isLoading) return;
    setState(() {
      _isLoading = true;
      _loadFailed = false;
    });
    await _fetchDetail(id);
  }

  Future<void> _loadWishState(int id, String mbId) async {
    final token = ++_wishLoadToken;
    final peeked = WishService.peekIsWished(mbId, '$id');
    if (peeked != null &&
        mounted &&
        token == _wishLoadToken &&
        _currentContentId == id) {
      setState(() => _isWished = peeked);
    }
    try {
      final wished = await WishService.isWished('$id');
      if (!mounted || token != _wishLoadToken || _currentContentId != id) {
        return;
      }
      setState(() => _isWished = wished);
    } catch (_) {}
  }

  /// 로그인 세션이 없으면 공통 로그인 안내를 띄우고 null을 반환한다.
  Future<String?> _requireMemberId(String message) async {
    var mbId = _userId?.trim() ?? '';
    if (mbId.isEmpty) {
      try {
        mbId = (await AuthService.getUser())?.id.trim() ?? '';
      } catch (_) {}
      if (mbId.isNotEmpty && mounted) {
        setState(() => _userId = mbId);
      }
    }
    if (mbId.isEmpty) {
      if (!mounted) return null;
      await showLoginRequiredDialog(context, message: message);
      return null;
    }
    return mbId;
  }

  Future<void> _toggleWish() async {
    final id = _currentContentId;
    if (id == null || _wishBusy) return;
    final mbId = await _requireMemberId('찜하기는 로그인 후 이용할 수 있습니다.');
    if (mbId == null || !mounted) return;

    _wishLoadToken++;
    final prev = _isWished == true;
    setState(() {
      _wishBusy = true;
      _isWished = !prev;
    });
    try {
      final r = await WishService.addToWish(
        '$id',
        wiItKind: 'content',
        mbId: mbId,
      );
      if (!mounted) return;
      if (r['success'] == false) {
        setState(() => _isWished = prev);
      }
    } catch (_) {
      if (mounted) setState(() => _isWished = prev);
    } finally {
      if (mounted) setState(() => _wishBusy = false);
    }
  }

  Future<void> _onRecommend() async {
    final id = _currentContentId;
    if (id == null || _recommendBusy) return;
    final mbId = await _requireMemberId('추천은 로그인 후 이용할 수 있습니다.');
    if (mbId == null || !mounted) return;

    final prevRecommended = _userRecommended == true;
    final prevCount = _recommendCount;
    final nextRecommended = !prevRecommended;
    final nextCount = (prevCount + (nextRecommended ? 1 : -1)).clamp(0, 999999);
    setState(() {
      _recommendBusy = true;
      _userRecommended = nextRecommended;
      _recommendCount = nextCount;
    });
    Future<void>.delayed(const Duration(milliseconds: 80), () {
      if (mounted) setState(() => _recommendBusy = false);
    });
    try {
      final r = await ContentService.recommendContent(
        id,
        mbId: mbId,
        recommended: nextRecommended,
        recommendCount: nextCount,
      );
      if (!mounted) return;
      if (r['success'] == true) {
        final rec = r['recommended'];
        if (rec is bool) {
          _userRecommended = rec;
        }
        final c = r['recommend_count'];
        final n = c is num ? c.toInt() : int.tryParse('$c');
        if (n != null) _recommendCount = n;
        setState(() {});
      } else {
        setState(() {
          _userRecommended = prevRecommended;
          _recommendCount = prevCount;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _userRecommended = prevRecommended;
          _recommendCount = prevCount;
        });
      }
    } finally {
      if (mounted) setState(() => _recommendBusy = false);
    }
  }

  String get _appBarTitle => _categoryLabel.trim();

  @override
  Widget build(BuildContext context) {
    if (widget.contentId == null) {
      return MobileAppLayoutWrapper(
        appBar: HealthAppBar(
          title: _appBarTitle,
        ),
        backgroundColor: Colors.white,
        child: CenteredEmptyState(
          iconWidget: CenteredEmptyState.assetIcon(
            context,
            AppAssets.emptyContentIcon,
          ),
          message: '등록된 콘텐츠가 없습니다.',
        ),
      );
    }

    if (_loadFailed && _title.isEmpty && !_isLoading) {
      return MobileAppLayoutWrapper(
        appBar: HealthAppBar(
          title: _appBarTitle,
        ),
        backgroundColor: Colors.white,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: healthDp(context, 20)),
            child: LoadFailureNotice(
              message: '콘텐츠를 불러오지 못했습니다',
              onRetry: _retryDetail,
            ),
          ),
        ),
      );
    }

    return MobileAppLayoutWrapper(
      appBar: HealthAppBar(
        title: _appBarTitle,
      ),
      backgroundColor: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                SingleChildScrollView(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(
                    healthDp(context, 20),
                    healthDp(context, 20),
                    healthDp(context, 20),
                    _articleScrollBottomPadding(context),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_loadFailed) ...[
                        LoadFailureNotice(
                          message: '콘텐츠를 불러오지 못했습니다',
                          onRetry: _retryDetail,
                        ),
                        SizedBox(height: healthDp(context, 8)),
                      ],
                      _buildArticleHeader(context),
                      SizedBox(height: healthDp(context, 20)),
                      Container(
                        height: healthDp(context, 1),
                        color: const Color(0x7FD2D2D2),
                      ),
                      if (!_isLoading) ...[
                        SizedBox(height: healthDp(context, 20)),
                        _buildThumbnail(context),
                        _buildBodyContent(context),
                      ],
                    ],
                  ),
                ),
                if (_isLoading)
                  Center(
                    child: SizedBox(
                      width: healthDp(context, 36),
                      height: healthDp(context, 36),
                      child: const CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Color(0xFFFF5A8D),
                      ),
                    ),
                  ),
                ArticleAdjacentNavOverlay(
                  controller: _scrollController,
                  horizontalPaddingBase: 20,
                  verticalPaddingBase: 20,
                  iconBase: 16,
                  labelFontBase: 13,
                  labelTitleGapBase: 4,
                  previous: _prevId != null &&
                          (_prevTitle?.trim().isNotEmpty ?? false)
                      ? ArticleAdjacentItem(
                          title: _prevTitle!,
                          onTap: () => _openContent(_prevId!),
                        )
                      : null,
                  next: _nextId != null &&
                          (_nextTitle?.trim().isNotEmpty ?? false)
                      ? ArticleAdjacentItem(
                          title: _nextTitle!,
                          onTap: () => _openContent(_nextId!),
                        )
                      : null,
                ),
              ],
            ),
          ),
          if (_currentContentId != null) _buildDetailPostNavActions(context),
        ],
      ),
    );
  }

  Widget _buildActionIcon({
    required double size,
    required bool filled,
    required String outlineAsset,
    required String filledAsset,
  }) {
    final asset = filled ? filledAsset : outlineAsset;
    return SvgPicture.asset(
      asset,
      key: ValueKey(asset),
      width: size,
      height: size,
      fit: BoxFit.contain,
      colorFilter: ColorFilter.mode(
        filled ? _pink : _textDark,
        BlendMode.srcIn,
      ),
    );
  }

  Widget _buildDetailPostNavActions(BuildContext context) {
    final iconSz = healthDp(context, 24);
    final wished = _isWished == true;
    final recommended = _userRecommended == true;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 20),
        vertical: healthDp(context, 10),
      ),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1),
            color: const Color(0x33E0BEC4),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: (_wishBusy || _currentContentId == null)
                ? null
                : _toggleWish,
            behavior: HitTestBehavior.opaque,
            child: _buildActionIcon(
              size: iconSz,
              filled: wished,
              outlineAsset: AppAssets.heartIcon,
              filledAsset: AppAssets.heartIconFilled,
            ),
          ),
          SizedBox(width: healthDp(context, 16)),
          GestureDetector(
            onTap: (_recommendBusy || _currentContentId == null)
                ? null
                : _onRecommend,
            behavior: HitTestBehavior.opaque,
            child: _buildActionIcon(
              size: iconSz,
              filled: recommended,
              outlineAsset: AppAssets.thumbUpIcon,
              filledAsset: AppAssets.thumbUpIconFilled,
            ),
          ),
          if (_recommendCount > 0) ...[
            SizedBox(width: healthDp(context, 4)),
            Text(
              '$_recommendCount',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: healthSp(context, 14),
                color: _pink,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const Spacer(),
          GestureDetector(
            onTap: () => popToBoardList(
              context,
              '/content/list',
              aliases: const ['/content'],
            ),
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: healthDp(context, 20),
                vertical: healthDp(context, 12),
              ),
              decoration: BoxDecoration(
                color: _pink,
                borderRadius: BorderRadius.circular(healthDp(context, 8)),
              ),
              child: Text(
                '목록',
                style: TextStyle(
                  fontSize: healthSp(context, 15),
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
      textAlign: TextAlign.center,
      style: TextStyle(
        color: const Color(0xFF1A1A1A),
        fontSize: healthSp(context, 16),
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: FontWeight.w500,
        letterSpacing: healthSp(context, -1.44),
      ),
    );
  }

  bool get _hasPreviousArticle =>
      _prevId != null && (_prevTitle?.trim().isNotEmpty ?? false);

  bool get _hasNextArticle =>
      _nextId != null && (_nextTitle?.trim().isNotEmpty ?? false);

  /// 이전글/다음글이 본문 위에 겹치므로, 그 높이만큼 더 스크롤되게 한다.
  double _articleScrollBottomPadding(BuildContext context) {
    var rows = 0;
    if (_hasPreviousArticle) rows++;
    if (_hasNextArticle) rows++;
    final base = healthDp(context, 40);
    if (rows == 0) return base;
    final rowH = healthDp(context, 20) * 2 + healthDp(context, 16);
    final borders = healthDp(context, 1) * (rows + 1);
    return base + rowH * rows + borders;
  }

  void _openContent(int targetId) {
    Navigator.pushReplacementNamed(
      context,
      '/content/detail',
      arguments: {
        'id': targetId,
        if (_categoryLabel.isNotEmpty) 'category': _categoryLabel,
      },
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    final raw = _thumbnailUrl.trim();
    if (raw.isEmpty) return const SizedBox.shrink();
    final url = ContentService.resolveThumbnailUrl(raw, fallback: '');
    if (url.isEmpty) return const SizedBox.shrink();
    if (_bodyHtml.contains(raw)) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: healthDp(context, 24)),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final targetWidth = healthDp(context, 335);
          final width = constraints.maxWidth < targetWidth
              ? constraints.maxWidth
              : targetWidth;
          final height = healthDp(context, 200);
          return Align(
            alignment: Alignment.centerLeft,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(healthDp(context, 10)),
              child: AppNetworkImage(
                url: url,
                width: width,
                height: height,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                decodeWidthLogical: width,
                preferHtmlElementOnWeb: false,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          );
        },
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
        textAlign: TextAlign.start,
        style: TextStyle(
          color: _textDark,
          fontSize: healthSp(context, 14),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
          height: 1.43,
          letterSpacing: healthSp(context, -0.56),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final hPad = healthDp(context, 20);
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.of(context).size.width - hPad * 2;
        final bodyFontSize = healthSp(context, 14);
        final bodyText = Style(
          fontFamily: 'Gmarket Sans TTF',
          fontSize: FontSize(bodyFontSize),
          fontWeight: FontWeight.w500,
          lineHeight: const LineHeight(1.43),
          letterSpacing: healthSp(context, -0.56),
          textAlign: TextAlign.start,
          color: _textDark,
          whiteSpace: WhiteSpace.pre,
        );

        return SizedBox(
          width: maxWidth,
          child: Html(
            data: processedHtml,
            extensions: [
              TagExtension(
                tagsToExtend: const {'img'},
                builder: (extensionContext) {
                  final rawSrc = (extensionContext.attributes['src'] ?? '')
                      .trim()
                      .replaceAll('&amp;', '&');
                  if (rawSrc.isEmpty) return const SizedBox.shrink();
                  final url = ImageUrlHelper.toWebSafeImageUrl(rawSrc);
                  return Padding(
                    padding: EdgeInsets.only(bottom: healthDp(context, 8)),
                    child: AppNetworkImage(
                      url: url,
                      width: maxWidth,
                      fit: BoxFit.fitWidth,
                      alignment: Alignment.topCenter,
                      decodeWidthLogical: maxWidth,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  );
                },
              ),
            ],
            style: {
              'html': Style(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
                fontSize: FontSize(bodyFontSize),
                whiteSpace: WhiteSpace.pre,
              ),
              'body': bodyText.copyWith(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
              ),
              'p': bodyText.copyWith(
                margin: Margins.only(bottom: healthDp(context, 10)),
                padding: HtmlPaddings.zero,
              ),
              'div': bodyText.copyWith(
                margin: Margins.zero,
                padding: HtmlPaddings.zero,
              ),
              'span': bodyText,
              'li': bodyText,
              'font': bodyText,
              'strong': bodyText,
              'b': bodyText,
              'em': bodyText,
              'i': bodyText,
              'u': bodyText,
              'a': bodyText,
              'blockquote': bodyText,
              'h1': bodyText,
              'h2': bodyText,
              'h3': bodyText,
              'h4': bodyText,
              'h5': bodyText,
              'h6': bodyText,
              'img': Style(
                width: Width(maxWidth),
                display: Display.block,
                whiteSpace: WhiteSpace.normal,
                margin: Margins.symmetric(vertical: healthDp(context, 8)),
              ),
            },
          ),
        );
      },
    );
  }
}
