import 'package:flutter/material.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/event/event_model.dart';
import '../../../../data/services/event_service.dart';
import '../../../common/widgets/app_bar.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';

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
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
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
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadEventDetail,
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_event == null) {
      return const Center(
        child: Text(
          '이벤트를 찾을 수 없습니다.',
          style: TextStyle(fontFamily: _font),
        ),
      );
    }

    final imageUrl = _event!.getImageUrl();
    final plainText = _event!.getPlainText();
    final prevEvent = _getPrevEvent();
    final nextEvent = _getNextEvent();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(27, 24, 27, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Text(
              _event!.wrSubject,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 20,
                fontFamily: _font,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.8,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: _kBorder),
          const SizedBox(height: 20),
          if (imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 240,
                  color: const Color(0xFFF4F4F4),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    size: 42,
                    color: Color(0xFF898686),
                  ),
                ),
              ),
            ),
          if (imageUrl != null) const SizedBox(height: 24),
          if (plainText.isNotEmpty)
            Text(
              plainText,
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 14,
                fontFamily: _font,
                fontWeight: FontWeight.w500,
                letterSpacing: -0.56,
                height: 1.5,
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            '이벤트 기간',
            style: TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 14,
              fontFamily: _font,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              '- ${_periodText(_event!)}',
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 14,
                fontFamily: _font,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 20),
          if (prevEvent != null || nextEvent != null) ...[
            if (prevEvent != null) ...[
              Container(height: 1, color: _kBorder),
              _buildNavRow(
                label: '이전글',
                event: prevEvent!,
                isPrev: true,
              ),
            ],
            if (nextEvent != null) ...[
              Container(height: 1, color: _kBorder),
              _buildNavRow(
                label: '다음글',
                event: nextEvent!,
                isPrev: false,
              ),
            ],
            Container(height: 1, color: _kBorder),
          ],
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () => Navigator.pop(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                decoration: ShapeDecoration(
                  color: _kPink,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text(
                  '목록',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
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

  Widget _buildNavRow({
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              isPrev ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 20,
              color: const Color(0xFF898686),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF898686),
                fontSize: 14,
                fontFamily: _font,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                event.wrSubject,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
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
