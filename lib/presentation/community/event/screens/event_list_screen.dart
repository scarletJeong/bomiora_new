import 'package:flutter/material.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/event/event_model.dart';
import '../../../../data/services/event_service.dart';
import '../../../common/widgets/app_clickable.dart';
import '../../../common/widgets/centered_empty_state.dart';
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
  int _visibleCount = 3;
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
    final list = byId.values.toList()
      ..sort((a, b) {
        final byOrder = a.sortOrder.compareTo(b.sortOrder);
        if (byOrder != 0) return byOrder;
        return a.wrId.compareTo(b.wrId);
      });
    return list;
  }

  bool _isEventEnded(EventModel e) => e.isEnded;

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
        appBar: const HealthAppBar(title: '이벤트'),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                healthDp(context, 20),
                healthDp(context, 10),
                healthDp(context, 20),
                healthDp(context, 20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFilterTabs(context),
                  SizedBox(height: healthDp(context, 20)),
                  Expanded(
                    child: _isLoading || events.isNotEmpty
                        ? _buildBody(context, events)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
            if (!_isLoading && (_errorMessage != null || events.isEmpty))
              PageCenteredEmptyOverlay(child: _buildEmptyMessage(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTabs(BuildContext context) {
    Widget tab(String text, int count, int index) {
      final selected = _selectedTab == index;
      final color = selected ? _kPink : _kMuted;
      return Expanded(
        child: AppClickable(
          onTap: () => setState(() {
            _selectedTab = index;
            _visibleCount = 3;
          }),
          child: Container(
            padding: EdgeInsets.only(bottom: healthDp(context, 10)),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  width: healthDp(context, 1),
                  color: selected ? _kPink : _kBorder,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: color,
                    fontSize: healthSp(context, 14),
                    fontFamily: _font,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                if (selected) ...[
                  SizedBox(width: healthDp(context, 4)),
                  Text(
                    '$count',
                    style: TextStyle(
                      color: color,
                      fontSize: healthSp(context, 12),
                      fontFamily: _font,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final base = _mergeUniqueEvents();
    final activeCount = base.where((e) => !_isEventEnded(e)).length;
    final endedCount = base.where((e) => _isEventEnded(e)).length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        tab('진행중인 이벤트', activeCount, 0),
        tab('종료된 이벤트', endedCount, 1),
      ],
    );
  }

  Widget _buildBody(BuildContext context, List<EventModel> events) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: _kPink),
      );
    }
    if (_errorMessage != null || events.isEmpty) {
      return const SizedBox.shrink();
    }

    final visible = events.take(_visibleCount).toList();
    final hasMore = events.length > visible.length;

    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView.separated(
        itemCount: visible.length + (hasMore ? 1 : 0),
        padding: EdgeInsets.only(bottom: healthDp(context, 20)),
        separatorBuilder: (_, __) => SizedBox(height: healthDp(context, 20)),
        itemBuilder: (context, index) {
          if (index >= visible.length) return _buildMoreButton(context);
          return _buildEventCard(context, visible[index]);
        },
      ),
    );
  }

  Widget _buildEmptyMessage(BuildContext context) {
    final emptyLabel = _selectedTab == 0
        ? '진행중인 이벤트가 없습니다'
        : '종료된 이벤트가 없습니다';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CenteredEmptyState.assetIcon(context, AppAssets.emptyEventIcon),
        SizedBox(height: healthDp(context, 10)),
        Text(
          emptyLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFFC0C0C0),
            fontSize: healthSp(context, 14),
            fontFamily: _font,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildMoreButton(BuildContext context) {
    return AppClickable(
      onTap: () => setState(() => _visibleCount += 3),
      child: Container(
        width: double.infinity,
        height: healthDp(context, 40),
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: healthDp(context, 0.5),
              color: _kBorder,
            ),
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
          ),
        ),
        child: Text(
          '더보기',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _kMuted,
            fontSize: healthSp(context, 14),
            fontFamily: _font,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  //이벤트 카드
  Widget _buildEventCard(BuildContext context, EventModel event) {
    final imageUrl = event.getImageUrl();
    final ended = _isEventEnded(event);
    final radius = healthDp(context, 10);
    final imageRadius = BorderRadius.only(
      topLeft: Radius.circular(radius),
      topRight: Radius.circular(radius),
    );
    return AppClickable(
      onTap: ended
          ? null
          : () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EventDetailScreen(wrId: event.wrId),
                  settings: RouteSettings(name: '/event/${event.wrId}'),
                ),
              ),
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              width: healthDp(context, 1),
              color: const Color(0x7FD2D2D2),
            ),
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: healthDp(context, 200),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: imageRadius,
                        child: imageUrl == null
                            ? const ColoredBox(color: Color(0xFFF4F4F4))
                            : Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: healthDp(context, 200),
                                errorBuilder: (_, __, ___) =>
                                    const ColoredBox(color: Color(0xFFF4F4F4)),
                              ),
                      ),
                    ),
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: ended
                              ? Colors.black.withValues(alpha: 0.50)
                              : null,
                          shape: RoundedRectangleBorder(
                            side: const BorderSide(
                              width: 1,
                              color: Color(0x7FD2D2D2),
                            ),
                            borderRadius: imageRadius,
                          ),
                        ),
                      ),
                    ),
                    if (ended)
                      Text(
                        '이벤트가\n종료되었습니다',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: healthSp(context, 16),
                          fontFamily: _font,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.all(healthDp(context, 10)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.wrSubject,
                      style: TextStyle(
                        color: const Color(0xFF1A1A1E),
                        fontSize: healthSp(context, 14),
                        fontFamily: _font,
                        fontWeight: FontWeight.w500,
                        letterSpacing: healthSp(context, -0.56),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: healthDp(context, 4)),
                    Text(
                      _periodText(event),
                      style: TextStyle(
                        color: _kMuted,
                        fontSize: healthSp(context, 10),
                        fontFamily: _font,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
