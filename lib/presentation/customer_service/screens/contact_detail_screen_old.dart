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
  List<Contact> _replies = [];
  final Map<int, List<Contact>> _repliesByWrId = {};
  bool _isLoading = true;
  String? _errorMessage;
  bool? _canEditContact;
  bool? _canDeleteContact;

  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kPinkSoft = Color(0xFFFE98B0);
  static const Color _kBorderMuted = Color(0x7FD2D2D2);
  static const Color _kAnswerBg = Color(0x4CD2D2D2);
  static const Color _kDot = Color(0xFFE9E9E9);
  static const Color _kMutedGray = Color(0xFF898686);
  static const Color _kTextMain = Color(0xFF1A1A1A);
  static const Color _kActionGray = Color(0xFF898383);
  static const Color _kButtonBorder = Color(0xFFD2D2D2);

  double _pagePadH(BuildContext context) => healthDp(context, 27);

  TextStyle _contactText(
    BuildContext context, {
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w500,
    double? height,
  }) =>
      TextStyle(
        color: color,
        fontSize: healthSp(context, size),
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: weight,
        height: height,
      );

  Widget _buildQuestionActions(Contact c, {required bool canEdit, required bool canDelete}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canEdit) ...[
          TextButton(
            onPressed: () => _navigateToEdit(c),
            style: TextButton.styleFrom(
              foregroundColor: _kActionGray,
              padding: EdgeInsets.symmetric(
                horizontal: healthDp(context, 4),
                vertical: healthDp(context, 2),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '수정',
              style: _contactText(
                context,
                size: 10,
                color: _kActionGray,
                weight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            '|',
            style: _contactText(
              context,
              size: 10,
              color: _kActionGray,
              weight: FontWeight.w500,
            ),
          ),
        ],
        if (canDelete)
          TextButton(
            onPressed: () => _confirmAndDeleteContact(c.wrId),
            style: TextButton.styleFrom(
              foregroundColor: _kActionGray,
              padding: EdgeInsets.symmetric(
                horizontal: healthDp(context, 4),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '삭제',
              style: _contactText(
                context,
                size: 10,
                color: _kActionGray,
                weight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _loadContactDetail();
  }

  Future<void> _loadContactDetail() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
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

        await _checkCanEdit();
        _loadRepliesForThread();
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
    final targets = _threadQuestions.map((q) => q.wrId).where((id) => id > 0).toList();
    if (targets.isEmpty) return;
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
        // 기존 코드 호환(수정 가능 여부 판단 등)
        _replies = _repliesByWrId.values.expand((e) => e).toList();
      });
      _checkCanEdit();
    } catch (_) {
      // 답변 로드 실패는 무시
    }
  }

  Future<void> _checkCanEdit() async {
    if (_contact == null) {
      if (mounted) {
        setState(() {
          _canEditContact = false;
          _canDeleteContact = false;
        });
      }
      return;
    }

    final user = await AuthService.getUser();
    if (!mounted) return;
    final owner = user != null && user.id == _contact!.mbId;
    final answered = _contact!.hasReply || _replies.isNotEmpty;

    setState(() {
      _canEditContact = owner && !answered;
      _canDeleteContact = owner;
    });
  }

  bool _isAnswered(Contact c) {
    if (c.hasReply) return true;
    final list = _repliesByWrId[c.wrId] ?? const <Contact>[];
    return list.isNotEmpty;
  }

  bool _canEditFor(Contact c) {
    if (_canEditContact != true) return false; // 원글/추가질문 공통: 소유자만
    return !_isAnswered(c);
  }

  bool _canDeleteFor(Contact c) {
    return _canDeleteContact == true; // 원글/추가질문 공통: 소유자만
  }

  Future<void> _confirmAndDeleteContact(int wrId) async {
    if (_contact == null) return;
    final target = _threadQuestions.firstWhere(
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
        // 원글을 삭제하면 상세를 닫고, 추가질문 삭제면 상세를 새로고침
        if (wrId == (_rootWrId ?? widget.wrId)) {
          Navigator.of(context).pop(true);
        } else {
          _loadContactDetail();
        }
      }
    } catch (e) {
      if (!mounted) return;
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
          onSuccess: () {
            _loadContactDetail();
          },
        ),
      ),
    );

    if (mounted && result == true) {
      _loadContactDetail();
    }
  }

  Widget _buildQuestionCardFor(Contact c) {
    final canEdit = _canEditFor(c);
    final canDelete = _canDeleteFor(c);
    final hasActions = canEdit || canDelete;
    final cardRadius = healthDp(context, 12);
    final qSize = healthDp(context, 40);
    final subject = c.wrSubject.isEmpty ? '(제목 없음)' : c.wrSubject;
    final titleStyle = _contactText(
      context,
      size: 16,
      color: _kTextMain,
      weight: FontWeight.w700,
      height: 1.5,
    );

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(cardRadius),
        border: Border.all(color: _kBorderMuted, width: healthDp(context, 1)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: healthDp(context, 4),
              decoration: BoxDecoration(
                color: _kPink,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(cardRadius),
                  bottomLeft: Radius.circular(cardRadius),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              healthDp(context, 24),
              hasActions ? healthDp(context, 10) : healthDp(context, 24),
              healthDp(context, 24),
              healthDp(context, 24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasActions)
                  Align(
                    alignment: Alignment.centerRight,
                    child: _buildQuestionActions(
                      c,
                      canEdit: canEdit,
                      canDelete: canDelete,
                    ),
                  ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: qSize,
                      height: qSize,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: _kPink,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        'Q',
                        style: _contactText(
                          context,
                          size: 20,
                          color: Colors.white,
                          weight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                    SizedBox(width: healthDp(context, 12)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subject,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: titleStyle,
                          ),
                          Text(
                            DateDisplayFormatter.formatYmdFromString(
                              c.wrDatetime,
                            ),
                            style: _contactText(
                              context,
                              size: 10,
                              color: _kTextMain,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: healthDp(context, 15)),
                _buildContactHtmlBody(c.wrContent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _answerHtmlFor(Contact q) {
    final direct = q.wrReply.trim();
    if (direct.isNotEmpty) return direct;
    // 백엔드 답변은 /:wrId/replies 에서 wr_7 -> wr_content 로 내려오는 케이스가 있음
    final list = _repliesByWrId[q.wrId] ?? const <Contact>[];
    if (list.isNotEmpty) return list.first.wrContent.trim();
    return '';
  }

  List<Contact> get _threadQuestions {
    final base = <Contact>[
      ..._thread,
      if (_contact != null) _contact!,
    ];
    // wr_id 기준 중복 제거 (contact + thread에 같은 글이 함께 오는 케이스 방지)
    final byId = <int, Contact>{};
    for (final c in base) {
      if (c.wrId > 0) byId[c.wrId] = c;
    }
    final unique = byId.values.toList();
    unique.sort((a, b) {
      final byDt = b.wrDatetime.compareTo(a.wrDatetime);
      if (byDt != 0) return byDt;
      return b.wrId.compareTo(a.wrId);
    });
    // 원글 + 추가질문 최대 2개 = 총 3개까지만 노출(시간역순)
    if (unique.length <= 3) return unique;
    return unique.take(3).toList();
  }

  int get _followupCount {
    final root = _rootWrId;
    if (root == null) return 0;
    return _threadQuestions.where((c) => c.wrId != root).length;
  }


  // 답변 카드
  Widget _buildAnswerCard(Contact reply) {
    final title = reply.wrSubject.trim().isEmpty ? '답변' : reply.wrSubject;
    final cardRadius = healthDp(context, 12);
    final aSize = healthDp(context, 32);
    final dotSize = healthDp(context, 16);
    return Padding(
      padding: EdgeInsets.only(top: healthDp(context, 20)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(left: healthDp(context, 24)),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              width: healthDp(context, 2),
              color: _kBorderMuted,
            ),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(healthDp(context, 24)),
              decoration: BoxDecoration(
                color: _kAnswerBg,
                borderRadius: BorderRadius.circular(cardRadius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: aSize,
                        height: aSize,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: _kPinkSoft,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          'A',
                          style: _contactText(
                            context,
                            size: 20,
                            color: Colors.white,
                            weight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                      SizedBox(width: healthDp(context, 12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: _contactText(
                                context,
                                size: 14,
                                color: _kTextMain,
                                weight: FontWeight.w700,
                                height: 1.43,
                              ),
                            ),
                            Text(
                              DateDisplayFormatter.formatYmdFromString(
                                reply.wrDatetime,
                              ),
                              style: _contactText(
                                context,
                                size: 10,
                                color: _kTextMain,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: healthDp(context, 15)),
                  _buildContactHtmlBody(_primaryContactHtml(reply)),
                ],
              ),
            ),
            Positioned(
              left: -healthDp(context, 33),
              top: -healthDp(context, 1),
              child: SizedBox(
                width: dotSize,
                height: dotSize,
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: _kDot,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildThreadBlocks() {
    final items = _threadQuestions;
    if (items.isEmpty) return const [];

    final blocks = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final q = items[i];
      final answerHtml = _answerHtmlFor(q);
      blocks.add(
        Padding(
          padding: EdgeInsets.only(bottom: healthDp(context, 24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildQuestionCardFor(q),
      
              if (answerHtml.isNotEmpty)
                _buildAnswerCard(
                  Contact(
                    wrId: q.wrId,
                    wrSubject: '',
                    wrContent: answerHtml,
                    mbId: q.mbId,
                    wrName: '관리자',
                    wrEmail: q.wrEmail,
                    wrDatetime: q.wrLast.isNotEmpty ? q.wrLast : q.wrDatetime,
                    wrLast: q.wrLast,
                    wrComment: q.wrComment,
                    wrReply: answerHtml,
                    wrParent: q.wrParent,
                    caName: q.caName,
                    wrHit: q.wrHit,
                    wrOption: q.wrOption,
                    wrIsComment: q.wrIsComment,
                  ),
                ),
            ],
          ),
        ),
      );
    }
    return blocks;
  }

  Widget _buildBottomButtons() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: healthDp(context, 40),
            child: OutlinedButton(
              onPressed: () {
                final root = _rootWrId ?? widget.wrId;
                if (_followupCount >= 2) {
                  return;
                }
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
                  borderRadius: BorderRadius.circular(
                    healthDp(context, 10),
                  ),
                ),
                padding: EdgeInsets.all(healthDp(context, 10)),
              ),
              child: Text(
                '추가질문',
                style: _contactText(
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
                  borderRadius: BorderRadius.circular(
                    healthDp(context, 10),
                  ),
                ),
                padding: EdgeInsets.all(healthDp(context, 10)),
              ),
              child: Text(
                '목록보기',
                style: _contactText(
                  context,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
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
                ? Center(
                    child: CircularProgressIndicator(color: _kPink),
                  )
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
                                style: _contactText(
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
                              style: _contactText(
                                context,
                                size: 14,
                                color: _kTextMain,
                              ),
                            ),
                          )
                        : ColoredBox(
                            color: Colors.white,
                            child: SingleChildScrollView(
                              padding: EdgeInsets.fromLTRB(
                                _pagePadH(context),
                                healthDp(context, 20),
                                _pagePadH(context),
                                healthDp(context, 20),
                              ),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  ..._buildThreadBlocks(),
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

  /// 본문 HTML 우선, 비어 있으면 답변 필드
  String _primaryContactHtml(Contact c) {
    if (c.wrContent.trim().isNotEmpty) return c.wrContent;
    return c.wrReply;
  }

  Widget _buildContactHtmlBody(String rawHtml) {
    final trimmed = rawHtml.trim();
    if (trimmed.isEmpty) {
      return const SizedBox.shrink();
    }
    final processed = ContentService.prepareContentHtmlForRender(rawHtml);
    if (processed.trim().isEmpty) {
      return Text(
        ContentService.normalizeHtmlToText(rawHtml),
        style: _contactText(
          context,
          size: 14,
          color: _kTextMain,
          weight: FontWeight.w300,
          height: 1.63,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPad = healthDp(context, 24) * 2;
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - horizontalPad;
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
              lineHeight: const LineHeight(1.63),
              textAlign: TextAlign.start,
              color: _kTextMain,
            ),
            'p': Style(
              margin: Margins.only(bottom: htmlGap),
              padding: HtmlPaddings.zero,
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
