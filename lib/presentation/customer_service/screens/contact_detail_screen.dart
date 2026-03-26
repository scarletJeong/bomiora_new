import 'package:flutter/material.dart';
import '../../../data/models/contact/contact_model.dart';
import '../../../data/services/contact_service.dart';
import '../../../data/services/auth_service.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/app_bar.dart';
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
  List<Contact> _replies = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool? _canEditContact;

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
      final contact = await ContactService.getContactDetail(widget.wrId);
      if (contact != null) {
        setState(() {
          _contact = contact;
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
        });
      }
      return;
    }

    if (_replies.isNotEmpty || _contact!.hasReply) {
      if (mounted) {
        setState(() {
          _canEditContact = false;
        });
      }
      return;
    }

    final user = await AuthService.getUser();
    if (user == null) {
      if (mounted) {
        setState(() {
          _canEditContact = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _canEditContact = user.id == _contact!.mbId;
      });
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

  String _formatDateShort(String datetime) {
    try {
      final date = DateTime.parse(datetime);
      return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return datetime;
    }
  }

  Widget _buildQuestionCard() {
    final c = _contact!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: _kPink, width: 4),
          top: BorderSide(color: Color(0x7FD2D2D2), width: 1),
          right: BorderSide(color: Color(0x7FD2D2D2), width: 1),
          bottom: BorderSide(color: Color(0x7FD2D2D2), width: 1),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0AB41D56),
            blurRadius: 32,
            offset: Offset(0, 12),
            spreadRadius: 0,
          ),
        ],
      ),
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
                            _formatDateShort(c.wrDatetime),
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
              if (_canEditContact == true)
                TextButton(
                  onPressed: _navigateToEdit,
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF3787),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    '수정',
                    style: TextStyle(
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            c.getPlainTextContent(),
            style: const TextStyle(
              color: Color(0xFF1A1A1A),
              fontSize: 14,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
              height: 1.63,
            ),
          ),
        ],
      ),
    );
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
                              _formatDateShort(reply.wrDatetime),
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
                  Text(
                    reply.getPlainTextContent(),
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 14,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                      height: 1.63,
                    ),
                  ),
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
                                  _formatDateShort(_contact!.wrLast.isNotEmpty ? _contact!.wrLast : _contact!.wrDatetime),
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
                      Text(
                        _stripToPlainText(raw),
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 14,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                          height: 1.63,
                        ),
                      ),
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
                                    _buildQuestionCard(),
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
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const ContactFormScreen(),
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

  static String _stripToPlainText(String s) {
    return s
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&')
        .trim();
  }
}
