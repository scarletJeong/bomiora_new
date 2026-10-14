import 'dart:convert';

import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/qa/qa_inquiry_model.dart';
import '../../../data/repositories/product/product_repository.dart';
import '../../../data/services/qa_service.dart';
import '../../common/widgets/centered_empty_state.dart';
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
        final replyMap = <int, List<QaInquiry>>{};
        if (payload.repliesIncluded) {
          replyMap[payload.inquiry.wrId] = payload.nestedReplies;
        }
        setState(() {
          _inquiry = payload.inquiry;
          _thread = payload.thread;
          _rootWrId = payload.rootWrId;
          _resolvedImageUrl = null;
          _repliesByWrId
            ..clear()
            ..addAll(replyMap);
          _isLoading = false;
        });
        _resolveProductCardExtras();
        if (!payload.repliesIncluded) {
          _loadReplies();
        }
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

  String _answerDateFor(QaInquiry q) {
    final list = _repliesByWrId[q.wrId] ?? const <QaInquiry>[];
    if (list.isNotEmpty) return _formatInquiryDateTime(list.first.wrDatetime);
    return '';
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
    final seen = <String>{};
    final urls = <String>[];

    void add(String raw) {
      final url = raw.trim();
      if (url.isEmpty || !seen.add(url)) return;
      urls.add(url);
    }

    for (final url in q.imageUrls) {
      add(url);
    }

    var html = q.wrContent;
    if (html.contains('&lt;') || html.contains('&quot;')) {
      html = html
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'")
          .replaceAll('&amp;', '&');
    }
    for (final match in RegExp(
      r'''<img[^>]+src\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    ).allMatches(html)) {
      add(match.group(1) ?? '');
    }
    return urls;
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
        title: '1:1 문의',
        leadingIconSize: healthDp(context, 16),
      ),
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: _pink));
    }
    if (_errorMessage != null || _rootQuestion == null) {
      return CenteredEmptyState(
        iconWidget: CenteredEmptyState.assetIcon(
          context,
          AppAssets.emptyQAIcon,
        ),
        message: '문의 내용이 없습니다.',
      );
    }

    final root = _rootQuestion!;
    final answered = _isAnswered(root);
    final photos = _inquiryPhotoUrls(root);
    final dateTime = _formatInquiryDateTime(root.wrDatetime);

    final headline = root.inquiryDetailLabel.trim();

    return ListView(
      padding: EdgeInsets.all(healthDp(context, 20)),
      children: [
        QaDetailProductCard(
          inquiry: root,
          fallbackImageUrl: _resolvedImageUrl,
        ),
        SizedBox(height: healthDp(context, 24)),
        _buildTextSection(
          context,
          title: '문의 내용',
          headline: headline,
          body: root.displayQuestionText,
          trailing: dateTime,
          photos: photos,
        ),
        SizedBox(height: healthDp(context, 24)),
        if (answered)
          _buildTextSection(
            context,
            title: '답변 내용',
            body: _answerTextFor(root),
            trailing: _answerDateFor(root),
          )
        else
          _buildPendingAnswer(context),
      ],
    );
  }

  String _formatInquiryDateTime(String raw) {
    final formatted = DateDisplayFormatter.formatDotDateTimeKorea(raw);
    if (formatted.isEmpty || formatted == '-') return '';
    return formatted;
  }

  Widget _sectionTitle(
    BuildContext context, {
    required String title,
    String? trailing,
  }) {
    return Row(
      children: [
        Container(
          width: healthDp(context, 2),
          height: healthDp(context, 14),
          decoration: ShapeDecoration(
            color: _pink,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(healthDp(context, 10)),
            ),
          ),
        ),
        SizedBox(width: healthDp(context, 6)),
        Text(
          title,
          style: TextStyle(
            color: Colors.black,
            fontSize: healthSp(context, 14),
            fontFamily: _font,
            fontWeight: FontWeight.w500,
          ),
        ),
        if ((trailing ?? '').isNotEmpty) ...[
          SizedBox(width: healthDp(context, 4)),
          Text(
            trailing!,
            style: TextStyle(
              color: const Color(0xFF898686),
              fontSize: healthSp(context, 10),
              fontFamily: _font,
              fontWeight: FontWeight.w300,
            ),
          ),
        ],
      ],
    );
  }

  ShapeDecoration _boxDecoration(BuildContext context) {
    return ShapeDecoration(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          width: healthDp(context, 1),
          color: const Color(0x7FD2D2D2),
        ),
        borderRadius: BorderRadius.circular(healthDp(context, 7)),
      ),
    );
  }

  TextStyle _bodyStyle(BuildContext context) {
    return TextStyle(
      color: const Color(0xFF1A1A1E),
      fontSize: healthSp(context, 12),
      fontFamily: _font,
      fontWeight: FontWeight.w500,
      height: 1.67,
      letterSpacing: healthSp(context, -0.60),
    );
  }

  Widget _buildTextSection(
    BuildContext context, {
    required String title,
    required String body,
    String? headline,
    String? trailing,
    List<String> photos = const [],
  }) {
    final line = (headline ?? '').trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, title: title, trailing: trailing),
        SizedBox(height: healthDp(context, 8)),
        if (line.isNotEmpty) ...[
          Container(
            width: double.infinity,
            height: healthDp(context, 40),
            padding: EdgeInsets.symmetric(
              horizontal: healthDp(context, 14),
              vertical: healthDp(context, 10),
            ),
            alignment: Alignment.centerLeft,
            decoration: _boxDecoration(context),
            child: Opacity(
              opacity: 0.86,
              child: Text(
                line,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: const Color(0xFF1A1A1E),
                  fontSize: healthSp(context, 12),
                  fontFamily: _font,
                  fontWeight: FontWeight.w500,
                  letterSpacing: healthSp(context, -1.08),
                ),
              ),
            ),
          ),
          SizedBox(height: healthDp(context, 8)),
        ],
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 14),
            vertical: healthDp(context, 10),
          ),
          decoration: _boxDecoration(context),
          child: Text(
            body.isEmpty ? '' : body,
            style: _bodyStyle(context),
          ),
        ),
        if (photos.isNotEmpty) ...[
          SizedBox(height: healthDp(context, 8)),
          Wrap(
            spacing: healthDp(context, 8),
            runSpacing: healthDp(context, 8),
            children: [
              for (final url in photos)
                ClipRRect(
                  borderRadius: BorderRadius.circular(healthDp(context, 10)),
                  child: _qaPhotoThumb(context, url),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildPendingAnswer(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(context, title: '답변 내용'),
        SizedBox(height: healthDp(context, 8)),
        Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 14),
            vertical: healthDp(context, 10),
          ),
          decoration: _boxDecoration(context),
          child: Column(
            children: [
              Icon(
                Icons.access_time,
                size: healthDp(context, 20),
                color: const Color(0xFFE9E9E9),
              ),
              SizedBox(height: healthDp(context, 8)),
              Text(
                '답변 준비 중입니다.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF898986),
                  fontSize: healthSp(context, 12),
                  fontFamily: _font,
                  fontWeight: FontWeight.w500,
                  height: 1.67,
                  letterSpacing: healthSp(context, -0.60),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
