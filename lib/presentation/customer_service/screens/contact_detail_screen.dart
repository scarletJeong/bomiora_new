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
  bool _pastHistoryExpanded = false;
  bool _didInitialScroll = false;

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

  bool _isPastHistory(Contact q) {
    if (!_isAnswered(q)) return false;
    return _isBeforeToday(_answerDatetimeFor(q));
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

  List<Contact> get _pastQuestions =>
      _allQuestions.where(_isPastHistory).toList();

  List<Contact> get _currentQuestions =>
      _allQuestions.where((q) => !_isPastHistory(q)).toList();

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

  bool _canEditFor(Contact c) {
    if (_currentUserId == null || _currentUserId != c.mbId) return false;
    return !_isAnswered(c);
  }

  bool _canDeleteFor(Contact c) {
    if (_currentUserId == null || _currentUserId != c.mbId) return false;
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

  Widget _buildQIcon({required bool isPast}) {
    return Container(
      width: healthDp(context, 24),
      height: healthDp(context, 24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isPast ? _kGrayIcon : _kPink,
        shape: BoxShape.circle,
        boxShadow: isPast
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

  Widget _buildAIcon({required bool isPast}) {
    return Container(
      width: healthDp(context, 24),
      height: healthDp(context, 24),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isPast ? _kGrayIcon : const Color(0x7FFF5A8D),
        shape: BoxShape.circle,
      ),
      child: Text(
        'A',
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
    required bool isPast,
    required bool isLatest,
  }) {
    final answered = _isAnswered(q);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _buildQIcon(isPast: isPast),
        SizedBox(width: healthDp(context, 8)),
        Text(
          DateDisplayFormatter.formatYmdFromString(q.wrDatetime),
          style: _gmarket(
            context,
            size: 16,
            color: _kGrayIcon,
            weight: FontWeight.w400,
            height: 1.5,
          ),
        ),
        if (answered) ...[
          SizedBox(width: healthDp(context, 8)),
          _buildStatusBadge(
            label: '답변완료',
            bg: _kBadgeAnsweredBg,
            fg: _kPink,
          ),
        ],
        if (!answered) ...[
          SizedBox(width: healthDp(context, 8)),
          _buildStatusBadge(
            label: '미답변',
            bg: _kBadgeUnansweredBg,
            fg: _kGrayIcon,
          ),
        ],
        if (isLatest) ...[
          SizedBox(width: healthDp(context, 8)),
          _buildStatusBadge(
            label: '최신',
            bg: _kPink,
            fg: Colors.black,
          ),
        ],
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
                  weight: FontWeight.w500,
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
                  weight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard(Contact q, {required bool isPast, required bool isLatest}) {
    final subject = q.wrSubject.isEmpty ? '(제목 없음)' : q.wrSubject;
    final radius = BorderRadius.circular(healthDp(context, 12));
    final showActions = isLatest && (_canEditFor(q) || _canDeleteFor(q));

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 16)),
      decoration: ShapeDecoration(
        color: isPast ? _kQuestionBgPast : Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: _kBorderRose),
          borderRadius: radius,
        ),
        shadows: isPast
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
          _buildQuestionHeader(q: q, isPast: isPast, isLatest: isLatest),
          SizedBox(height: healthDp(context, 4)),
          Text(
            subject,
            style: _gmarket(
              context,
              size: 16,
              color: _kTextMain,
              weight: isLatest && !_isAnswered(q)
                  ? FontWeight.w500
                  : FontWeight.w700,
              height: 1.5,
            ),
          ),
          SizedBox(height: healthDp(context, 4)),
          _buildContactHtmlBody(
            q.wrContent,
            textColor: _kTextBody,
          ),
          if (showActions) _buildQuestionActions(q),
        ],
      ),
    );
  }

  Widget _buildAnswerCard(Contact q, {required bool isPast}) {
    final answerHtml = _answerHtmlFor(q);
    if (answerHtml.isEmpty) return const SizedBox.shrink();

    final answerDate = DateDisplayFormatter.formatYmdFromString(
      _answerDatetimeFor(q),
    );
    final radius = BorderRadius.only(
      topRight: Radius.circular(healthDp(context, 12)),
      bottomRight: Radius.circular(healthDp(context, 12)),
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 16)),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 4, color: _kBorderRose),
          borderRadius: radius,
        ),
        shadows: const [
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
          Row(
            children: [
              _buildAIcon(isPast: isPast),
              SizedBox(width: healthDp(context, 8)),
              Text(
                '답변 완료 · $answerDate',
                style: _gmarket(
                  context,
                  size: 16,
                  color: _kGrayIcon,
                  weight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
            ],
          ),
          SizedBox(height: healthDp(context, 8)),
          _buildContactHtmlBody(answerHtml, textColor: _kTextMain),
        ],
      ),
    );
  }

  Widget _buildQaBlock(Contact q, {required bool isPast, required bool isLatest}) {
    final hasAnswer = _isAnswered(q);
    return Padding(
      padding: EdgeInsets.only(bottom: healthDp(context, 10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildQuestionCard(q, isPast: isPast, isLatest: isLatest),
          if (hasAnswer)
            Padding(
              padding: EdgeInsets.only(left: healthDp(context, 16)),
              child: _buildAnswerCard(q, isPast: isPast),
            ),
        ],
      ),
    );
  }

  Widget _buildPastHistoryDivider() {
    return GestureDetector(
      onTap: () => setState(() => _pastHistoryExpanded = !_pastHistoryExpanded),
      behavior: HitTestBehavior.opaque,
      child: Padding(
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '지난 문의 내역',
                    style: _gmarket(
                      context,
                      size: 12,
                      color: _kGrayIcon,
                      weight: FontWeight.w500,
                      height: 1.33,
                      letterSpacing: 0.24,
                    ),
                  ),
                  SizedBox(width: healthDp(context, 4)),
                  Icon(
                    _pastHistoryExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: healthDp(context, 16),
                    color: _kGrayIcon,
                  ),
                ],
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
      ),
    );
  }

  List<Widget> _buildThreadContent() {
    final past = _pastQuestions;
    final current = _currentQuestions;
    final latestId = _latestWrId;
    final widgets = <Widget>[];

    if (past.isNotEmpty && _pastHistoryExpanded) {
      for (final q in past) {
        widgets.add(
          _buildQaBlock(
            q,
            isPast: true,
            isLatest: q.wrId == latestId,
          ),
        );
      }
    }

    if (past.isNotEmpty) {
      widgets.add(_buildPastHistoryDivider());
    }

    for (final q in current) {
      widgets.add(
        _buildQaBlock(
          q,
          isPast: false,
          isLatest: q.wrId == latestId,
        ),
      );
    }

    return widgets;
  }

  Widget _buildBottomButtons() {
    return Padding(
      padding: EdgeInsets.only(top: healthDp(context, 38)),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: healthDp(context, 40),
              child: OutlinedButton(
                onPressed: () {
                  final root = _rootWrId ?? widget.wrId;
                  if (_followupCount >= 2) return;
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
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: _kPink,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(healthDp(context, 10)),
                  ),
                  padding: EdgeInsets.all(healthDp(context, 10)),
                ),
                child: Text(
                  '목록보기',
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
              title: '1:1 문의',
              titleFontSize: healthSp(context, 16),
              leadingIconSize: healthDp(context, 24),
            ),
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _kPink))
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
                        : ColoredBox(
                            color: Colors.white,
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              padding: EdgeInsets.fromLTRB(
                                _pagePadH(context),
                                healthDp(context, 20),
                                _pagePadH(context),
                                healthDp(context, 112),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ..._buildThreadContent(),
                                  _buildBottomButtons(),
                                ],
                              ),
                            ),
                          ),
          ),
        ),
      ),
    );
  }

  Widget _buildContactHtmlBody(String rawHtml, {required Color textColor}) {
    final trimmed = rawHtml.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();
    final processed = ContentService.prepareContentHtmlForRender(rawHtml);
    if (processed.trim().isEmpty) {
      return Text(
        ContentService.normalizeHtmlToText(rawHtml),
        style: _gmarket(
          context,
          size: 14,
          color: textColor,
          weight: FontWeight.w300,
          height: 1.71,
        ),
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
              fontFamily: 'Gmarket Sans TTF',
              fontSize: FontSize(healthSp(context, 14)),
              fontWeight: FontWeight.w300,
              lineHeight: const LineHeight(1.71),
              textAlign: TextAlign.start,
              color: textColor,
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
