import 'package:flutter/material.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/announcement/announcement_model.dart';
import '../../../../data/services/announcement_service.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/app_bar.dart';
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
          padding: const EdgeInsets.fromLTRB(27, 16, 27, 20),
          children: [
            _buildSearchBar(),
            const SizedBox(height: 14),
            _buildTotalRow(),
            const SizedBox(height: 10),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 64),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _buildError()
            else if (_items.isEmpty)
              _buildEmpty()
            else ...[
              ..._items.map(_buildNoticeCard),
              const SizedBox(height: 16),
              _buildPagination(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: Color(0xFFD2D2D2)),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submitSearch(),
              decoration: const InputDecoration(
                hintText: '검색',
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: _kMuted,
                  fontSize: 14,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 18, color: _kMuted),
            onPressed: _submitSearch,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(height: 1, color: _kBorder),
        const SizedBox(height: 5),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(
                text: '총 ',
                style: TextStyle(
                  color: _kMuted,
                  fontSize: 12,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextSpan(
                text: '$_total',
                style: const TextStyle(
                  color: _kPink,
                  fontSize: 12,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                ),
              ),
              const TextSpan(
                text: '건',
                style: TextStyle(
                  color: _kMuted,
                  fontSize: 12,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 5),
        Container(height: 1, color: _kBorder),
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

  Widget _buildNoticeCard(AnnouncementModel item) {
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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: ShapeDecoration(
          shape: RoundedRectangleBorder(
            side: const BorderSide(width: 1, color: _kBorder),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _kText,
                fontSize: 14,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (item.isNotice) ...[
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: ShapeDecoration(
                      color: _kPink,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      '공지',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                Text(
                  date,
                  style: const TextStyle(
                    color: _kMuted,
                    fontSize: 10,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '조회 : ${item.viewCount}',
                  style: const TextStyle(
                    color: _kMuted,
                    fontSize: 10,
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

  Widget _buildPagination() {
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
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: InkWell(
                onTap: p == _page ? null : () => _load(page: p),
                borderRadius: BorderRadius.circular(7),
                child: Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: p == _page ? _kPink : Colors.white,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        width: p == _page ? 0 : 1,
                        color: const Color(0x7FD2D2D2),
                      ),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  child: Text(
                    '$p',
                    style: TextStyle(
                      color: p == _page ? Colors.white : const Color(0xFF898383),
                      fontSize: 14,
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

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40),
      alignment: Alignment.center,
      child: Text(
        _error ?? '오류가 발생했습니다.',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _kMuted,
          fontSize: 14,
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          '공지사항이 없습니다.',
          style: TextStyle(
            color: _kMuted,
            fontSize: 14,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
