import 'package:flutter/material.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/event/event_model.dart';
import '../../../../data/services/event_service.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../health/health_common/health_responsive_scale.dart';
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

  int _selectedTab = 0; // 0: 진행중, 1: 종료
  bool _isLoading = true;
  String? _errorMessage;
  List<EventModel> _activeEvents = [];
  List<EventModel> _endedEvents = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = '이벤트를 불러오는데 실패했습니다: $e';
        _isLoading = false;
      });
    }
  }

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
    final base = _mergeUniqueEvents();
    if (_selectedTab == 0) {
      return base.where((e) => !_isEventEnded(e)).toList();
    }
    return base.where((e) => _isEventEnded(e)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final events = _filteredEvents;
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: _font),
      child: MobileAppLayoutWrapper(
        appBar: const HealthAppBar(title: '이벤트', centerTitle: false),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            healthDp(context, 27),
            healthDp(context, 20),
            healthDp(context, 27),
            healthDp(context, 20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildFilterTabs(context),
              SizedBox(height: healthDp(context, 10)),
              _buildCountRow(context, events.length),
              SizedBox(height: healthDp(context, 10)),
              Expanded(child: _buildBody(context, events)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs(BuildContext context) {
    Widget tab(String text, int index) {
      final selected = _selectedTab == index;
      return InkWell(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: healthDp(context, 1),
                color: selected ? _kPink : Colors.transparent,
              ),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: selected ? _kPink : const Color(0xFF898383),
              fontSize: healthSp(context, 14),
              fontFamily: _font,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      );
    }

    Widget divider() => Container(
          width: healthDp(context, 0.5),
          height: healthDp(context, 11),
          color: const Color(0xFFD2D2D2),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        tab('진행중인 이벤트', 0),
        SizedBox(width: healthDp(context, 22)),
        divider(),
        SizedBox(width: healthDp(context, 22)),
        tab('종료된 이벤트', 1),
      ],
    );
  }

  Widget _buildCountRow(BuildContext context, int total) {
    return Column(
      children: [
        Container(
          height: healthDp(context, 1),
          color: const Color(0x7FD2D2D2),
        ),
        SizedBox(height: healthDp(context, 5)),
        Align(
          alignment: Alignment.centerLeft,
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '총 ',
                  style: TextStyle(
                    color: _kMuted,
                    fontSize: healthSp(context, 12),
                    fontFamily: _font,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                TextSpan(
                  text: '$total',
                  style: TextStyle(
                    color: _kPink,
                    fontSize: healthSp(context, 12),
                    fontFamily: _font,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: '건',
                  style: TextStyle(
                    color: _kMuted,
                    fontSize: healthSp(context, 12),
                    fontFamily: _font,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: healthDp(context, 5)),
        Container(
          height: healthDp(context, 1),
          color: const Color(0x7FD2D2D2),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, List<EventModel> events) {
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
              style: TextStyle(
                fontFamily: _font,
                fontSize: healthSp(context, 14),
              ),
            ),
            SizedBox(height: healthDp(context, 12)),
            ElevatedButton(
              onPressed: _loadEvents,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }
    if (events.isEmpty) {
      return Center(
        child: Text(
          '이벤트가 없습니다.',
          style: TextStyle(
            color: _kMuted,
            fontFamily: _font,
            fontSize: healthSp(context, 14),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView.separated(
        itemCount: events.length,
        padding: EdgeInsets.only(bottom: healthDp(context, 24)),
        separatorBuilder: (_, __) => SizedBox(height: healthDp(context, 14)),
        itemBuilder: (context, index) {
          final event = events[index];
          return _buildEventCard(context, event, ended: _isEventEnded(event));
        },
      ),
    );
  }

  //이벤트 카드
  Widget _buildEventCard(
    BuildContext context,
    EventModel event, {
    required bool ended,
  }) {
    final imageUrl = event.getImageUrl();
    final card = InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(wrId: event.wrId),
          settings: RouteSettings(name: '/event/${event.wrId}'),
        ),
      ),
      borderRadius: BorderRadius.circular(healthDp(context, 10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(healthDp(context, 10)),
              topRight: Radius.circular(healthDp(context, 10)),
            ),
            child: SizedBox(
              height: healthDp(context, 220),
              child: imageUrl == null
                  ? Container(
                      color: const Color(0xFFF4F4F4),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.image_outlined,
                        size: healthDp(context, 42),
                        color: _kMuted,
                      ),
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFF4F4F4),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.broken_image_outlined,
                          size: healthDp(context, 42),
                          color: _kMuted,
                        ),
                      ),
                    ),
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: healthDp(context, 12),
              vertical: healthDp(context, 10),
            ),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: _kBorder,
                  width: healthDp(context, 0.8),
                ),
                right: BorderSide(
                  color: _kBorder,
                  width: healthDp(context, 0.8),
                ),
                bottom: BorderSide(
                  color: _kBorder,
                  width: healthDp(context, 0.8),
                ),
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(healthDp(context, 10)),
                bottomRight: Radius.circular(healthDp(context, 10)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.wrSubject,
                  style: TextStyle(
                    color: const Color(0xFF231F20),
                    fontSize: healthSp(context, 16),
                    fontFamily: _font,
                    fontWeight: FontWeight.w500,
                    letterSpacing: healthSp(context, -1.44),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: healthDp(context, 10)),
                Text(
                  _periodText(event),
                  style: TextStyle(
                    color: _kMuted,
                    fontSize: healthSp(context, 12),
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
              borderRadius: BorderRadius.circular(healthDp(context, 10)),
            ),
            alignment: Alignment.center,
            child: Text(
              '이벤트가\n종료 되었습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: healthSp(context, 18),
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
}
