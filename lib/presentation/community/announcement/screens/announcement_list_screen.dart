import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/announcement/announcement_model.dart';
import '../../../../data/services/announcement_service.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/centered_empty_state.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import 'announcement_detail_screen.dart';

class AnnouncementListScreen extends StatefulWidget {
  const AnnouncementListScreen({super.key});

  @override
  State<AnnouncementListScreen> createState() => _AnnouncementListScreenState();
}

class _AnnouncementListScreenState extends State<AnnouncementListScreen> {
  static const Color _kText = Color(0xFF1A1A1A);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kBorder = Color(0x7FD2D2D2);
  static const Color _kPink = Color(0xFFFF5A8D);

  final TextEditingController _searchController = TextEditingController();
  final int _size = 6;

  bool _loading = false;
  String _query = '';
  String? _error;
  int _page = 1;
  int _total = 0;
  int _totalPages = 1;
  List<AnnouncementModel> _items = const [];

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

  Future<void> _load({int? page, String? query}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final targetPage = page ?? _page;
    final targetQuery = query ?? _query;
    final result = await AnnouncementService.getAnnouncements(
      page: targetPage,
      size: _size,
      query: targetQuery,
    );

    if (!mounted) return;
    if (result['success'] == true) {
      final loaded = (result['items'] as List<AnnouncementModel>?) ?? [];
      for (var i = 0; i < loaded.length && i < 8; i++) {
        final it = loaded[i];
        final formatted = DateDisplayFormatter.formatYmdFromString(it.createdAtRaw);
        debugPrint(
          '[AnnouncementList] id=${it.id} createdAtRaw=${it.createdAtRaw} '
          'createdAt=${it.createdAt} formatYmd=$formatted',
        );
      }
      setState(() {
        _items = loaded;
        _total = (result['total'] as num?)?.toInt() ?? 0;
        _page = (result['page'] as num?)?.toInt() ?? targetPage;
        _totalPages = ((result['totalPages'] as num?)?.toInt() ?? 1).clamp(1, 9999);
        _query = targetQuery;
      });
    } else {
      setState(() {
        _error = result['message']?.toString() ?? '공지사항을 불러오지 못했습니다.';
      });
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: const HealthAppBar(title: '공지사항', centerTitle: false),
      child: RefreshIndicator(
        onRefresh: () => _load(page: 1),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            healthDp(context, 27),
            healthDp(context, 20),
            healthDp(context, 27),
            healthDp(context, 20),
          ),
          children: [
            _buildSearchBar(context),
            SizedBox(height: healthDp(context, 10)),
            _buildTotalRow(context),
            SizedBox(height: healthDp(context, 10)),
            if (_loading)
              Padding(
                padding: EdgeInsets.symmetric(vertical: healthDp(context, 64)),
                child: const Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _buildError(context)
            else if (_items.isEmpty)
              _buildEmpty(context)
            else ...[
              ..._items.map((item) => _buildNoticeCard(context, item)),
              SizedBox(height: healthDp(context, 16)),
              _buildPagination(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      height: healthDp(context, 36),
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
        padding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 10),
          vertical: healthDp(context, 10),
        ),
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
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AnnouncementDetailScreen(announcementId: item.id),
          settings: RouteSettings(name: '/announcement/${item.id}'),
        ),
      ),
      borderRadius: BorderRadius.circular(healthDp(context, 16)),
      child: Container(
        margin: EdgeInsets.only(bottom: healthDp(context, 14)),
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
              children: [
                if (item.isNotice) ...[
                  Container(
                    margin: EdgeInsets.only(right: healthDp(context, 6)),
                    padding: EdgeInsets.symmetric(
                      horizontal: healthDp(context, 6),
                      vertical: healthDp(context, 2),
                    ),
                    decoration: ShapeDecoration(
                      color: _kPink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(healthDp(context, 10)),
                      ),
                    ),
                    child: Text(
                      '고정',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: healthSp(context, 10),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                Text(
                  date,
                  style: TextStyle(
                    color: _kMuted,
                    fontSize: healthSp(context, 10),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    letterSpacing: healthSp(context, -1.65),
                  ),
                ),
                SizedBox(width: healthDp(context, 10)),
                Text(
                  '조회 : ${item.viewCount}',
                  style: TextStyle(
                    color: _kMuted,
                    fontSize: healthSp(context, 10),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPagination(BuildContext context) {
    final startPage = ((_page - 1) ~/ 6) * 6 + 1;
    final endPage = (startPage + 5).clamp(1, _totalPages);
    final pages = List<int>.generate(endPage - startPage + 1, (i) => startPage + i);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: _page > 1 ? () => _load(page: _page - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        ...pages.map((p) => Padding(
              padding: EdgeInsets.symmetric(horizontal: healthDp(context, 2)),
              child: InkWell(
                onTap: p == _page ? null : () => _load(page: p),
                borderRadius: BorderRadius.circular(healthDp(context, 7)),
                child: Container(
                  width: healthDp(context, 30),
                  height: healthDp(context, 30),
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: p == _page ? _kPink : Colors.white,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: p == _page ? 0 : healthDp(context, 1),
                        color: const Color(0x7FD2D2D2),
                      ),
                      borderRadius: BorderRadius.circular(healthDp(context, 7)),
                    ),
                  ),
                  child: Text(
                    '$p',
                    style: TextStyle(
                      color: p == _page ? Colors.white : const Color(0xFF898383),
                      fontSize: healthSp(context, 14),
                      fontFamily: 'Pretendard Variable',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            )),
        IconButton(
          onPressed: _page < _totalPages ? () => _load(page: _page + 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: healthDp(context, 40)),
      alignment: Alignment.center,
      child: Text(
        _error ?? '오류가 발생했습니다.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _kMuted,
          fontSize: healthSp(context, 14),
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: healthDp(context, 40)),
      child: const CenteredEmptyState(
        icon: Icons.campaign_outlined,
        message: '공지사항이 없습니다.',
      ),
    );
  }
}
