import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../data/models/qa/qa_inquiry_model.dart';
import '../../../data/services/qa_service.dart';
import '../../common/widgets/app_toast_overlay.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../models/qa_inquiry_draft.dart';

class QaDetailScreen extends StatefulWidget {
  final int wrId;

  const QaDetailScreen({
    super.key,
    required this.wrId,
  });

  @override
  State<QaDetailScreen> createState() => _QaDetailScreenState();
}

class _QaDetailScreenState extends State<QaDetailScreen> {
  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _userBubble = Color(0xFFFFD6E4);
  static const Color _datePill = Color(0x99E7E8E9);
  static const Color _csBorder = Color(0x33E0BEC4);
  static const Color _csText = Color(0xFF191C1D);
  static const Color _inputBarBg = Color(0xFFF8F9FA);
  static const Color _inputFieldBg = Color(0xFFE7E8E9);
  static const Color _hint = Color(0x66584045);
  static const String _font = 'Gmarket Sans TTF';

  QaInquiry? _inquiry;
  List<QaInquiry> _thread = [];
  int? _rootWrId;
  final Map<int, List<QaInquiry>> _repliesByWrId = {};
  bool _isLoading = true;
  String? _errorMessage;
  bool _didInitialScroll = false;
  bool _sending = false;

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadContactDetail();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    _inputFocus.dispose();
    super.dispose();
  }

  Future<void> _loadContactDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _didInitialScroll = false;
    });

    try {
      final payload = await QaService.getDetail(widget.wrId);
      if (payload != null) {
        setState(() {
           _inquiry = payload.inquiry;
          _thread = payload.thread;
          _rootWrId = payload.rootWrId;
          _isLoading = false;
        });
        await _loadRepliesForThread();
      } else {
        setState(() {
          _errorMessage = '문의를 불러오는데 실패했습니다.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = '문의를 불러오는 중 오류가 발생했습니다: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRepliesForThread() async {
    final targets =
        _allQuestions.map((q) => q.wrId).where((id) => id > 0).toList();
    if (targets.isEmpty) {
      _scheduleScrollToBottom();
      return;
    }
    try {
      final results =
          await Future.wait(targets.map(QaService.getReplies));
      if (!mounted) return;
      final map = <int, List<QaInquiry>>{};
      for (var i = 0; i < targets.length; i++) {
        map[targets[i]] = results[i];
      }
      setState(() {
        _repliesByWrId
          ..clear()
          ..addAll(map);
      });
      _scheduleScrollToBottom();
    } catch (_) {
      _scheduleScrollToBottom();
    }
  }

  void _scheduleScrollToBottom({int attempt = 0}) {
    if (attempt > 10) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didInitialScroll) return;
      if (!_scrollController.hasClients) {
        _scheduleScrollToBottom(attempt: attempt + 1);
        return;
      }
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      _didInitialScroll = true;
    });
  }

  List<QaInquiry> get _allQuestions {
    final base = <QaInquiry>[
      ..._thread,
      if (_inquiry != null)  _inquiry!,
    ];
    final byId = <int, QaInquiry>{};
    for (final c in base) {
      if (c.wrId > 0) byId[c.wrId] = c;
    }
    final unique = byId.values.toList()
      ..sort((a, b) {
        final byDt = a.wrDatetime.compareTo(b.wrDatetime);
        if (byDt != 0) return byDt;
        return a.wrId.compareTo(b.wrId);
      });
    return unique;
  }

  bool get _isThreadClosed {
    final rootId = _rootWrId ?? widget.wrId;
    for (final q in _allQuestions) {
      if (q.wrId == rootId) return q.isClosed;
    }
    return _inquiry?.isClosed ?? false;
  }

  bool _isAnswered(QaInquiry c) {
    if (c.hasReply) return true;
    final list = _repliesByWrId[c.wrId] ?? const <QaInquiry>[];
    return list.isNotEmpty || c.wrReply.trim().isNotEmpty;
  }

  String _answerTextFor(QaInquiry q) {
    final list = _repliesByWrId[q.wrId] ?? const <QaInquiry>[];
    if (list.isNotEmpty) return list.first.plainQuestionBody;

    final reply = q.wrReply.trim();
    if (reply.isEmpty) return '';
    return _stripHtml(reply);
  }

  String _stripHtml(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    if (!t.contains(RegExp(r'<[^>]+>'))) return t;
    return t
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }

  /// �亯 �ۼ� �ð� ? ���� ���� `wr_last`
  String _answerDatetimeFor(QaInquiry q) => q.wrLast.trim();

  /// �ð����� ������ �Ľ�
  /// - Ÿ���� ����(`2026-07-20 17:17:20`) �� ǥ�ÿ� ����(���ð�) �״��
  /// - Ÿ���� ����(`...Z`, `+09:00`) �� �Ľ� �� `toLocal()`
  DateTime? _parseDate(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return null;

    final hasTz = RegExp(
      r'(Z|[+-]\d{2}:?\d{2})\s*$',
      caseSensitive: false,
    ).hasMatch(t) ||
        RegExp(r'GMT', caseSensitive: false).hasMatch(t);

    if (hasTz) {
      try {
        // ISO / JS ��Ķ �� Ÿ���� ���� �� ��� ���÷� ��ȯ
        final parsed = DateTime.parse(
          t.contains('T') ? t : t.replaceFirst(' ', 'T'),
        );
        return parsed.toLocal();
      } catch (_) {
        // fall through
      }
    }

    // 2026-07-20 15:30:00 / 2026.07.20 15:30:00.000 ? ���ð� �״��
    final m = RegExp(
      r'^(\d{4})[.\-/](\d{1,2})[.\-/](\d{1,2})[ T](\d{1,2}):(\d{2})(?::(\d{2}))?',
    ).firstMatch(t);
    if (m != null) {
      return DateTime(
        int.parse(m.group(1)!),
        int.parse(m.group(2)!),
        int.parse(m.group(3)!),
        int.parse(m.group(4)!),
        int.parse(m.group(5)!),
        int.parse(m.group(6) ?? '0'),
      );
    }

    // Fri Apr 17 2026 11:07:38 GMT+0900 ...
    final js = RegExp(
      r'^[A-Za-z]{3}\s+([A-Za-z]{3})\s+(\d{1,2})\s+(\d{4})\s+'
      r'(\d{1,2}):(\d{2}):(\d{2})',
      caseSensitive: false,
    ).firstMatch(t);
    if (js != null) {
      const months = <String, int>{
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'aug': 8,
        'sep': 9,
        'oct': 10,
        'nov': 11,
        'dec': 12,
      };
      final mon = months[js.group(1)!.toLowerCase()];
      if (mon != null) {
        final wall = DateTime(
          int.parse(js.group(3)!),
          mon,
          int.parse(js.group(2)!),
          int.parse(js.group(4)!),
          int.parse(js.group(5)!),
          int.parse(js.group(6)!),
        );
        // GMT �������� ������ ������ hasTz�� �̹� ó������ �� ����
        return wall;
      }
    }

    try {
      return DateTime.parse(t.replaceFirst(' ', 'T')).toLocal();
    } catch (_) {
      return DateDisplayFormatter.tryParseYmdFlexible(t);
    }
  }

  String _formatAmPmTime(String raw) {
    final dt = _parseDate(raw)?.toLocal();
    if (dt == null) return '';
    final hour24 = dt.hour;
    final isAm = hour24 < 12;
    var hour12 = hour24 % 12;
    if (hour12 == 0) hour12 = 12;
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${isAm ? '오전' : '오후'}\n$hour12:$mm';
  }

  List<_ChatItem> _buildTimeline() {
    final items = <_ChatItem>[];
    String? lastDateKey;

    void maybeDate(String datetime) {
      final key = DateDisplayFormatter.formatYmdFromString(datetime);
      if (key == '-' || key.isEmpty) return;
      if (key == lastDateKey) return;
      lastDateKey = key;
      items.add(_ChatItem.date(key));
    }

    final root = _rootQuestion;
    final category = root?.inquiryCategoryLabel ?? '';
    final topic = root?.inquiryDetailLabel ?? '';
    final hasTopicFlow = (category == '주문' ||
            category == '상품' ||
            category == '기타') &&
        topic.isNotEmpty;

    if (root != null && hasTopicFlow) {
      maybeDate(root.wrDatetime);
      if (category == '주문' || category == '상품') {
        items.add(_ChatItem.target(root));
      }
      items.add(_ChatItem.topicGuide(category: category, selectedTopic: topic));
      items.add(_ChatItem.topicUser(text: topic));
      if (category == '기타') {
        items.add(_ChatItem.cs(
          text: QaInquiryDraft.etcTopicGuide(topic),
          datetime: root.wrDatetime,
        ));
      }
      items.add(_ChatItem.cs(
        text: QaInquiryDraft.askPrompt,
        datetime: root.wrDatetime,
      ));
    }

    for (final q in _allQuestions) {
      maybeDate(q.wrDatetime);
      items.add(_ChatItem.user(q));
      if (_isAnswered(q)) {
        final ansDt = _answerDatetimeFor(q);
        if (ansDt.isNotEmpty) maybeDate(ansDt);
        items.add(_ChatItem.cs(
          text: _answerTextFor(q),
          datetime: ansDt,
        ));
      }
    }
    return items;
  }

  QaInquiry? get _rootQuestion {
    final rootId = _rootWrId ?? widget.wrId;
    for (final q in _allQuestions) {
      if (q.wrId == rootId) return q;
    }
    return _inquiry ??
        (_allQuestions.isNotEmpty ? _allQuestions.first : null);
  }

  Future<void> _confirmAndCloseInquiry() async {
    if (_isThreadClosed) return;

    try {
      final root = _rootWrId ?? widget.wrId;
      final result = await QaService.close(root);
      if (!mounted) return;
      if (result['success'] == true) {
        AppToastOverlay.show(context, '문의를 종료하였습니다');
        _loadContactDetail();
      } else {
        AppToastOverlay.show(context, '문의 종료 중 오류가 발생했습니다.');
      }
    } catch (_) {
      if (mounted) {
        AppToastOverlay.show(context, '문의 종료 중 오류가 발생했습니다.');
      }
    }
  }

  Future<void> _sendFollowUp() async {
    if (_sending || _isThreadClosed) return;
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      final root = _rootWrId ?? widget.wrId;
      final subject = text.length > 40 ? '${text.substring(0, 40)}…' : text;
      final result = await QaService.create(
        subject: subject,
        content: text,
        parentWrId: root,
      );
      if (!mounted) return;
      if (result['success'] == true) {
        _inputController.clear();
        _inputFocus.unfocus();
        _didInitialScroll = false;
        await _loadContactDetail();
      } else {
        AppToastOverlay.show(
          context,
          result['message']?.toString() ?? '문의 전송에 실패했습니다.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppToastOverlay.show(context, '문의 전송 중 오류가 발생했습니다.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: const HealthAppBar(
        title: '1:1 문의',
        centerTitle: false,
      ),
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _pink));
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(healthDp(context, 27)),
          child: Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _font,
              fontSize: healthSp(context, 14),
              color: Colors.black54,
            ),
          ),
        ),
      );
    }

    final timeline = _buildTimeline();

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.fromLTRB(
              healthDp(context, 16),
              healthDp(context, 20),
              healthDp(context, 16),
              healthDp(context, 16),
            ),
            itemCount: timeline.length,
            itemBuilder: (context, index) {
              final item = timeline[index];
              switch (item.type) {
                case _ChatItemType.date:
                  return Padding(
                    padding: EdgeInsets.only(bottom: healthDp(context, 16)),
                    child: _buildDatePill(context, item.dateLabel!),
                  );
                case _ChatItemType.target:
                  return Padding(
                    padding: EdgeInsets.only(bottom: healthDp(context, 16)),
                    child: _buildTargetCard(context, item.question!),
                  );
                case _ChatItemType.topicGuide:
                  return Padding(
                    padding: EdgeInsets.only(bottom: healthDp(context, 16)),
                    child: _buildTopicGuide(
                      context,
                      category: item.topicCategory!,
                      selectedTopic: item.selectedTopic!,
                    ),
                  );
                case _ChatItemType.topicUser:
                  return Padding(
                    padding: EdgeInsets.only(bottom: healthDp(context, 16)),
                    child: _buildTopicUserBubble(
                      context,
                      text: item.topicUserText!,
                    ),
                  );
                case _ChatItemType.user:
                  return Padding(
                    padding: EdgeInsets.only(bottom: healthDp(context, 16)),
                    child: _buildUserBubble(context, item.question!),
                  );
                case _ChatItemType.cs:
                  return Padding(
                    padding: EdgeInsets.only(bottom: healthDp(context, 16)),
                    child: _buildCsBubble(
                      context,
                      text: item.csText ?? '',
                      datetime: item.csDatetime ?? '',
                    ),
                  );
              }
            },
          ),
        ),
        if (!_isThreadClosed) _buildCloseBadge(context),
        _buildInputBar(context),
      ],
    );
  }

  Widget _buildCloseBadge(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: healthDp(context, 4)),
      child: Center(
        child: GestureDetector(
          onTap: _confirmAndCloseInquiry,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: healthDp(context, 12),
              vertical: healthDp(context, 5),
            ),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                side: const BorderSide(width: 1, color: _pink),
                borderRadius: BorderRadius.circular(healthDp(context, 9999)),
              ),
              shadows: const [
                BoxShadow(
                  color: Color(0x0C000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Text(
              '문의를 종료합니다.',
              style: TextStyle(
                color: _pink,
                fontSize: healthSp(context, 8),
                fontFamily: _font,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDatePill(BuildContext context, String label) {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 12),
          vertical: healthDp(context, 4),
        ),
        decoration: ShapeDecoration(
          color: _datePill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 9999)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.black,
            fontSize: healthSp(context, 11),
            fontFamily: _font,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildTargetCard(BuildContext context, QaInquiry root) {
    final category = root.inquiryCategoryLabel;
    final badgeLabel = category == '주문'
        ? '주문문의'
        : (category == '상품' ? '상품문의' : category);
    final brandOrOrder = category == '주문' &&
            (root.subjectOrderId ?? '').isNotEmpty
        ? '주문번호 ${root.subjectOrderId}'
        : (root.subjectBrandName ?? '');
    final productName = (root.subjectProductName ?? '').trim().isNotEmpty
        ? root.subjectProductName!.trim()
        : root.listCardTitle;
    final price = root.subjectPrice;

    return Container(
      padding: EdgeInsets.all(healthDp(context, 12)),
      decoration: ShapeDecoration(
        color: const Color(0xFFF8F9FA),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(healthDp(context, 12)),
          side: const BorderSide(color: _csBorder),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(healthDp(context, 6)),
            child: Container(
              width: healthDp(context, 56),
              height: healthDp(context, 56),
              color: const Color(0xFFE8E8E8),
              child: const Icon(Icons.image_outlined),
            ),
          ),
          SizedBox(width: healthDp(context, 12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: healthDp(context, 4),
                    vertical: healthDp(context, 2),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x14FF5A8D),
                    borderRadius: BorderRadius.circular(healthDp(context, 4)),
                    border: Border.all(color: _pink.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(
                      color: _pink,
                      fontSize: healthSp(context, 6),
                      fontFamily: _font,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(height: healthDp(context, 2)),
                if (brandOrOrder.isNotEmpty) ...[
                  Text(
                    brandOrOrder,
                    style: TextStyle(
                      color: const Color(0xFF898686),
                      fontSize: healthSp(context, 10),
                      fontFamily: _font,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 2)),
                ],
                Text(
                  productName,
                  style: TextStyle(
                    color: const Color(0xFF1A1A1A),
                    fontSize: healthSp(context, 10),
                    fontFamily: _font,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (price != null) ...[
                  SizedBox(height: healthDp(context, 2)),
                  Text(
                    '${PriceFormatter.format(price)}원',
                    style: TextStyle(
                      color: const Color(0xFF1A1A1A),
                      fontSize: healthSp(context, 10),
                      fontFamily: _font,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicGuide(
    BuildContext context, {
    required String category,
    required String selectedTopic,
  }) {
    final topics = QaInquiryDraft.topicsFor(category);
    final guide = QaInquiryDraft.guideMessage(category);
    final avatar = healthDp(context, 36);
    final r = healthDp(context, 16);
    final tail = healthDp(context, 8);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: avatar,
          height: avatar,
          decoration: const BoxDecoration(
            color: Color(0xFFDDE3EB),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            AppAssets.bomioraPinkLogo,
            width: healthDp(context, 20),
            height: healthDp(context, 20),
          ),
        ),
        SizedBox(width: healthDp(context, 8)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(left: healthDp(context, 2)),
                child: Text(
                  'Bomi CS',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: healthSp(context, 11),
                    fontFamily: _font,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
              SizedBox(height: healthDp(context, 4)),
              CustomPaint(
                painter: _ChatBubblePainter(
                  color: Colors.white,
                  borderColor: const Color(0xFFE7E8E9),
                  isUser: false,
                  radius: r,
                  tailSize: tail,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    healthDp(context, 14) + tail,
                    healthDp(context, 10),
                    healthDp(context, 14),
                    healthDp(context, 10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        guide,
                        style: TextStyle(
                          color: _csText,
                          fontSize: healthSp(context, 12),
                          fontFamily: _font,
                          fontWeight: FontWeight.w500,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: healthDp(context, 12)),
                      Wrap(
                        spacing: healthDp(context, 8),
                        runSpacing: healthDp(context, 8),
                        children: [
                          for (final t in topics)
                            _TopicChip(
                              label: t,
                              selected: t == selectedTopic,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTopicUserBubble(
    BuildContext context, {
    required String text,
  }) {
    final r = healthDp(context, 16);
    final tail = healthDp(context, 8);

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Flexible(
          child: CustomPaint(
            painter: _ChatBubblePainter(
              color: _userBubble,
              isUser: true,
              radius: r,
              tailSize: tail,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                healthDp(context, 14),
                healthDp(context, 10),
                healthDp(context, 14) + tail,
                healthDp(context, 10),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.95),
                  fontSize: healthSp(context, 12),
                  fontFamily: _font,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserBubble(BuildContext context, QaInquiry q) {
    final text = q.displayQuestionText;
    final time = _formatAmPmTime(q.wrDatetime);
    final r = healthDp(context, 16);
    final tail = healthDp(context, 8);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (time.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(right: healthDp(context, 6)),
                child: Text(
                  time,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: const Color(0xFF898686),
                    fontSize: healthSp(context, 10),
                    fontFamily: _font,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
              ),
            Flexible(
              child: CustomPaint(
                painter: _ChatBubblePainter(
                  color: _userBubble,
                  isUser: true,
                  radius: r,
                  tailSize: tail,
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    healthDp(context, 14),
                    healthDp(context, 10),
                    healthDp(context, 14) + tail,
                    healthDp(context, 10),
                  ),
                  child: text.isEmpty
                      ? const SizedBox.shrink()
                      : Text(
                          text,
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.95),
                            fontSize: healthSp(context, 12),
                            fontFamily: _font,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCsBubble(
    BuildContext context, {
    required String text,
    required String datetime,
  }) {
    if (text.trim().isEmpty) return const SizedBox.shrink();
    final time = _formatAmPmTime(datetime);
    final avatar = healthDp(context, 36);
    final r = healthDp(context, 16);
    final tail = healthDp(context, 8);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: avatar,
          height: avatar,
          decoration: const BoxDecoration(
            color: Color(0xFFDDE3EB),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 4,
                offset: Offset(0, 1),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: SvgPicture.asset(
            AppAssets.bomioraPinkLogo,
            width: healthDp(context, 20),
            height: healthDp(context, 20),
          ),
        ),
        SizedBox(width: healthDp(context, 8)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(left: healthDp(context, 2)),
                child: Text(
                  'Bomi CS',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: healthSp(context, 11),
                    fontFamily: _font,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
              SizedBox(height: healthDp(context, 4)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: CustomPaint(
                      painter: _ChatBubblePainter(
                        color: Colors.white,
                        borderColor: const Color(0xFFE7E8E9),
                        isUser: false,
                        radius: r,
                        tailSize: tail,
                      ),
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          healthDp(context, 14) + tail,
                          healthDp(context, 10),
                          healthDp(context, 14),
                          healthDp(context, 10),
                        ),
                        child: Text(
                          text,
                          style: TextStyle(
                            color: _csText,
                            fontSize: healthSp(context, 12),
                            fontFamily: _font,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (time.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(
                        left: healthDp(context, 6),
                        bottom: healthDp(context, 2),
                      ),
                      child: Text(
                        time.replaceAll('\n', ' '),
                        style: TextStyle(
                          color: const Color(0xFF898686),
                          fontSize: healthSp(context, 10),
                          fontFamily: _font,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInputBar(BuildContext context) {
    final closed = _isThreadClosed;

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(healthDp(context, 12)),
        decoration: const BoxDecoration(
          color: _inputBarBg,
          border: Border(top: BorderSide(width: 1, color: _csBorder)),
        ),
        child: IgnorePointer(
          ignoring: closed,
          child: Opacity(
            opacity: closed ? 0.7 : 1,
            child: GestureDetector(
              onTap: closed ? null : () => _inputFocus.requestFocus(),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: healthDp(context, 8),
                  vertical: healthDp(context, 6),
                ),
                decoration: ShapeDecoration(
                  color: _inputFieldBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(healthDp(context, 22)),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        focusNode: _inputFocus,
                        enabled: !closed,
                        readOnly: closed,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.send,
                        minLines: 1,
                        maxLines: 5,
                        enableInteractiveSelection: !closed,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: healthSp(context, 15),
                          fontFamily: _font,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          hintText: closed
                              ? '종료된 문의입니다. 추가 질문은 불가합니다.'
                              : '문의하실 내용을 입력해주세요',
                          hintStyle: TextStyle(
                            color: _hint,
                            fontSize: healthSp(context, closed ? 13 : 15),
                            fontFamily: _font,
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: healthDp(context, 12),
                            vertical: healthDp(context, 8),
                          ),
                        ),
                        onSubmitted: closed ? null : (_) => _sendFollowUp(),
                      ),
                    ),
                    SizedBox(width: healthDp(context, 8)),
                    GestureDetector(
                      onTap: (closed || _sending) ? null : _sendFollowUp,
                      child: Container(
                        width: healthDp(context, 32),
                        height: healthDp(context, 32),
                        decoration: const ShapeDecoration(
                          color: _pink,
                          shape: CircleBorder(),
                        ),
                        alignment: Alignment.center,
                        child: _sending
                            ? SizedBox(
                                width: healthDp(context, 14),
                                height: healthDp(context, 14),
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                Icons.arrow_upward_rounded,
                                size: healthDp(context, 18),
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _ChatItemType { date, user, cs, target, topicGuide, topicUser }

class _ChatItem {
  final _ChatItemType type;
  final String? dateLabel;
  final QaInquiry? question;
  final String? csText;
  final String? csDatetime;
  final String? topicCategory;
  final String? selectedTopic;
  final String? topicUserText;

  const _ChatItem._({
    required this.type,
    this.dateLabel,
    this.question,
    this.csText,
    this.csDatetime,
    this.topicCategory,
    this.selectedTopic,
    this.topicUserText,
  });

  factory _ChatItem.date(String label) =>
      _ChatItem._(type: _ChatItemType.date, dateLabel: label);

  factory _ChatItem.user(QaInquiry q) =>
      _ChatItem._(type: _ChatItemType.user, question: q);

  factory _ChatItem.cs({required String text, required String datetime}) =>
      _ChatItem._(
        type: _ChatItemType.cs,
        csText: text,
        csDatetime: datetime,
      );

  factory _ChatItem.target(QaInquiry q) =>
      _ChatItem._(type: _ChatItemType.target, question: q);

  factory _ChatItem.topicGuide({
    required String category,
    required String selectedTopic,
  }) =>
      _ChatItem._(
        type: _ChatItemType.topicGuide,
        topicCategory: category,
        selectedTopic: selectedTopic,
      );

  factory _ChatItem.topicUser({
    required String text,
  }) =>
      _ChatItem._(
        type: _ChatItemType.topicUser,
        topicUserText: text,
      );
}

class _TopicChip extends StatelessWidget {
  final String label;
  final bool selected;

  const _TopicChip({
    required this.label,
    required this.selected,
  });

  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _border = Color(0xFFD2D2D2);
  static const String _font = 'Gmarket Sans TTF';

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: selected ? 1 : 0.45,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 12),
          vertical: healthDp(context, 8),
        ),
        decoration: BoxDecoration(
          color: selected ? const Color(0x14FF5A8D) : Colors.white,
          borderRadius: BorderRadius.circular(healthDp(context, 999)),
          border: Border.all(
            color: selected ? _pink : _border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? _pink : const Color(0xFF1A1A1A),
            fontSize: healthSp(context, 12),
            fontFamily: _font,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

/// ��ü+������ �� Path�� �׷� ������ ���� ����
class _ChatBubblePainter extends CustomPainter {
  final Color color;
  final Color? borderColor;
  final bool isUser;
  final double radius;
  final double tailSize;

  const _ChatBubblePainter({
    required this.color,
    required this.isUser,
    required this.radius,
    required this.tailSize,
    this.borderColor,
  });

  Path _buildPath(Size size) {
    final r = radius.clamp(4.0, size.shortestSide / 2);
    final t = tailSize.clamp(4.0, 14.0);
    final w = size.width;
    final h = size.height;
    final path = Path();

    if (isUser) {
      // ���� ��� ���� ? ���� ����
      final bodyRight = w - t;
      path.moveTo(r, 0);
      path.lineTo(w, 0);
      path.lineTo(bodyRight, t);
      path.lineTo(bodyRight, h - r);
      path.arcToPoint(
        Offset(bodyRight - r, h),
        radius: Radius.circular(r),
        clockwise: true,
      );
      path.lineTo(r, h);
      path.arcToPoint(
        Offset(0, h - r),
        radius: Radius.circular(r),
        clockwise: true,
      );
      path.lineTo(0, r);
      path.arcToPoint(
        Offset(r, 0),
        radius: Radius.circular(r),
        clockwise: true,
      );
      path.close();
    } else {
      // ���� ��� ���� ? ���� ����
      final bodyLeft = t;
      path.moveTo(0, 0);
      path.lineTo(w - r, 0);
      path.arcToPoint(
        Offset(w, r),
        radius: Radius.circular(r),
        clockwise: true,
      );
      path.lineTo(w, h - r);
      path.arcToPoint(
        Offset(w - r, h),
        radius: Radius.circular(r),
        clockwise: true,
      );
      path.lineTo(bodyLeft + r, h);
      path.arcToPoint(
        Offset(bodyLeft, h - r),
        radius: Radius.circular(r),
        clockwise: true,
      );
      path.lineTo(bodyLeft, t);
      path.lineTo(0, 0);
      path.close();
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);
    canvas.drawShadow(path, const Color(0x14000000), 3, false);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );
    if (borderColor != null) {
      canvas.drawPath(
        path,
        Paint()
          ..color = borderColor!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChatBubblePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.isUser != isUser ||
        oldDelegate.radius != radius ||
        oldDelegate.tailSize != tailSize;
  }
}
