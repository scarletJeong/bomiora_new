import 'package:flutter/material.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/event/event_model.dart';
import '../../../../data/services/event_service.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import '../../../common/navigation/board_list_navigation.dart';
import '../../../common/widgets/article_adjacent_nav.dart';
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
  static const Color _kBorder = Color(0x7FD2D2D2);
  static const Color _kPink = Color(0xFFFF5A8D);

  EventModel? _event;
  bool _isLoading = true;
  String? _errorMessage;
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
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await Future.wait([
        EventService.getEventDetail(widget.wrId),
        EventService.getActiveEvents(),
      ]);
      final event = result[0] as EventModel?;
      final active = (result[1] as List<EventModel>)
          .where((e) => !e.isEnded)
          .toList()
        ..sort((a, b) => b.wrId.compareTo(a.wrId));

      if (!mounted) return;

      if (event != null && event.isEnded) {
        setState(() {
          _errorMessage = '종료된 이벤트입니다.';
          _event = null;
          _allEvents = active;
          _isLoading = false;
        });
      } else if (event != null) {
        setState(() {
          _event = event;
          _allEvents = active;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = '이벤트를 찾을 수 없습니다.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = '이벤트를 불러오는데 실패했습니다: $e';
        _isLoading = false;
      });
    }
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _errorMessage!,
              style: TextStyle(
                color: Colors.red,
                fontSize: healthSp(context, 14),
                fontFamily: _font,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: healthDp(context, 16)),
            ElevatedButton(
              onPressed: _loadEventDetail,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_event == null) {
      return Center(
        child: Text(
          '이벤트를 찾을 수 없습니다.',
          style: TextStyle(
            fontFamily: _font,
            fontSize: healthSp(context, 14),
          ),
        ),
      );
    }

    final imageUrl = _event!.getImageUrl();
    final plainText = _event!.getPlainText();
    final prevEvent = _getPrevEvent();
    final nextEvent = _getNextEvent();

    return Stack(
      fit: StackFit.expand,
      children: [
        SingleChildScrollView(
          controller: _scrollController,
          padding: EdgeInsets.fromLTRB(
            healthDp(context, 27),
            healthDp(context, 20),
            healthDp(context, 27),
            healthDp(context, 20),
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
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
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
              if (plainText.isNotEmpty)
                Text(
                  plainText,
                  style: TextStyle(
                    color: const Color(0xFF1A1A1A),
                    fontSize: healthSp(context, 14),
                    fontFamily: _font,
                    fontWeight: FontWeight.w500,
                    letterSpacing: healthSp(context, -0.56),
                    height: 1.5,
                  ),
                ),
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
              SizedBox(height: healthDp(context, 20)),
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  borderRadius: BorderRadius.circular(healthDp(context, 4)),
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
            ],
          ),
        ),
        ArticleAdjacentNavOverlay(
          controller: _scrollController,
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
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => EventDetailScreen(wrId: wrId),
        settings: RouteSettings(name: '/event/$wrId'),
      ),
    );
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
