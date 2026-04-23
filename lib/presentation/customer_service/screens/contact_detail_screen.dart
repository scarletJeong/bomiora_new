import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../data/models/contact/contact_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/contact_service.dart';
import '../../../data/services/content_service.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/app_bar.dart';
import '../../common/widgets/confirm_dialog.dart';
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
        _loadReplies();
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

  Future<void> _loadReplies() async {
    try {
      final replies = await ContactService.getContactReplies(widget.wrId);

      if (mounted) {
        setState(() {
          _replies = replies;
        });
        _checkCanEdit();
      }
    } catch (e) {
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
    final answered = _replies.isNotEmpty || _contact!.hasReply;

    setState(() {
      _canEditContact = owner && !answered;
      _canDeleteContact = owner;
    });
  }

  Future<void> _confirmAndDeleteContact() async {
    if (_contact == null || _canDeleteContact != true) return;

    final confirmed = await ConfirmDialog.show(
      context,
      title: '문의 삭제',
      message: '이 문의를 삭제하시겠습니까?',
      cancelText: '취소',
      confirmText: '삭제',
    );
    if (!confirmed || !mounted) return;

    try {
      final result = await ContactService.deleteContact(widget.wrId);
      if (!mounted) return;
      if (result['success'] == true) {
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']?.toString() ?? '삭제에 실패했습니다.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('삭제 중 오류가 발생했습니다: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _navigateToEdit() async {
    if (_contact == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactFormScreen(
          contact: _contact,
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

  Widget _buildQuestionCard() {
    final c = _contact!;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorderMuted, width: 1),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: const BoxDecoration(
                color: _kPink,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: _kPink,
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        'Q',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.wrSubject.isEmpty ? '(제목 없음)' : c.wrSubject,
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 16,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                            ),
                          ),
                          Text(
                            DateDisplayFormatter.formatYmdFromString(c.wrDatetime),
                            style: const TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontSize: 10,
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_canEditContact == true || _canDeleteContact == true)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_canEditContact == true) ...[
                      TextButton(
                        onPressed: _navigateToEdit,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF898383),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          '수정',
                          style: TextStyle(
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w300,
                            fontSize: 11,
                            color: Color(0xFF898383),
                          ),
                        ),
                      ),
                      const Text(
                        '|',
                        style: TextStyle(
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                          fontSize: 11,
                          color: Color(0xFF898383),
                        ),
                      ),
                    ],
                    if (_canDeleteContact == true)
                      TextButton(
                        onPressed: _confirmAndDeleteContact,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF898383),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          '삭제',
                          style: TextStyle(
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w300,
                            fontSize: 11,
                            color: Color(0xFF898383),
                          ),
                        ),
                      ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 15),
          _buildContactHtmlBody(c.wrContent),
        ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCardFor(Contact c) {
    final canEdit = (_canEditContact == true) && c.wrId == _contact?.wrId;
    final canDelete = (_canDeleteContact == true) && c.wrId == _contact?.wrId;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBorderMuted, width: 1),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: const BoxDecoration(
                color: _kPink,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: _kPink,
                              shape: BoxShape.circle,
                            ),
                            child: const Text(
                              'Q',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w700,
                                height: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  c.wrSubject.isEmpty ? '(제목 없음)' : c.wrSubject,
                                  style: const TextStyle(
                                    color: Color(0xFF1A1A1A),
                                    fontSize: 16,
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w700,
                                    height: 1.5,
                                  ),
                                ),
                                Text(
                                  DateDisplayFormatter.formatYmdFromString(c.wrDatetime),
                                  style: const TextStyle(
                                    color: Color(0xFF1A1A1A),
                                    fontSize: 10,
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w500,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canEdit || canDelete)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (canEdit) ...[
                            TextButton(
                              onPressed: _navigateToEdit,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF898383),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                '수정',
                                style: TextStyle(
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w300,
                                  fontSize: 11,
                                  color: Color(0xFF898383),
                                ),
                              ),
                            ),
                            const Text(
                              '|',
                              style: TextStyle(
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w300,
                                fontSize: 11,
                                color: Color(0xFF898383),
                              ),
                            ),
                          ],
                          if (canDelete)
                            TextButton(
                              onPressed: _confirmAndDeleteContact,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF898383),
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: const Text(
                                '삭제',
                                style: TextStyle(
                                  fontFamily: 'Gmarket Sans TTF',
                                  fontWeight: FontWeight.w300,
                                  fontSize: 11,
                                  color: Color(0xFF898383),
                                ),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 15),
                _buildContactHtmlBody(c.wrContent),
                if ((c.wrReply.trim().isNotEmpty || c.hasReply) && _primaryContactHtml(c).trim().isNotEmpty)
                  _buildAnswerCard(
                    Contact(
                      wrId: c.wrId,
                      wrSubject: c.wrSubject,
                      wrContent: _primaryContactHtml(c),
                      mbId: c.mbId,
                      wrName: '관리자',
                      wrEmail: c.wrEmail,
                      wrDatetime: c.wrLast.isNotEmpty ? c.wrLast : c.wrDatetime,
                      wrLast: c.wrLast,
                      wrComment: c.wrComment,
                      wrReply: c.wrReply,
                      wrParent: c.wrParent,
                      caName: c.caName,
                      wrHit: c.wrHit,
                      wrOption: c.wrOption,
                      wrIsComment: c.wrIsComment,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Contact> get _threadQuestions {
    if (_thread.isEmpty) return _contact != null ? [_contact!] : const [];
    final sorted = [..._thread]..sort((a, b) {
      final byDt = b.wrDatetime.compareTo(a.wrDatetime);
      if (byDt != 0) return byDt;
      return b.wrId.compareTo(a.wrId);
    });
    return sorted;
  }

  int get _followupCount {
    final root = _rootWrId;
    if (root == null) return 0;
    return _threadQuestions.where((c) => c.wrId != root).length;
  }

  Widget _buildAnswerCard(Contact reply) {
    final title = reply.wrSubject.trim().isEmpty ? '답변' : reply.wrSubject;
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.only(left: 24),
        decoration: const BoxDecoration(
          border: Border(
            left: BorderSide(width: 2, color: _kBorderMuted),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _kAnswerBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: _kPinkSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Text(
                          'A',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w700,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontSize: 14,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w700,
                                height: 1.43,
                              ),
                            ),
                            Text(
                              DateDisplayFormatter.formatYmdFromString(reply.wrDatetime),
                              style: const TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontSize: 10,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildContactHtmlBody(_primaryContactHtml(reply)),
                ],
              ),
            ),
            const Positioned(
              left: -33,
              top: -1,
              child: SizedBox(
                width: 16,
                height: 16,
                child: DecoratedBox(
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

  List<Widget> _buildAnswerBlocks() {
    if (_replies.isNotEmpty) {
      return _replies.map(_buildAnswerCard).toList();
    }
    final raw = _contact?.wrReply.trim() ?? '';
    if (raw.isNotEmpty) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.only(left: 24),
            decoration: const BoxDecoration(
              border: Border(
                left: BorderSide(width: 2, color: _kBorderMuted),
              ),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _kAnswerBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              color: _kPinkSoft,
                              shape: BoxShape.circle,
                            ),
                            child: const Text(
                              'A',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w700,
                                height: 1,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _contact!.wrSubject.isEmpty ? '답변' : _contact!.wrSubject,
                                  style: const TextStyle(
                                    color: Color(0xFF1A1A1A),
                                    fontSize: 14,
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w700,
                                    height: 1.43,
                                  ),
                                ),
                                Text(
                                  DateDisplayFormatter.formatYmdFromString(
                                    _contact!.wrLast.isNotEmpty
                                        ? _contact!.wrLast
                                        : _contact!.wrDatetime,
                                  ),
                                  style: const TextStyle(
                                    color: Color(0xFF1A1A1A),
                                    fontSize: 10,
                                    fontFamily: 'Gmarket Sans TTF',
                                    fontWeight: FontWeight.w500,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      _buildContactHtmlBody(raw),
                    ],
                  ),
                ),
                const Positioned(
                  left: -7,
                  top: -1,
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: DecoratedBox(
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
        ),
      ];
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: const HealthAppBar(title: '1:1 문의 상세'),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF3787)))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 27),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red, fontFamily: 'Gmarket Sans TTF'),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadContactDetail,
                          child: const Text('다시 시도'),
                        ),
                      ],
                    ),
                  ),
                )
              : _contact == null
                  ? const Center(child: Text('문의를 찾을 수 없습니다.'))
                  : ColoredBox(
                      color: Colors.white,
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(27, 20, 27, 20),
                              child: DefaultTextStyle.merge(
                                style: const TextStyle(
                                  fontFamily: 'Gmarket Sans TTF',
                                  color: Color(0xFF1A1A1A),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    ..._threadQuestions.map((c) => Padding(
                                          padding: const EdgeInsets.only(bottom: 16),
                                          child: _buildQuestionCardFor(c),
                                        )),
                                    ..._buildAnswerBlocks(),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(27, 0, 27, 20),
                            child: Row(
                              children: [
                                Expanded(
                                  child: SizedBox(
                                    height: 40,
                                    child: OutlinedButton(
                                      onPressed: () {
                                        final root = _rootWrId ?? widget.wrId;
                                        if (_followupCount >= 2) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('추가질문은 최대 2회까지 가능합니다.')),
                                          );
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
                                        side: const BorderSide(width: 0.5, color: Color(0xFFD2D2D2)),
                                        backgroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.all(10),
                                      ),
                                      child: const Text(
                                        '추가질문',
                                        style: TextStyle(
                                          color: Color(0xFF898686),
                                          fontSize: 16,
                                          fontFamily: 'Gmarket Sans TTF',
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: SizedBox(
                                    height: 40,
                                    child: FilledButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: _kPink,
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        padding: const EdgeInsets.all(10),
                                      ),
                                      child: const Text(
                                        '목록보기',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontFamily: 'Gmarket Sans TTF',
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
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
        style: const TextStyle(
          color: Color(0xFF1A1A1A),
          fontSize: 14,
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w300,
          height: 1.63,
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 48;
        return Html(
          data: processed,
          style: {
            'html': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
            'body': Style(
              margin: Margins.zero,
              padding: HtmlPaddings.zero,
              fontFamily: 'Gmarket Sans TTF',
              fontSize: FontSize(14),
              fontWeight: FontWeight.w300,
              lineHeight: const LineHeight(1.63),
              textAlign: TextAlign.start,
              color: const Color(0xFF1A1A1A),
            ),
            'p': Style(
              margin: Margins.only(bottom: 8),
              padding: HtmlPaddings.zero,
            ),
            'img': Style(
              width: Width(maxWidth),
              display: Display.block,
              margin: Margins.symmetric(vertical: 8),
            ),
            'div': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
            'span': Style(fontFamily: 'Gmarket Sans TTF'),
          },
        );
      },
    );
  }
}
