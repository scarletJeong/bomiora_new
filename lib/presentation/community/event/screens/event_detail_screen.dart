import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/logging/failure_log.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../data/models/event/event_model.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/content_service.dart';
import '../../../../data/services/event_service.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import '../../../common/navigation/board_list_navigation.dart';
import '../../../common/widgets/app_clickable.dart';
import '../../../common/widgets/app_network_image.dart';
import '../../../common/widgets/article_adjacent_nav.dart';
import '../../../common/widgets/centered_empty_state.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../health/health_common/health_responsive_scale.dart';

class EventDetailScreen extends StatefulWidget {
  final int wrId;

  const EventDetailScreen({
    super.key,
    required this.wrId,
  });

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  static const String _font = 'Gmarket Sans TTF';
  static const Color _kBorder = Color(0xFFD2D2D2);
  static const Color _kPink = Color(0xFFFF5A8D);

  EventModel? _event;
  bool _isLoading = true;
  bool _loadFailed = false;
  List<EventModel> _allEvents = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadEventDetail();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadEventDetail() async {
    setState(() => _isLoading = true);

    EventModel? event;
    var failed = false;
    try {
      event = await EventService.getEventDetail(widget.wrId);
    } catch (e) {
      failed = true;
      final user = await AuthService.getUser();
      await FailureLog.record(
        code: 'event.detail',
        mbId: user?.id ?? '',
        reason: e.toString(),
        detail: {'id': widget.wrId},
      );
    }

    var active = const <EventModel>[];
    if (!failed) {
      try {
        active = (await EventService.getActiveEvents())
            .where((e) => !e.isEnded)
            .toList();
      } catch (_) {
        active = const [];
      }
    }

    if (!mounted) return;

    if (failed || event == null) {
      if (!failed) {
        final user = await AuthService.getUser();
        await FailureLog.record(
          code: 'event.detail',
          mbId: user?.id ?? '',
          reason: '이벤트를 찾을 수 없습니다.',
          detail: {'id': widget.wrId},
        );
      }
      if (!mounted) return;
      setState(() {
        _event = null;
        _allEvents = active;
        _loadFailed = failed;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _event = event!.isEnded ? null : event;
      _allEvents = active;
      _loadFailed = false;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: _font),
      child: MobileAppLayoutWrapper(
        appBar: const HealthAppBar(title: '이벤트'),
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: const Color(0xFFFF5A8D)));
    }

    if (_event == null) {
      return CenteredEmptyState(
        iconWidget: CenteredEmptyState.assetIcon(
          context,
          AppAssets.emptyEventIcon,
        ),
        message: _loadFailed ? '불러오지 못했습니다' : '이벤트가 없습니다.',
      );
    }

    final event = _event!;
    final linkImage = (event.wrLink1 ?? '').trim();
    final imageUrl = linkImage.isEmpty ? null : event.getImageUrl();
    final prevEvent = _getPrevEvent();
    final nextEvent = _getNextEvent();

    final navHeight = ArticleAdjacentNav.reservedHeight(
      context,
      hasPrevious: prevEvent != null,
      hasNext: nextEvent != null,
    );

    return Column(
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
            healthDp(context, 20) + navHeight,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  _event!.wrSubject,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF1A1A1A),
                    fontSize: healthSp(context, 16),
                    fontFamily: _font,
                    fontWeight: FontWeight.w500,
                    letterSpacing: healthSp(context, -1.44),
                  ),
                ),
              ),
              SizedBox(height: healthDp(context, 10)),
              Container(height: healthDp(context, 1), color: _kBorder),
              SizedBox(height: healthDp(context, 30)),
              if (imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(healthDp(context, 10)),
                  child: AppNetworkImage(
                    url: imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: double.infinity,
                      height: healthDp(context, 240),
                      color: const Color(0xFFF4F4F4),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: healthDp(context, 42),
                        color: const Color(0xFF898686),
                      ),
                    ),
                  ),
                ),
              if (imageUrl != null) SizedBox(height: healthDp(context, 24)),
              _buildEventBody(context, _bodyHtml(event)),
              SizedBox(height: healthDp(context, 30)),
              Text(
                '이벤트 기간',
                style: TextStyle(
                  color: const Color(0xFF1A1A1A),
                  fontSize: healthSp(context, 14),
                  fontFamily: _font,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: healthDp(context, 5)),
              Padding(
                padding: EdgeInsets.only(left: healthDp(context, 20)),
                child: Text(
                  '- ${_periodText(_event!)}',
                  style: TextStyle(
                    color: const Color(0xFF1A1A1A),
                    fontSize: healthSp(context, 14),
                    fontFamily: _font,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        ArticleAdjacentNavOverlay(
          controller: _scrollController,
          verticalPaddingBase: 12,
          previous: prevEvent == null
              ? null
              : ArticleAdjacentItem(
                  title: prevEvent.wrSubject,
                  onTap: () => _openEvent(prevEvent.wrId),
                ),
          next: nextEvent == null
              ? null
              : ArticleAdjacentItem(
                  title: nextEvent.wrSubject,
                  onTap: () => _openEvent(nextEvent.wrId),
                ),
        ),
            ],
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(
            healthDp(context, 20),
            0,
            healthDp(context, 20),
            healthDp(context, 20),
          ),
          child: Align(
            alignment: Alignment.centerRight,
            child: AppClickable(
              onTap: () => popToBoardList(context, '/event'),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: healthDp(context, 15),
                  vertical: healthDp(context, 6),
                ),
                decoration: ShapeDecoration(
                  color: _kPink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(healthDp(context, 4)),
                  ),
                ),
                child: Text(
                  '목록',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: healthSp(context, 14),
                    fontFamily: _font,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 대표 이미지와 같은 본문 이미지는 한 번만 보여 준다.
  String _bodyHtml(EventModel event) {
    final hero = (event.wrLink1 ?? '').trim();
    if (hero.isEmpty) return event.wrContent;
    final heroPath = Uri.tryParse(hero)?.path ?? hero;
    return event.wrContent.replaceAllMapped(
      RegExp(r'<img\b[^>]*>', caseSensitive: false),
      (match) {
        final tag = match.group(0) ?? '';
        final src = RegExp(
          '''src\\s*=\\s*["']([^"']+)["']''',
          caseSensitive: false,
        ).firstMatch(tag)?.group(1)?.trim();
        if (src == null || src.isEmpty) return tag;
        final srcPath = Uri.tryParse(src)?.path ?? src;
        if (src == hero || srcPath == heroPath || src.endsWith(heroPath)) {
          return '';
        }
        return tag;
      },
    );
  }

  Widget _buildEventBody(BuildContext context, String rawHtml) {
    final processed = ContentService.prepareContentHtmlForRender(rawHtml);
    if (processed.trim().isEmpty) {
      final plain = ContentService.normalizeHtmlToText(rawHtml);
      if (plain.isEmpty) return const SizedBox.shrink();
      return Text(
        plain,
        style: TextStyle(
          color: const Color(0xFF1A1A1A),
          fontSize: healthSp(context, 14),
          fontFamily: _font,
          fontWeight: FontWeight.w300,
          height: 1.7,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - healthDp(context, 40);
        return Html(
          data: processed,
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
                    errorBuilder: (_, __, ___) => Container(
                      width: maxWidth,
                      height: healthDp(context, 180),
                      alignment: Alignment.center,
                      color: const Color(0xFFF6F6F6),
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: const Color(0xFF898686),
                        size: healthDp(context, 32),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
          style: {
            'html': Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              whiteSpace: WhiteSpace.pre,
            ),
            'body': Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              fontFamily: _font,
              fontSize: FontSize(healthSp(context, 14)),
              fontWeight: FontWeight.w300,
              lineHeight: const LineHeight(1.7),
              textAlign: TextAlign.start,
              color: const Color(0xFF1A1A1A),
              whiteSpace: WhiteSpace.pre,
            ),
            'p': Style(
              margin: Margins.only(bottom: healthDp(context, 8)),
              padding: HtmlPaddings.zero,
              whiteSpace: WhiteSpace.pre,
            ),
            'img': Style(
              width: Width(maxWidth),
              display: Display.block,
              margin: Margins.symmetric(vertical: healthDp(context, 8)),
            ),
            'div': Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              whiteSpace: WhiteSpace.pre,
            ),
            'span': Style(
              fontFamily: _font,
              whiteSpace: WhiteSpace.pre,
            ),
          },
        );
      },
    );
  }

  void _openEvent(int wrId) {
    EventModel? target;
    for (final e in _allEvents) {
      if (e.wrId == wrId) {
        target = e;
        break;
      }
    }
    if (target == null || target.isEnded) return;
    Navigator.pushReplacementNamed(context, '/event/$wrId');
  }

  List<EventModel> get _navEvents =>
      _allEvents.where((e) => !e.isEnded).toList();

  EventModel? _getPrevEvent() {
    if (_event == null) return null;
    final list = _navEvents;
    final index = list.indexWhere((e) => e.wrId == _event!.wrId);
    if (index <= 0) return null;
    return list[index - 1];
  }

  EventModel? _getNextEvent() {
    if (_event == null) return null;
    final list = _navEvents;
    final index = list.indexWhere((e) => e.wrId == _event!.wrId);
    if (index == -1 || index >= list.length - 1) return null;
    return list[index + 1];
  }

  String _periodText(EventModel event) {
    final start = DateDisplayFormatter.tryParseYmdFlexible(event.wr1);
    final end = DateDisplayFormatter.tryParseYmdFlexible(event.wr2);
    if (start != null && end != null) {
      return '${DateDisplayFormatter.formatYmd(start)} ~ ${DateDisplayFormatter.formatYmd(end)}';
    }
    if (start != null) {
      return '${DateDisplayFormatter.formatYmd(start)} ~';
    }
    if (end != null) {
      return '~ ${DateDisplayFormatter.formatYmd(end)}';
    }
    return DateDisplayFormatter.formatYmdFromString(event.wrDatetime);
  }
}
