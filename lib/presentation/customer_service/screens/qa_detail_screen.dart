import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/qa/qa_inquiry_model.dart';
import '../../../data/repositories/product/product_repository.dart';
import '../../../data/services/qa_service.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../widgets/qa_detail_product_card.dart';

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
  static const String _font = 'Gmarket Sans TTF';

  QaInquiry? _inquiry;
  List<QaInquiry> _thread = [];
  int? _rootWrId;
  final Map<int, List<QaInquiry>> _repliesByWrId = {};
  bool _isLoading = true;
  String? _errorMessage;
  String? _resolvedImageUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final payload = await QaService.getDetail(widget.wrId);
      if (payload != null) {
        setState(() {
          _inquiry = payload.inquiry;
          _thread = payload.thread;
          _rootWrId = payload.rootWrId;
          _resolvedImageUrl = null;
          _isLoading = false;
        });
        await _resolveProductCardExtras();
        await _loadReplies();
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

  List<QaInquiry> get _allQuestions {
    final byId = <int, QaInquiry>{};
    for (final c in [..._thread, if (_inquiry != null) _inquiry!]) {
      if (c.wrId > 0) byId[c.wrId] = c;
    }
    return byId.values.toList()
      ..sort((a, b) {
        final byDt = a.wrDatetime.compareTo(b.wrDatetime);
        if (byDt != 0) return byDt;
        return a.wrId.compareTo(b.wrId);
      });
  }

  QaInquiry? get _rootQuestion {
    final rootId = _rootWrId ?? widget.wrId;
    for (final q in _allQuestions) {
      if (q.wrId == rootId) return q;
    }
    return _inquiry ??
        (_allQuestions.isNotEmpty ? _allQuestions.first : null);
  }

  Future<void> _resolveProductCardExtras() async {
    final root = _rootQuestion;
    if (root == null) return;
    final category = root.inquiryCategoryLabel;
    if (category != '상품' && category != '주문') return;
    final needImage = (root.subjectImageUrl ?? '').trim().isEmpty;
    if (!needImage) return;
    final itId = (root.subjectProductCode ?? '').trim();
    if (itId.isEmpty) return;
    try {
      final product = await ProductRepository.getProductDetail(itId);
      if (!mounted || product == null) return;
      final image = (product.imageUrl ?? '').trim();
      if (image.isEmpty) return;
      setState(() => _resolvedImageUrl = image);
    } catch (_) {}
  }

  Future<void> _loadReplies() async {
    final targets =
        _allQuestions.map((q) => q.wrId).where((id) => id > 0).toList();
    if (targets.isEmpty) return;
    try {
      final results = await Future.wait(targets.map(QaService.getReplies));
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
    } catch (_) {}
  }

  bool _isAnswered(QaInquiry q) {
    if (q.hasReply) return true;
    final list = _repliesByWrId[q.wrId] ?? const <QaInquiry>[];
    return list.isNotEmpty || q.wrReply.trim().isNotEmpty;
  }

  String _answerTextFor(QaInquiry q) {
    final list = _repliesByWrId[q.wrId] ?? const <QaInquiry>[];
    if (list.isNotEmpty) return list.first.getPlainTextContent();
    return _stripHtml(q.wrReply);
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

  List<String> _inquiryPhotoUrls(QaInquiry q) {
    final html = q.wrContent;
    return RegExp(r'''<img[^>]+src=["']([^"']+)["']''', caseSensitive: false)
        .allMatches(html)
        .map((m) => m.group(1)!.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Widget _qaPhotoThumb(BuildContext context, String url) {
    final w = healthDp(context, 76);
    final h = healthDp(context, 76);
    final broken = Container(
      width: w,
      height: h,
      color: const Color(0xFFF1F1F1),
      alignment: Alignment.center,
      child: Icon(
        Icons.broken_image_outlined,
        size: healthDp(context, 22),
        color: const Color(0xFFBDBDBD),
      ),
    );

    if (url.startsWith('data:image/')) {
      try {
        final b64 = url.split(',').length > 1 ? url.split(',').last : '';
        final bytes = base64Decode(b64);
        return Image.memory(
          bytes,
          width: w,
          height: h,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => broken,
        );
      } catch (_) {
        return broken;
      }
    }

    return Image.network(
      ImageUrlHelper.getImageUrl(url),
      width: w,
      height: h,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => broken,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.white,
      appBar: HealthAppBar(
        title: '문의내역',
        titleFontSize: healthSp(context, 17),
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

    final root = _rootQuestion;
    if (root == null) {
      return const Center(child: Text('문의 내용이 없습니다.'));
    }
    final answered = _isAnswered(root);
    final photos = _inquiryPhotoUrls(root);
    final dateTime = _formatInquiryDateTime(root.wrDatetime);

    return ListView(
      padding: EdgeInsets.fromLTRB(
        healthDp(context, 20),
        healthDp(context, 16),
        healthDp(context, 20),
        healthDp(context, 32),
      ),
      children: [
        QaDetailProductCard(
          inquiry: root,
          fallbackImageUrl: _resolvedImageUrl,
        ),
        SizedBox(height: healthDp(context, 12)),
        _buildTextSection(
          context,
          title: '문의내용',
          body: root.displayQuestionText,
          trailing: dateTime,
          photos: photos,
        ),
        if (answered) ...[
          SizedBox(height: healthDp(context, 20)),
          _buildTextSection(
            context,
            title: '답변내용',
            body: _answerTextFor(root),
          ),
        ],
      ],
    );
  }

  String _formatInquiryDateTime(String raw) {
    final formatted = DateDisplayFormatter.formatDotDateTimeKorea(raw);
    if (formatted.isEmpty || formatted == '-') return '';
    return formatted;
  }

  Widget _buildTextSection(
    BuildContext context, {
    required String title,
    required String body,
    String? trailing,
    List<String> photos = const [],
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: healthDp(context, 3),
              height: healthDp(context, 14),
              decoration: ShapeDecoration(
                color: _pink,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(healthDp(context, 99)),
                ),
              ),
            ),
            SizedBox(width: healthDp(context, 8)),
            Text(
              title,
              style: TextStyle(
                color: const Color(0xFF1B1B1B),
                fontSize: healthSp(context, 15),
                fontFamily: _font,
                fontWeight: FontWeight.w300,
                height: 1.5,
              ),
            ),
            if ((trailing ?? '').isNotEmpty) ...[
              SizedBox(width: healthDp(context, 8)),
              Text(
                trailing!,
                style: TextStyle(
                  color: const Color(0xFF9C9C9C),
                  fontSize: healthSp(context, 10),
                  fontFamily: _font,
                  fontWeight: FontWeight.w300,
                  height: 1.5,
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: healthDp(context, 10)),
        Container(
          width: double.infinity,
          constraints: BoxConstraints(minHeight: healthDp(context, 120)),
          padding: EdgeInsets.all(healthDp(context, 14)),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: healthDp(context, 1),
                color: const Color(0xFFE0E0E0),
              ),
              borderRadius: BorderRadius.circular(healthDp(context, 8)),
            ),
          ),
          child: Text(
            body.isEmpty ? '' : body,
            style: TextStyle(
              color: const Color(0xFF1B1B1B),
              fontSize: healthSp(context, 13),
              fontFamily: _font,
              fontWeight: FontWeight.w300,
              height: 1.62,
            ),
          ),
        ),
        if (photos.isNotEmpty) ...[
          SizedBox(height: healthDp(context, 12)),
          Wrap(
            spacing: healthDp(context, 8),
            runSpacing: healthDp(context, 8),
            children: [
              for (final url in photos)
                ClipRRect(
                  borderRadius: BorderRadius.circular(healthDp(context, 8)),
                  child: _qaPhotoThumb(context, url),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
