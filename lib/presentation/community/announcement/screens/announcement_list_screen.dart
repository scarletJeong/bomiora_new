import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/logging/failure_log.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/announcement/announcement_model.dart';
import '../../../../data/services/announcement_service.dart';
import '../../../../data/services/auth_service.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/centered_empty_state.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import '../../../common/widgets/app_clickable.dart';
import '../../../health/health_common/health_responsive_scale.dart';

class AnnouncementListScreen extends StatefulWidget {
  const AnnouncementListScreen({super.key});

  @override
  State<AnnouncementListScreen> createState() => _AnnouncementListScreenState();
}

class _AnnouncementListScreenState extends State<AnnouncementListScreen> {
  static const Color _kText = Color(0xFF1A1A1E);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kBorder = Color(0x7FD2D2D2);
  static const Color _kPink = Color(0xFFFF5A8D);

  final TextEditingController _searchController = TextEditingController();
  static const int _size = 5;

  bool _loading = false;
  bool _loadingMore = false;
  String _query = '';
  String? _error;
  int _page = 1;
  int _total = 0;
  List<AnnouncementModel> _items = const [];

  bool get _hasMore => _items.length < _total;

  void _submitSearch() {
    _load(page: 1, query: _searchController.text.trim());
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({int? page, String? query, bool append = false}) async {
    if (append) {
      if (_loading || _loadingMore || !_hasMore) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    final targetPage = page ?? (append ? _page + 1 : _page);
    final targetQuery = query ?? _query;
    final result = await AnnouncementService.getAnnouncements(
      page: targetPage,
      size: _size,
      query: targetQuery,
    );

    if (!mounted) return;
    if (result['success'] == true) {
      final loaded = (result['items'] as List<AnnouncementModel>?) ?? [];
      setState(() {
        _items = append ? _appendById(_items, loaded) : loaded;
        _total = (result['total'] as num?)?.toInt() ?? 0;
        _page = (result['page'] as num?)?.toInt() ?? targetPage;
        _query = targetQuery;
        if (append) _loadingMore = false;
      });
    } else {
      final reason =
          result['message']?.toString() ?? '공지사항을 불러오지 못했습니다.';
      final user = await AuthService.getUser();
      await FailureLog.record(
        code: 'announcement.list',
        mbId: user?.id ?? '',
        reason: reason,
        detail: {'page': targetPage, 'query': targetQuery},
      );
      if (!mounted) return;
      if (!append) {
        setState(() {
          _error = reason;
        });
      }
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _loadingMore = false;
    });
  }

  List<AnnouncementModel> _appendById(
    List<AnnouncementModel> current,
    List<AnnouncementModel> incoming,
  ) {
    final seen = current.map((item) => item.id).toSet();
    return [
      ...current,
      ...incoming.where((item) => seen.add(item.id)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final showEmpty = !_loading && (_error != null || _items.isEmpty);
    return MobileAppLayoutWrapper(
      appBar: const HealthAppBar(title: '공지사항'),
      resizeToAvoidBottomInset: false,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  healthDp(context, 20),
                  healthDp(context, 10),
                  healthDp(context, 20),
                  healthDp(context, 10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSearchBar(context),
                    SizedBox(height: healthDp(context, 10)),
                    _buildTotalRow(context),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => _load(page: 1),
                  child: CustomScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.manual,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      if (_loading)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (showEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: SizedBox.shrink(),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            healthDp(context, 20),
                            0,
                            healthDp(context, 20),
                            healthDp(context, 48),
                          ),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              ..._items.map(
                                (item) => _buildNoticeCard(context, item),
                              ),
                              if (_hasMore) _buildMoreButton(context),
                            ]),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (showEmpty) PageCenteredEmptyOverlay(child: _buildEmpty(context)),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1),
            color: const Color(0xFFD2D2D2),
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(healthDp(context, 10)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _submitSearch(),
                style: TextStyle(
                  color: _kText,
                  fontSize: healthSp(context, 14),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w400,
                  height: 1,
                ),
                decoration: InputDecoration(
                  hintText: '검색',
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: _kMuted,
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                    height: 1,
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: _submitSearch,
              behavior: HitTestBehavior.opaque,
              child: SvgPicture.asset(
                AppAssets.searchIcon,
                width: healthDp(context, 18),
                height: healthDp(context, 18),
                fit: BoxFit.contain,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: healthDp(context, 1), color: _kBorder),
        SizedBox(height: healthDp(context, 5)),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '총 ',
                style: TextStyle(
                  color: _kMuted,
                  fontSize: healthSp(context, 12),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextSpan(
                text: '$_total',
                style: TextStyle(
                  color: _kPink,
                  fontSize: healthSp(context, 12),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: '건',
                style: TextStyle(
                  color: _kMuted,
                  fontSize: healthSp(context, 12),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: healthDp(context, 5)),
        Container(height: healthDp(context, 1), color: _kBorder),
      ],
    );
  }

  String _formatCount(int value) {
    final raw = value.toString();
    final buffer = StringBuffer();
    for (var i = 0; i < raw.length; i++) {
      if (i > 0 && (raw.length - i) % 3 == 0) buffer.write(',');
      buffer.write(raw[i]);
    }
    return buffer.toString();
  }

  String _noticeDateLabel(AnnouncementModel item) {
    final fromRaw = DateDisplayFormatter.formatYmdFromString(item.createdAtRaw);
    if (fromRaw != '-') return fromRaw;
    if (item.createdAt != null) {
      return DateDisplayFormatter.formatYmd(item.createdAt!);
    }
    return '-';
  }

  Widget _buildNoticeCard(BuildContext context, AnnouncementModel item) {
    final date = _noticeDateLabel(item);
    final title = item.title
        .replaceAll(r'\n', ' ')
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return Padding(
      padding: EdgeInsets.only(bottom: healthDp(context, 14)),
      child: AppClickable(
        onTap: () => Navigator.pushNamed(
          context,
          '/announcement/${item.id}',
        ),
        child: Container(
          padding: EdgeInsets.all(healthDp(context, 16)),
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: healthDp(context, 1),
              color: _kBorder,
            ),
            borderRadius: BorderRadius.circular(healthDp(context, 16)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: _kText,
                fontSize: healthSp(context, 14),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
                letterSpacing: healthSp(context, -1.26),
              ),
            ),
            SizedBox(height: healthDp(context, 10)),
            Row(
              spacing: healthDp(context, 10),
              children: [
                Text(
                  date,
                  style: TextStyle(
                    color: _kMuted,
                    fontSize: healthSp(context, 10),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    height: 1.65,
                  ),
                ),
                Text(
                  '조회 : ${_formatCount(item.viewCount)}',
                  style: TextStyle(
                    color: _kMuted,
                    fontSize: healthSp(context, 10),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    height: 1.65,
                  ),
                ),
              ],
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildMoreButton(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: healthDp(context, 2)),
      child: TextButton(
        onPressed: _loadingMore ? null : () => _load(append: true),
        style: TextButton.styleFrom(
          foregroundColor: _kPink,
          overlayColor: Colors.transparent,
          minimumSize: Size(double.infinity, healthDp(context, 36)),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: _loadingMore
            ? SizedBox(
                width: healthDp(context, 16),
                height: healthDp(context, 16),
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _kPink,
                ),
              )
            : Text(
                '더보기',
                style: TextStyle(
                  color: _kPink,
                  fontSize: healthSp(context, 13),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return CenteredEmptyState(
      iconWidget: CenteredEmptyState.assetIcon(
        context,
        AppAssets.emptyNoticeIcon,
      ),
      message: '공지사항이 없습니다.',
    );
  }
}
