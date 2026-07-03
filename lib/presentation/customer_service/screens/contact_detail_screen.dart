import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../data/models/contact/contact_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/contact_service.dart';
import '../../../data/services/content_service.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/confirm_dialog.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../widget/contact_inquiry_type_filters.dart';
import 'contact_form_screen.dart';

class ContactDetailScreen extends StatefulWidget {
  final int wrId;

  const ContactDetailScreen({
    super.key,
    required this.wrId,
  });

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  Contact? _contact;
  List<Contact> _thread = [];
  int? _rootWrId;
  final Map<int, List<Contact>> _repliesByWrId = {};
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentUserId;
  Map<int, bool>? _cardExpanded;
  Map<int, bool>? _answerExpanded;
  bool _didInitialScroll = false;

  Map<int, bool> get _cardExpandedMap => _cardExpanded ??= <int, bool>{};

  Map<int, bool> get _answerExpandedMap =>
      _answerExpanded ??= <int, bool>{};

  final ScrollController _scrollController = ScrollController();

  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kPinkAccent = Color(0xFFB41D56);
  static const Color _kGrayIcon = Color(0xFF5C5F61);
  static const Color _kBorderRose = Color(0x4CE0BEC4);
  static const Color _kQuestionBgPast = Color(0x7FF3F3F4);
  static const Color _kTextMain = Color(0xFF1A1C1C);
  static const Color _kTextBody = Color(0xFF584045);
  static const Color _kActionGray = Color(0xFF898383);
  static const Color _kMutedGray = Color(0xFF898686);
  static const Color _kButtonBorder = Color(0xFFD2D2D2);
  static const Color _kBadgeAnsweredBg = Color(0x19B41D56);
  static const Color _kBadgeUnansweredBg = Color(0xFFE8E8E8);
  static const Color _kAnswerCardBorder = Color(0xFFE1BEC5);
  static const Color _kAnswerIconPink = Color(0x7FFF5A8D);

  static const Color _kCardDateText = Color(0xFF5C5F61);
  static const Color _kCardTitleText = Color(0xFF1A1C1C);
  static const Color _kCardBodyText = Color(0xFF584045);

  double _pagePadH(BuildContext context) => healthDp(context, 27);

  TextStyle _gmarket(
    BuildContext context, {
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w500,
    double? height,
    double? letterSpacing,
  }) =>
      TextStyle(
        color: color,
        fontSize: healthSp(context, size),
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
      );

  TextStyle _cardDateStyle(BuildContext context) => _gmarket(
        context,
        size: 13,
        color: _kCardDateText,
        weight: FontWeight.w500,
        height: 1.5,
      );

  TextStyle _cardTitleStyle(BuildContext context) => _gmarket(
        context,
        size: 13,
        color: _kCardTitleText,
        weight: FontWeight.w500,
        height: 1.5,
      );

  TextStyle _cardBodyStyle(BuildContext context) => _gmarket(
        context,
        size: 10,
        color: _kCardBodyText,
        weight: FontWeight.w300,
        height: 1.5,
      );

  @override
  void initState() {
    super.initState();
    _loadContactDetail();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadContactDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _didInitialScroll = false;
    });

    try {
      final payload = await ContactService.getContactDetail(widget.wrId);
      if (payload != null) {
        setState(() {
          _contact = payload.contact;
          _thread = payload.thread;
          _rootWrId = payload.rootWrId;
          _isLoading = false;
        });

        await _loadCurrentUser();
        await _loadRepliesForThread();
        if (!mounted) return;
        setState(_initCardExpanded);
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

  Future<void> _loadCurrentUser() async {
    final user = await AuthService.getUser();
    if (!mounted) return;
    setState(() => _currentUserId = user?.id);
  }

  Future<void> _loadRepliesForThread() async {
    final targets =
        _allQuestions.map((q) => q.wrId).where((id) => id > 0).toList();
    if (targets.isEmpty) {
      _scheduleScrollToBottom();
      return;
    }
    try {
      final futures = targets.map(ContactService.getContactReplies).toList();
      final results = await Future.wait(futures);
      if (!mounted) return;
      final map = <int, List<Contact>>{};
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

  bool _isAnswered(Contact c) {
    if (c.hasReply) return true;
    final list = _repliesByWrId[c.wrId] ?? const <Contact>[];
    return list.isNotEmpty || c.wrReply.trim().isNotEmpty;
  }

  String _answerHtmlFor(Contact q) {
    final direct = q.wrReply.trim();
    if (direct.isNotEmpty) return direct;
    final list = _repliesByWrId[q.wrId] ?? const <Contact>[];
    if (list.isNotEmpty) return list.first.wrContent.trim();
    return '';
  }

  String _answerDatetimeFor(Contact q) {
    final list = _repliesByWrId[q.wrId] ?? const <Contact>[];
    if (list.isNotEmpty) {
      final r = list.first;
      if (r.wrDatetime.isNotEmpty) return r.wrDatetime;
      if (r.wrLast.isNotEmpty) return r.wrLast;
    }
    if (q.wrLast.isNotEmpty) return q.wrLast;
    return q.wrDatetime;
  }

  DateTime? _parseDate(String raw) {
    if (raw.trim().isEmpty) return null;
    return DateDisplayFormatter.tryParseYmdFlexible(raw) ??
        DateTime.tryParse(raw);
  }

  DateTime _todayDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  bool _isBeforeToday(String raw) {
    final parsed = _parseDate(raw);
    if (parsed == null) return false;
    final date = DateTime(parsed.year, parsed.month, parsed.day);
    return date.isBefore(_todayDate());
  }

  bool _isToday(String raw) {
    final parsed = _parseDate(raw);
    if (parsed == null) return false;
    final date = DateTime(parsed.year, parsed.month, parsed.day);
    return date == _todayDate();
  }

  List<Contact> get _allQuestions {
    final base = <Contact>[
      ..._thread,
      if (_contact != null) _contact!,
    ];
    final byId = <int, Contact>{};
    for (final c in base) {
      if (c.wrId > 0) byId[c.wrId] = c;
    }
    final unique = byId.values.toList();
    unique.sort((a, b) {
      final byDt = a.wrDatetime.compareTo(b.wrDatetime);
      if (byDt != 0) return byDt;
      return a.wrId.compareTo(b.wrId);
    });
    return unique;
  }

  int? get _latestWrId {
    final qs = _allQuestions;
    if (qs.isEmpty) return null;
    return qs.last.wrId;
  }

  int get _followupCount {
    final root = _rootWrId;
    if (root == null) return 0;
    return _allQuestions.where((c) => c.wrId != root).length;
  }

  int get _questionCount => _allQuestions.length;

  int get _answerCount => _allQuestions.where(_isAnswered).length;

  bool get _isSimpleThread => _questionCount <= 1;

  bool _shouldShowLatestBadge(Contact q) {
    if (_isAnswered(q)) return false;
    if (q.wrId != _latestWrId) return false;
    return _isToday(q.wrDatetime);
  }

  bool get _hasPastInquiry =>
      _allQuestions.any((q) => !_isToday(q.wrDatetime));

  bool get _hasTodayInquiry =>
      _allQuestions.any((q) => _isToday(q.wrDatetime));

  bool get _shouldShowTodayDivider =>
      _hasPastInquiry && _hasTodayInquiry;

  void _initCardExpanded() {
    final cardMap = _cardExpandedMap;
    final answerMap = _answerExpandedMap;
    cardMap.clear();
    answerMap.clear();

    final latestId = _latestWrId;

    for (final q in _allQuestions) {
      if (_isSimpleThread) {
        cardMap[q.wrId] = true;
        answerMap[q.wrId] = _isAnswered(q);
      } else {
        final isLatest = q.wrId == latestId;
        cardMap[q.wrId] = isLatest;
        answerMap[q.wrId] = isLatest && _isAnswered(q);
      }
    }
  }

  bool _isCardExpanded(Contact q) {
    final cardMap = _cardExpanded;
    if (cardMap != null && cardMap.containsKey(q.wrId)) {
      return cardMap[q.wrId]!;
    }
    if (_isSimpleThread) return true;
    return q.wrId == _latestWrId;
  }

  bool _isAnswerExpanded(Contact q) {
    if (!_isAnswered(q)) return false;
    final answerMap = _answerExpanded;
    if (answerMap != null && answerMap.containsKey(q.wrId)) {
      return answerMap[q.wrId]!;
    }
    if (_isSimpleThread) return true;
    return q.wrId == _latestWrId;
  }

  void _toggleCardExpanded(int wrId) {
    setState(() {
      final q = _allQuestions.firstWhere(
        (c) => c.wrId == wrId,
        orElse: () => _contact!,
      );
      final next = !_isCardExpanded(q);
      _cardExpandedMap[wrId] = next;
      if (_isAnswered(q)) {
        _answerExpandedMap[wrId] = next;
      }
    });
  }

  bool get _isThreadClosed {
    final rootId = _rootWrId ?? widget.wrId;
    for (final q in _allQuestions) {
      if (q.wrId == rootId) return q.isClosed;
    }
    return _contact?.isClosed ?? false;
  }

  Future<void> _confirmAndCloseInquiry() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: '문의 종료',
      message: '문의를 종료하시겠습니까?\n종료 후에는 추가질문·수정·삭제가 불가합니다.',
      cancelText: '취소',
      confirmText: '종료',
    );
    if (!confirmed || !mounted) return;

    try {
      final root = _rootWrId ?? widget.wrId;
      final result = await ContactService.closeContact(root);
      if (!mounted) return;
      if (result['success'] == true) {
        _loadContactDetail();
      }
    } catch (_) {
      // 종료 실패는 무시
    }
  }

  bool _canEditFor(Contact c) {
    if (_isThreadClosed) return false;
    if (_currentUserId == null || _currentUserId != c.mbId) return false;
    return !_isAnswered(c);
  }

  bool _canDeleteFor(Contact c) {
    if (_isThreadClosed) return false;
    if (_currentUserId == null || _currentUserId != c.mbId) return false;
    if (_isAnswered(c)) return false;
    return true;
  }

  Future<void> _confirmAndDeleteContact(int wrId) async {
    if (_contact == null) return;
    final target = _allQuestions.firstWhere(
      (c) => c.wrId == wrId,
      orElse: () => _contact!,
    );
    if (!_canDeleteFor(target)) return;

    final confirmed = await ConfirmDialog.show(
      context,
      title: '1:1 문의 삭제',
      message: '문의를 삭제하시겠습니까?',
      cancelText: '취소',
      confirmText: '삭제',
    );
    if (!confirmed || !mounted) return;

    try {
      final result = await ContactService.deleteContact(wrId);
      if (!mounted) return;
      if (result['success'] == true) {
        if (wrId == (_rootWrId ?? widget.wrId)) {
          Navigator.of(context).pop(true);
        } else {
          _loadContactDetail();
        }
      }
    } catch (_) {
      // 삭제 실패는 무시
    }
  }

  Future<void> _navigateToEdit(Contact c) async {
    if (_contact == null) return;
    if (!_canEditFor(c)) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactFormScreen(
          contact: c,
          onSuccess: _loadContactDetail,
        ),
      ),
    );

    if (mounted && result == true) {
      _loadContactDetail();
    }
  }

  Widget _buildStatusBadge({
    required String label,
    required Color bg,
    required Color fg,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 8),
        vertical: healthDp(context, 2),
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(healthDp(context, 9999)),
      ),
      child: Text(
        label,
        style: _gmarket(
          context,
          size: 10,
          color: fg,
          weight: FontWeight.w500,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildQIcon(Contact q) {
    final usePastStyle = _usesPastAnsweredBg(q, forAnswerCard: false);
    return Container(
      width: healthDp(context, 24),
      height: healthDp(context, 24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: usePastStyle ? _kGrayIcon : _kPink,
        shape: BoxShape.circle,
        boxShadow: usePastStyle
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0C000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
      ),
      child: Text(
        'Q',
        style: _gmarket(
          context,
          size: 12,
          color: Colors.white,
          weight: FontWeight.w700,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _buildQuestionHeader({
    required Contact q,
    required bool isExpanded,
  }) {
    final answered = _isAnswered(q);
    final showLatestBadge = _shouldShowLatestBadge(q);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildQIcon(q),
        SizedBox(width: healthDp(context, 8)),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: healthDp(context, 8),
            runSpacing: healthDp(context, 4),
            children: [
              Text(
                DateDisplayFormatter.formatYmdFromString(q.wrDatetime),
                style: _cardDateStyle(context),
              ),
              if (answered)
                _buildStatusBadge(
                  label: '답변완료',
                  bg: _kBadgeAnsweredBg,
                  fg: _kPink,
                ),
              if (!answered)
                _buildStatusBadge(
                  label: '답변대기',
                  bg: _kBadgeUnansweredBg,
                  fg: _kGrayIcon,
                ),
              if (showLatestBadge)
                _buildStatusBadge(
                  label: '최신',
                  bg: _kPink,
                  fg: Colors.black,
                ),
            ],
          ),
        ),
        GestureDetector(
          onTap: () => _toggleCardExpanded(q.wrId),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: EdgeInsets.only(left: healthDp(context, 4)),
            child: Icon(
              isExpanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: healthDp(context, 22),
              color: _kPink,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionActions(Contact c) {
    final canEdit = _canEditFor(c);
    final canDelete = _canDeleteFor(c);
    if (!canEdit && !canDelete) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: healthDp(context, 12)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (canEdit) ...[
            GestureDetector(
              onTap: () => _navigateToEdit(c),
              child: Text(
                '수정',
                style: _gmarket(
                  context,
                  size: 10,
                  color: _kActionGray,
                  weight: FontWeight.w300,
                ),
              ),
            ),
            Container(
              width: healthDp(context, 0.5),
              height: healthDp(context, 10),
              margin: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
              color: _kActionGray,
            ),
          ],
          if (canDelete)
            GestureDetector(
              onTap: () => _confirmAndDeleteContact(c.wrId),
              child: Text(
                '삭제',
                style: _gmarket(
                  context,
                  size: 10,
                  color: _kActionGray,
                  weight: FontWeight.w300,
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool _usesPastAnsweredBg(Contact q, {required bool forAnswerCard}) {
    if (_isThreadClosed) return true;
    if (forAnswerCard) {
      return _isBeforeToday(_answerDatetimeFor(q));
    }
    return _isAnswered(q) && !_isToday(q.wrDatetime);
  }

  Widget _buildQuestionCard(Contact q) {
    final subject = contactDisplayTitle(q.wrSubject);
    final usePastBg = _usesPastAnsweredBg(q, forAnswerCard: false);
    final isExpanded = _isCardExpanded(q);
    final isLatestQuestion = q.wrId == _latestWrId;
    final radius = BorderRadius.circular(healthDp(context, 12));
    final showActions =
        isLatestQuestion && (_canEditFor(q) || _canDeleteFor(q)) && isExpanded;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 16)),
      decoration: ShapeDecoration(
        color: usePastBg ? _kQuestionBgPast : Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: _kBorderRose),
          borderRadius: radius,
        ),
        shadows: usePastBg
            ? null
            : const [
                BoxShadow(
                  color: Color(0x0C000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuestionHeader(
            q: q,
            isExpanded: isExpanded,
          ),
          SizedBox(height: healthDp(context, 4)),
          Text(
            subject,
            style: _cardTitleStyle(context),
          ),
          if (isExpanded) ...[
            SizedBox(height: healthDp(context, 4)),
            _buildContactHtmlBody(
              q.wrContent,
              style: _cardBodyStyle(context),
            ),
            if (showActions) _buildQuestionActions(q),
          ],
        ],
      ),
    );
  }

  Widget _buildAnswerAIcon(Contact q) {
    final usePastStyle = _usesPastAnsweredBg(q, forAnswerCard: true);
    return Container(
      width: healthDp(context, 24),
      height: healthDp(context, 24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: usePastStyle ? _kGrayIcon : _kAnswerIconPink,
        shape: BoxShape.circle,
      ),
      child: Text(
        'A',
        textAlign: TextAlign.center,
        style: _gmarket(
          context,
          size: 12,
          color: Colors.white,
          weight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }

  Widget _buildAnswerCard(Contact q) {
    final answerHtml = _answerHtmlFor(q);
    if (answerHtml.isEmpty) return const SizedBox.shrink();

    final answerDate = DateDisplayFormatter.formatYmdFromString(
      _answerDatetimeFor(q),
    );
    final usePastBg = _usesPastAnsweredBg(q, forAnswerCard: true);
    final cardPad = healthDp(context, 20);
    final cardRadius = healthDp(context, 8);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildAnswerAIcon(q),
            SizedBox(width: healthDp(context, 12)),
            Flexible(
              child: Text(
                '답변 완료 · $answerDate',
                style: _cardDateStyle(context),
              ),
            ),
          ],
        ),
        SizedBox(height: healthDp(context, 4)),
        _buildContactHtmlBody(
          answerHtml,
          style: _cardBodyStyle(context),
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(cardPad),
      decoration: ShapeDecoration(
        color: usePastBg ? _kQuestionBgPast : Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(
            width: 1,
            color: _kAnswerCardBorder,
          ),
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      child: content,
    );
  }

  Widget _buildQaAnswerWithConnector(Contact q) {
    final qLineX = healthDp(context, 28);
    final gap = healthDp(context, 5);
    final hookArm = healthDp(context, 8);
    final verticalStem = healthDp(context, 6);
    final stroke = healthDp(context, 2);
    final radius = healthDp(context, 6);
    const lineColor = Color(0xFFE0BEC4);
    final hookShiftLeft = healthDp(context, 15);
    final half = stroke / 2;
    final hookLeft = qLineX - half - hookShiftLeft;
    final hookWidth = hookArm + radius + stroke;
    final answerIndent = hookLeft + hookWidth - half;
    final upExtent = gap + verticalStem;
    final hookDrop = healthDp(context, 6);

    return Padding(
      padding: EdgeInsets.only(top: gap),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.only(left: answerIndent),
            child: _buildAnswerCard(q),
          ),
          Positioned(
            left: hookLeft,
            top: -upExtent + hookDrop,
            width: hookWidth,
            height: upExtent + stroke + hookDrop,
            child: CustomPaint(
              painter: _AnswerCardHookPainter(
                cornerRadius: radius,
                strokeWidth: stroke,
                color: lineColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQaBlock(Contact q) {
    final hasAnswer = _isAnswered(q);
    final isExpanded = _isCardExpanded(q);
    final showAnswer = hasAnswer && isExpanded && _isAnswerExpanded(q);
    return Padding(
      padding: EdgeInsets.only(bottom: healthDp(context, 10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildQuestionCard(q),
          if (showAnswer) _buildQaAnswerWithConnector(q),
        ],
      ),
    );
  }

  Widget _buildTodayDivider() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: healthDp(context, 10)),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              color: _kBorderRose,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: healthDp(context, 16)),
            child: Text(
              '오늘',
              style: _gmarket(
                context,
                size: 12,
                color: _kGrayIcon,
                weight: FontWeight.w500,
                height: 1.33,
                letterSpacing: 0.24,
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 1,
              color: _kBorderRose,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildThreadContent() {
    final widgets = <Widget>[];
    var dividerShown = false;

    for (final q in _allQuestions) {
      if (_shouldShowTodayDivider && !dividerShown && _isToday(q.wrDatetime)) {
        widgets.add(_buildTodayDivider());
        dividerShown = true;
      }
      widgets.add(_buildQaBlock(q));
    }

    return widgets;
  }

  Widget _buildFixedBottomBar() {
    if (_isThreadClosed) {
      return Container(
        padding: EdgeInsets.fromLTRB(
          _pagePadH(context),
          healthDp(context, 12),
          _pagePadH(context),
          healthDp(context, 20),
        ),
        color: Colors.white,
        child: SafeArea(
          top: false,
          child: SizedBox(
            width: double.infinity,
            height: healthDp(context, 40),
            child: FilledButton(
              onPressed: null,
              style: FilledButton.styleFrom(
                disabledBackgroundColor: const Color(0xFFD2D2D2),
                disabledForegroundColor: _kMutedGray,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 10)),
                ),
                padding: EdgeInsets.all(healthDp(context, 10)),
              ),
              child: Text(
                '종료된 문의입니다',
                style: _gmarket(
                  context,
                  size: 16,
                  color: _kMutedGray,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
        _pagePadH(context),
        healthDp(context, 12),
        _pagePadH(context),
        healthDp(context, 20),
      ),
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: healthDp(context, 40),
                child: OutlinedButton(
                  onPressed: () {
                    final root = _rootWrId ?? widget.wrId;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ContactFormScreen(
                          parentWrId: root,
                          onSuccess: _loadContactDetail,
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kMutedGray,
                    side: BorderSide(
                      width: healthDp(context, 0.5),
                      color: _kButtonBorder,
                    ),
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(healthDp(context, 10)),
                    ),
                    padding: EdgeInsets.all(healthDp(context, 10)),
                  ),
                  child: Text(
                    '추가질문',
                    style: _gmarket(
                      context,
                      size: 16,
                      color: _kMutedGray,
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: healthDp(context, 20)),
            Expanded(
              child: SizedBox(
                height: healthDp(context, 40),
                child: FilledButton(
                  onPressed: _confirmAndCloseInquiry,
                  style: FilledButton.styleFrom(
                    backgroundColor: _kPink,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(healthDp(context, 10)),
                    ),
                    padding: EdgeInsets.all(healthDp(context, 10)),
                  ),
                  child: Text(
                    '종료하기',
                    style: _gmarket(
                      context,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
    );
    final textScale =
        healthTextScaleByWidth(MediaQuery.sizeOf(context).width);

    return Theme(
      data: gmarketTheme,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(
            fontFamily: 'Gmarket Sans TTF',
            color: _kTextMain,
          ),
          child: MobileAppLayoutWrapper(
            backgroundColor: Colors.white,
            appBar: HealthAppBar(
              title: '1:1 문의상세',
              titleFontSize: healthSp(context, 16),
              leadingIconSize: healthDp(context, 24),
            ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: _kPink))
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: _pagePadH(context),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: _gmarket(
                                  context,
                                  size: 14,
                                  color: Colors.red,
                                ),
                              ),
                              SizedBox(height: healthDp(context, 16)),
                              ElevatedButton(
                                onPressed: _loadContactDetail,
                                child: const Text('다시 시도'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _contact == null
                        ? Center(
                            child: Text(
                              '문의를 찾을 수 없습니다.',
                              style: _gmarket(
                                context,
                                size: 14,
                                color: _kTextMain,
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  controller: _scrollController,
                                  padding: EdgeInsets.fromLTRB(
                                    _pagePadH(context),
                                    healthDp(context, 20),
                                    _pagePadH(context),
                                    healthDp(context, 20),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: _buildThreadContent(),
                                  ),
                                ),
                              ),
                              _buildFixedBottomBar(),
                            ],
                          ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactHtmlBody(
    String rawHtml, {
    TextStyle? style,
    Color? textColor,
    double? bodyLineHeight,
    double? bodyFontSize,
    FontWeight bodyWeight = FontWeight.w300,
  }) {
    final baseStyle = style ??
        _gmarket(
          context,
          size: bodyFontSize ?? 14,
          color: textColor ?? _kTextBody,
          weight: bodyWeight,
          height: bodyLineHeight ?? 1.71,
        );
    final lineHeight = baseStyle.height ?? 1.71;
    final trimmed = rawHtml.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();
    final processed = ContentService.prepareContentHtmlForRender(rawHtml);
    if (processed.trim().isEmpty) {
      return Text(
        ContentService.normalizeHtmlToText(rawHtml),
        style: baseStyle,
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final htmlGap = healthDp(context, 8);
        return Html(
          data: processed,
          style: {
            'html': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
            'body': Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              fontFamily: baseStyle.fontFamily,
              fontSize: FontSize(baseStyle.fontSize ?? healthSp(context, 14)),
              fontWeight: baseStyle.fontWeight ?? bodyWeight,
              lineHeight: LineHeight(lineHeight),
              textAlign: TextAlign.start,
              color: baseStyle.color,
            ),
            'p': Style(
              margin: Margins.only(bottom: htmlGap),
              padding: HtmlPaddings.zero,
            ),
            'strong': Style(
              color: _kPinkAccent,
              fontWeight: FontWeight.w300,
            ),
            'b': Style(
              color: _kPinkAccent,
              fontWeight: FontWeight.w300,
            ),
            'img': Style(
              width: Width(maxWidth),
              display: Display.block,
              margin: Margins.symmetric(vertical: htmlGap),
            ),
            'div': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
            'span': Style(fontFamily: 'Gmarket Sans TTF'),
          },
        );
      },
    );
  }
}

/// 답변 카드 상단에 붙는 연결선 — 위로 올라간 뒤 답변 카드 상단 테두리로 꺾임
class _AnswerCardHookPainter extends CustomPainter {
  const _AnswerCardHookPainter({
    required this.cornerRadius,
    required this.strokeWidth,
    required this.color,
  });

  final double cornerRadius;
  final double strokeWidth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final r = cornerRadius.clamp(0.0, size.shortestSide / 2);
    final half = strokeWidth / 2;
    final baseY = size.height - half;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      ..moveTo(half, half)
      ..lineTo(half, baseY - r)
      ..arcToPoint(
        Offset(half + r, baseY),
        radius: Radius.circular(r),
        clockwise: false,
      )
      ..lineTo(size.width - half, baseY);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _AnswerCardHookPainter oldDelegate) {
    return cornerRadius != oldDelegate.cornerRadius ||
        strokeWidth != oldDelegate.strokeWidth ||
        color != oldDelegate.color;
  }
}
