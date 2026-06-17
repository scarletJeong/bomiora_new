import 'package:flutter/material.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/event/event_model.dart';
import '../../../../data/services/event_service.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
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

  @override
  void initState() {
    super.initState();
    _loadEventDetail();
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
        EventService.getEndedEvents(),
      ]);
      final event = result[0] as EventModel?;
      final active = result[1] as List<EventModel>;
      final ended = result[2] as List<EventModel>;

      if (!mounted) return;
      final byId = <int, EventModel>{};
      for (final e in active) {
        byId[e.wrId] = e;
      }
      for (final e in ended) {
        byId.putIfAbsent(e.wrId, () => e);
      }
      final all = byId.values.toList()
        ..sort((a, b) => b.wrId.compareTo(a.wrId));

      if (event != null) {
        setState(() {
          _event = event;
          _allEvents = all;
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
        appBar: const HealthAppBar(title: '이벤트', centerTitle: false),
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

    return SingleChildScrollView(
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
          if (prevEvent != null || nextEvent != null) ...[
            if (prevEvent != null) ...[
              Container(height: healthDp(context, 1), color: _kBorder),
              _buildNavRow(
                context,
                label: '이전글',
                event: prevEvent,
                isPrev: true,
              ),
            ],
            if (nextEvent != null) ...[
              Container(height: healthDp(context, 1), color: _kBorder),
              _buildNavRow(
                context,
                label: '다음글',
                event: nextEvent,
                isPrev: false,
              ),
            ],
            Container(height: healthDp(context, 1), color: _kBorder),
          ],
          SizedBox(height: healthDp(context, 20)),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              borderRadius: BorderRadius.circular(healthDp(context, 4)),
              onTap: () => Navigator.pop(context),
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
    );
  }

  Widget _buildNavRow(
    BuildContext context, {
    required String label,
    required EventModel event,
    required bool isPrev,
  }) {
    return InkWell(
      onTap: () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(wrId: event.wrId),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: healthDp(context, 12)),
        child: Row(
          children: [
            Icon(
              isPrev ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: healthDp(context, 20),
              color: const Color(0xFF898686),
            ),
            Text(
              label,
              style: TextStyle(
                color: const Color(0xFF898686),
                fontSize: healthSp(context, 14),
                fontFamily: _font,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: healthDp(context, 10)),
            Expanded(
              child: Text(
                event.wrSubject,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: healthSp(context, 14),
                  fontFamily: _font,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  EventModel? _getPrevEvent() {
    if (_event == null) return null;
    final index = _allEvents.indexWhere((e) => e.wrId == _event!.wrId);
    if (index <= 0) return null;
    return _allEvents[index - 1];
  }

  EventModel? _getNextEvent() {
    if (_event == null) return null;
    final index = _allEvents.indexWhere((e) => e.wrId == _event!.wrId);
    if (index == -1 || index >= _allEvents.length - 1) return null;
    return _allEvents[index + 1];
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
