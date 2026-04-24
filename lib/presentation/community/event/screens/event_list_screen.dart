import 'package:flutter/material.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/event/event_model.dart';
import '../../../../data/services/event_service.dart';
import '../../../common/widgets/app_bar.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import 'event_detail_screen.dart';

class EventListScreen extends StatefulWidget {
  const EventListScreen({super.key});

  @override
  State<EventListScreen> createState() => _EventListScreenState();
}

class _EventListScreenState extends State<EventListScreen> {
  static const String _font = 'Gmarket Sans TTF';
  static const Color _kBorder = Color(0xFFD2D2D2);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kPink = Color(0xFFFF5A8D);

  int _selectedTab = 0; // 0: 전체, 1: 진행중, 2: 종료
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  bool _isLoading = true;
  String? _errorMessage;
  List<EventModel> _activeEvents = [];
  List<EventModel> _endedEvents = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final result = await Future.wait([
        EventService.getActiveEvents(),
        EventService.getEndedEvents(),
      ]);
      if (!mounted) return;
      setState(() {
        _activeEvents = result[0];
        _endedEvents = result[1];
        _isLoading = false;
      });
      final merged = _mergeUniqueEvents();
      final ongoing = merged.where((e) => !_isEventEnded(e)).length;
      final closed = merged.where((e) => _isEventEnded(e)).length;
      debugPrint(
        '[EventListScreen] state: activeAPI=${_activeEvents.length} endedAPI=${_endedEvents.length} '
        'merged=${merged.length} ongoing(byDate)=$ongoing closed(byDate)=$closed '
        'tab=$_selectedTab visible=${_filteredEvents.length}',
      );
    } catch (e, st) {
      debugPrint('[EventListScreen] load failed: $e');
      debugPrint('$st');
      if (!mounted) return;
      setState(() {
        _errorMessage = '이벤트를 불러오는데 실패했습니다: $e';
        _isLoading = false;
      });
    }
  }

  /// API 두 목록을 합치되 `wr_id` 기준 중복 제거 (진행 목록 우선).
  List<EventModel> _mergeUniqueEvents() {
    final byId = <int, EventModel>{};
    for (final e in _activeEvents) {
      byId[e.wrId] = e;
    }
    for (final e in _endedEvents) {
      byId.putIfAbsent(e.wrId, () => e);
    }
    final list = byId.values.toList()..sort((a, b) => b.wrId.compareTo(a.wrId));
    return list;
  }

  /// `wr2`(종료일) 기준: 오늘 날짜가 종료일 **다음날**부터면 종료. 파싱 불가 시 서버 `isActive`.
  bool _isEventEnded(EventModel e) {
    final end = DateDisplayFormatter.tryParseYmdFlexible(e.wr2);
    if (end != null) {
      final n = DateTime.now();
      final today = DateTime(n.year, n.month, n.day);
      final endDay = DateTime(end.year, end.month, end.day);
      return today.isAfter(endDay);
    }
    final category = (e.caName ?? '').trim();
    if (category.contains('종료')) return true;
    return false;
  }

  List<EventModel> get _filteredEvents {
    var base = _mergeUniqueEvents();
    switch (_selectedTab) {
      case 1:
        base = base.where((e) => !_isEventEnded(e)).toList();
        break;
      case 2:
        base = base.where((e) => _isEventEnded(e)).toList();
        break;
      default:
        break;
    }
    if (_query.trim().isEmpty) return base;
    final q = _query.trim().toLowerCase();
    return base.where((e) => e.wrSubject.toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final events = _filteredEvents;
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: _font),
      child: MobileAppLayoutWrapper(
        appBar: const HealthAppBar(title: '이벤트', centerTitle: false),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(27, 24, 27, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFilterTabs(),
              const SizedBox(height: 12),
              _buildSearchBox(),
              const SizedBox(height: 12),
              _buildCountRow(events.length),
              const SizedBox(height: 10),
              Expanded(child: _buildBody(events)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    Widget tab(String text, int index) {
      final selected = _selectedTab == index;
      return InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.only(bottom: 5),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: 1,
                color: selected ? _kPink : Colors.transparent,
              ),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: selected ? _kPink : const Color(0xFF898383),
              fontSize: 14,
              fontFamily: _font,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      );
    }

    Widget divider() =>
        Container(width: 0.5, height: 11, color: const Color(0xFFD2D2D2));

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        tab('전체', 0),
        const SizedBox(width: 12),
        divider(),
        const SizedBox(width: 12),
        tab('진행중인 이벤트', 1),
        const SizedBox(width: 12),
        divider(),
        const SizedBox(width: 12),
        tab('종료된 이벤트', 2),
      ],
    );
  }

  Widget _buildSearchBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: _kBorder),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _applySearch(),
              style: const TextStyle(
                fontFamily: _font,
                fontSize: 14,
                color: Color(0xFF1A1A1A),
              ),
              decoration: const InputDecoration(
                hintText: '검색',
                hintStyle: TextStyle(
                  color: _kMuted,
                  fontSize: 14,
                  fontFamily: _font,
                  fontWeight: FontWeight.w300,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 18, color: _kMuted),
            onPressed: _applySearch,
          ),
        ],
      ),
    );
  }

  Widget _buildCountRow(int total) {
    return Column(
      children: [
        Container(height: 1, color: const Color(0x7FD2D2D2)),
        const SizedBox(height: 5),
        Align(
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                const TextSpan(
                  text: '총 ',
                  style: TextStyle(
                    color: _kMuted,
                    fontSize: 12,
                    fontFamily: _font,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text: '$total',
                  style: const TextStyle(
                    color: _kPink,
                    fontSize: 12,
                    fontFamily: _font,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const TextSpan(
                  text: '건',
                  style: TextStyle(
                    color: _kMuted,
                    fontSize: 12,
                    fontFamily: _font,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Container(height: 1, color: const Color(0x7FD2D2D2)),
      ],
    );
  }

  Widget _buildBody(List<EventModel> events) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _kPink),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: _font),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loadEvents,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    if (events.isEmpty) {
      return const Center(
        child: Text(
          '이벤트가 없습니다.',
          style: TextStyle(
            color: _kMuted,
            fontFamily: _font,
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView.separated(
        itemCount: events.length,
        padding: const EdgeInsets.only(bottom: 24),
        separatorBuilder: (_, __) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final event = events[index];
          return _buildEventCard(event, ended: _isEventEnded(event));
        },
      ),
    );
  }

  Widget _buildEventCard(EventModel event, {required bool ended}) {
    final imageUrl = event.getImageUrl();
    final card = InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(wrId: event.wrId),
          settings: RouteSettings(name: '/evnt/${event.wrId}'),
        ),
      ),
      borderRadius: BorderRadius.circular(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: 220,
              child: imageUrl == null
                  ? Container(
                      color: const Color(0xFFF4F4F4),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_outlined,
                        size: 42,
                        color: _kMuted,
                      ),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFF4F4F4),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.broken_image_outlined,
                          size: 42,
                          color: _kMuted,
                        ),
                      ),
                    ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              border: Border.all(color: _kBorder, width: 0.8),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.wrSubject,
                  style: const TextStyle(
                    color: Color(0xFF231F20),
                    fontSize: 20,
                    fontFamily: _font,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1.8,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  _periodText(event),
                  style: const TextStyle(
                    color: _kMuted,
                    fontSize: 12,
                    fontFamily: _font,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (!ended) return card;

    return Stack(
      children: [
        Opacity(opacity: 0.7, child: card),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Text(
              '이벤트가\n종료 되었습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontFamily: _font,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
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

  void _applySearch() {
    setState(() {
      _query = _searchController.text.trim();
    });
  }
}
