import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../core/utils/node_value_parser.dart';
import '../../../core/utils/price_formatter.dart';
import '../../../data/services/qa_service.dart';
import '../../common/widgets/app_toast_overlay.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../models/qa_inquiry_draft.dart';

/// �ű� 1:1 ���� �ۼ� (���� ȭ�鿡�� ���á��Է¡��߰����� �̾)
class QaInputScreen extends StatefulWidget {
  final QaInquiryDraft draft;

  const QaInputScreen({super.key, required this.draft});

  @override
  State<QaInputScreen> createState() => _QaInputScreenState();
}

class _QaInputScreenState extends State<QaInputScreen> {
  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _userBubble = Color(0xFFFFD6E4);
  static const Color _inputBarBg = Color(0xFFF8F9FA);
  static const Color _inputFieldBg = Color(0xFFE7E8E9);
  static const Color _hint = Color(0x66584045);
  static const Color _csBorder = Color(0x33E0BEC4);
  static const Color _csText = Color(0xFF191C1D);
  static const Color _datePill = Color(0x99E7E8E9);
  static const Color _ink = Color(0xFF1A1A1A);
  static const Color _muted = Color(0xFF898686);
  static const String _font = 'Gmarket Sans TTF';

  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();

  static const String _askPrompt = QaInquiryDraft.askPrompt;

  bool _sending = false;
  bool _closing = false;
  bool _threadClosed = false;
  String? _selectedTopic;
  int? _createdWrId;
  bool _hasTyped = false;
  /// CS�� ��� ���� �ñ��ϽŰ���?���� ���� �ں��� �Է� ����
  bool _inquiryPromptShown = false;
  DateTime? _promptShownAt;
  final List<String> _sentMessages = [];

  QaInquiryDraft get _draft => widget.draft;

  bool get _isEtc => _draft.category == '기타';

  bool get _needsTopic =>
      _draft.category == '주문' ||
      _draft.category == '상품' ||
      _draft.category == '기타';

  bool get _canType =>
      !_threadClosed &&
      (!_needsTopic || (_selectedTopic != null && _inquiryPromptShown));

  bool get _showCloseBadge =>
      !_threadClosed && (_hasTyped || _createdWrId != null);

  List<String> get _topics => QaInquiryDraft.topicsFor(_draft.category);

  String get _guideMessage => QaInquiryDraft.guideMessage(_draft.category);

  String _etcTopicGuide(String topic) => QaInquiryDraft.etcTopicGuide(topic);

  String get _caName {
    if (_selectedTopic == null || _selectedTopic!.isEmpty) {
      return _draft.category;
    }
    return '${_draft.category}|$_selectedTopic';
  }

  @override
  void initState() {
    super.initState();
    _inputController.addListener(_onInputChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _canType) _inputFocus.requestFocus();
    });
  }

  void _onInputChanged() {
    final typed = _inputController.text.trim().isNotEmpty;
    if (typed != _hasTyped && mounted) {
      setState(() => _hasTyped = typed);
    }
  }

  @override
  void dispose() {
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    _inputFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  int? _extractWrId(Map<String, dynamic> result) {
    final direct = NodeValueParser.asInt(result['wr_id']) ??
        NodeValueParser.asInt(result['wrId']);
    if (direct != null && direct > 0) return direct;

    final data = result['data'];
    if (data is Map) {
      final nested = NodeValueParser.asInt(data['wr_id']) ??
          NodeValueParser.asInt(data['wrId']);
      if (nested != null && nested > 0) return nested;
    }

    final contactMap = result['contact'];
    if (contactMap is Map) {
      final nested = NodeValueParser.asInt(contactMap['wr_id']) ??
          NodeValueParser.asInt(contactMap['wrId']);
      if (nested != null && nested > 0) return nested;
    }
    return null;
  }

  void _onSelectTopic(String topic) {
    if (_selectedTopic != null) return;
    final now = DateTime.now();
    setState(() {
      _selectedTopic = topic;
      // �ֹ�/��ǰ: Ĩ ���� CS ������Ʈ �� �Է� ����
      // ��Ÿ: 1�� �ȳ� + ������ ����ϱ⡹ �� ������Ʈ
      if (!_isEtc) {
        _inquiryPromptShown = true;
        _promptShownAt = now;
      }
    });
    _scrollToBottom();
    if (!_isEtc) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _canType) _inputFocus.requestFocus();
      });
    }
  }

  void _onContinueInquiry() {
    if (_inquiryPromptShown) return;
    final now = DateTime.now();
    setState(() {
      _inquiryPromptShown = true;
      _promptShownAt = now;
    });
    _scrollToBottom();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _canType) _inputFocus.requestFocus();
    });
  }

  String _formatAmPmTime(DateTime? dt) {
    if (dt == null) return '';
    final hour24 = dt.hour;
    final isAm = hour24 < 12;
    var hour12 = hour24 % 12;
    if (hour12 == 0) hour12 = 12;
    final mm = dt.minute.toString().padLeft(2, '0');
    return '${isAm ? '오전' : '오후'}\n$hour12:$mm';
  }

  Future<void> _send() async {
    if (_sending || !_canType) return;
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      final draft = _draft;
      final Map<String, dynamic> result;
      if (_createdWrId == null) {
        // ù ���� �� DB ���� (���� ȭ�� ����)
        result = await QaService.create(
          subject: draft.buildSubject(text),
          content: draft.buildContent(text),
          primaryType: _caName,
        );
      } else {
        // �߰� ����
        result = await QaService.create(
          subject: text.length > 40 ? '${text.substring(0, 40)}…' : text,
          content: text,
          parentWrId: _createdWrId,
        );
      }

      if (!mounted) return;
      if (result['success'] == true) {
        final wrId = _extractWrId(result) ?? _createdWrId;
        setState(() {
          if (_createdWrId == null && wrId != null) {
            _createdWrId = wrId;
          }
          _sentMessages.add(text);
          _inputController.clear();
          _hasTyped = false;
        });
        _scrollToBottom();
      } else {
        AppToastOverlay.show(
          context,
          result['message']?.toString() ?? '문의 전송에 실패했습니다.',
        );
      }
    } catch (_) {
      if (mounted) {
        AppToastOverlay.show(context, '문의 전송 중 오류가 발생했습니다.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _confirmAndClose() async {
    if (_closing || _threadClosed) return;

    // ���� DB ���� �� �� �׳� ������
    if (_createdWrId == null) {
      if (!mounted) return;
      Navigator.pop(context, false);
      return;
    }

    setState(() => _closing = true);
    try {
      final result = await QaService.close(_createdWrId!);
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() {
          _threadClosed = true;
          _hasTyped = false;
        });
        _inputFocus.unfocus();
        AppToastOverlay.show(context, '문의를 종료하였습니다');
      } else {
        AppToastOverlay.show(context, '문의 종료 중 오류가 발생했습니다.');
      }
    } catch (_) {
      if (mounted) {
        AppToastOverlay.show(context, '문의 종료 중 오류가 발생했습니다.');
      }
    } finally {
      if (mounted) setState(() => _closing = false);
    }
  }

  Future<void> _onWillPop() async {
    Navigator.pop(context, _createdWrId != null ? true : false);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onWillPop();
      },
      child: MobileAppLayoutWrapper(
        backgroundColor: Colors.white,
        resizeToAvoidBottomInset: true,
        appBar: const HealthAppBar(
          title: '1:1 문의',
          centerTitle: false,
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  healthDp(context, 16),
                  healthDp(context, 16),
                  healthDp(context, 16),
                  healthDp(context, 8),
                ),
                children: [
                  _buildDatePill(context),
                  SizedBox(height: healthDp(context, 12)),
                  if (_draft.hasTarget ||
                      _draft.category == '주문' ||
                      _draft.category == '상품')
                    _buildTargetCard(context),
                  if (_needsTopic) ...[
                    SizedBox(height: healthDp(context, 16)),
                    _buildCsGuide(context),
                    if (_selectedTopic != null) ...[
                      SizedBox(height: healthDp(context, 12)),
                      _buildUserBubble(
                        context,
                        _selectedTopic!,
                      ),
                      if (_isEtc) ...[
                        SizedBox(height: healthDp(context, 12)),
                        _buildCsMessage(
                          context,
                          text: _etcTopicGuide(_selectedTopic!),
                          footer: _inquiryPromptShown
                              ? null
                              : _buildContinueButton(context),
                        ),
                      ],
                      if (_inquiryPromptShown) ...[
                        SizedBox(height: healthDp(context, 12)),
                        _buildCsBubble(
                          context,
                          text: _askPrompt,
                          timeLabel: _formatAmPmTime(_promptShownAt),
                        ),
                      ],
                    ],
                  ],
                  for (final msg in _sentMessages) ...[
                    SizedBox(height: healthDp(context, 12)),
                    _buildUserBubble(context, msg),
                  ],
                  if (!_needsTopic &&
                      !_draft.hasTarget &&
                      _sentMessages.isEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: healthDp(context, 24)),
                      child: Text(
                        '문의하실 내용을 입력해주세요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _muted,
                          fontSize: healthSp(context, 14),
                          fontFamily: _font,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (_showCloseBadge) _buildCloseBadge(context),
            _buildInputBar(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePill(BuildContext context) {
    final label = DateDisplayFormatter.formatYmd(DateTime.now());
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

  Widget _buildCloseBadge(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: healthDp(context, 4)),
      child: Center(
        child: GestureDetector(
          onTap: _closing ? null : _confirmAndClose,
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

  Widget _buildTargetCard(BuildContext context) {
    final draft = _draft;
    final imageUrl = (draft.imageUrl ?? '').trim();
    final badgeLabel = draft.category == '주문'
        ? '주문문의'
        : (draft.category == '상품' ? '상품문의' : draft.category);

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
              child: imageUrl.isNotEmpty
                  ? Image.network(
                      ImageUrlHelper.getImageUrl(imageUrl),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.image_outlined),
                    )
                  : const Icon(Icons.image_outlined),
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
                if (draft.category == '주문' && (draft.odId ?? '').isNotEmpty)
                  Text(
                    '주문번호 ${draft.odId}',
                    style: TextStyle(
                      color: _muted,
                      fontSize: healthSp(context, 10),
                      fontFamily: _font,
                    ),
                  )
                else if (draft.brandName?.trim().isNotEmpty == true)
                  Text(
                    draft.brandName!.trim(),
                    style: TextStyle(
                      color: _muted,
                      fontSize: healthSp(context, 10),
                      fontFamily: _font,
                    ),
                  ),
                if ((draft.category == '주문' &&
                        (draft.odId ?? '').isNotEmpty) ||
                    draft.brandName?.trim().isNotEmpty == true)
                  SizedBox(height: healthDp(context, 2)),
                Text(
                  draft.productName?.trim().isNotEmpty == true
                      ? draft.productName!.trim()
                      : '선택 항목',
                  style: TextStyle(
                    color: _ink,
                    fontSize: healthSp(context, 10),
                    fontFamily: _font,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (draft.price != null) ...[
                  SizedBox(height: healthDp(context, 2)),
                  Text(
                    '${PriceFormatter.format(draft.price)}원',
                    style: TextStyle(
                      color: _ink,
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

  Widget _buildCsGuide(BuildContext context) {
    return _buildCsMessage(
      context,
      text: _guideMessage,
      footer: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: healthDp(context, 12)),
          Wrap(
            spacing: healthDp(context, 8),
            runSpacing: healthDp(context, 8),
            children: [
              for (final topic in _topics)
                _TopicChip(
                  label: topic,
                  selected: _selectedTopic == topic,
                  // ���� �� ���� ��Ȱ�� (���� �Ұ�, Ĩ�� ����)
                  enabled: _selectedTopic == null,
                  onTap: () => _onSelectTopic(topic),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCsBubble(
    BuildContext context, {
    required String text,
    String timeLabel = '',
  }) {
    return _buildCsMessage(context, text: text, timeLabel: timeLabel);
  }

  Widget _buildContinueButton(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: healthDp(context, 12)),
      child: GestureDetector(
        onTap: _onContinueInquiry,
        child: Container(
          width: double.infinity,
          height: healthDp(context, 40),
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: _pink,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(healthDp(context, 10)),
            ),
          ),
          child: Text(
            '문의 계속하기',
            style: TextStyle(
              color: Colors.white,
              fontSize: healthSp(context, 14),
              fontFamily: _font,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCsMessage(
    BuildContext context, {
    required String text,
    Widget? footer,
    String timeLabel = '',
  }) {
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              text,
                              style: TextStyle(
                                color: _csText,
                                fontSize: healthSp(context, 12),
                                fontFamily: _font,
                                fontWeight: FontWeight.w500,
                                height: 1.5,
                              ),
                            ),
                            if (footer != null) footer,
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (timeLabel.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(
                        left: healthDp(context, 6),
                        bottom: healthDp(context, 2),
                      ),
                      child: Text(
                        timeLabel.replaceAll('\n', ' '),
                        style: TextStyle(
                          color: _muted,
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

  Widget _buildUserBubble(
    BuildContext context,
    String text, {
    String timeLabel = '',
  }) {
    final r = healthDp(context, 16);
    final tail = healthDp(context, 8);

    return Align(
      alignment: Alignment.centerRight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (timeLabel.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(right: healthDp(context, 6)),
              child: Text(
                timeLabel,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: _muted,
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
      ),
    );
  }

  Widget _buildInputBar(BuildContext context) {
    final locked = !_canType;
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
          ignoring: locked,
          child: Opacity(
            opacity: locked ? 0.75 : 1,
            child: GestureDetector(
              onTap: locked ? null : () => _inputFocus.requestFocus(),
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
                        enabled: !locked,
                        readOnly: locked,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.send,
                        minLines: 1,
                        maxLines: 5,
                        enableInteractiveSelection: !locked,
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
                          hintText: locked
                              ? (_threadClosed
                                  ? '종료된 문의입니다. 추가 질문은 불가합니다.'
                                  : '현재는 텍스트를 입력할 수 없어요.')
                              : '문의하실 내용을 입력해주세요',
                          hintStyle: TextStyle(
                            color: _hint,
                            fontSize: healthSp(context, locked ? 13 : 15),
                            fontFamily: _font,
                            fontWeight: FontWeight.w500,
                            height: 1.25,
                          ),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: healthDp(context, 12),
                            vertical: healthDp(context, 8),
                          ),
                        ),
                        onSubmitted: locked ? null : (_) => _send(),
                      ),
                    ),
                    SizedBox(width: healthDp(context, 8)),
                    GestureDetector(
                      onTap: (locked || _sending) ? null : _send,
                      child: Container(
                        width: healthDp(context, 32),
                        height: healthDp(context, 32),
                        decoration: ShapeDecoration(
                          color: locked
                              ? _pink.withValues(alpha: 0.4)
                              : _pink,
                          shape: const CircleBorder(),
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

class _TopicChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _TopicChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _border = Color(0xFFD2D2D2);
  static const String _font = 'Gmarket Sans TTF';

  @override
  Widget build(BuildContext context) {
    final active = selected;
    final dimmed = !enabled && !selected;
    return Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(healthDp(context, 999)),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: healthDp(context, 12),
              vertical: healthDp(context, 8),
            ),
            decoration: BoxDecoration(
              color: active ? const Color(0x14FF5A8D) : Colors.white,
              borderRadius: BorderRadius.circular(healthDp(context, 999)),
              border: Border.all(
                color: active ? _pink : _border,
                width: active ? 1.5 : 1,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                color: active ? _pink : const Color(0xFF1A1A1A),
                fontSize: healthSp(context, 12),
                fontFamily: _font,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
