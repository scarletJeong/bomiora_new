import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../health/health_common/health_responsive_scale.dart';

TextStyle _tailSectionTitleStyle(BuildContext context) => TextStyle(
      color: const Color(0xFF1A1A1E),
      fontSize: healthSp(context, 16),
      fontFamily: 'Gmarket Sans TTF',
      fontWeight: FontWeight.w300,
      letterSpacing: healthSp(context, -1.44),
    );

TextStyle _tailBodyStyle(BuildContext context) => TextStyle(
      fontSize: healthSp(context, 12),
      color: Colors.black87,
      height: 1.55,
      letterSpacing: healthSp(context, -0.84),
    );

TextStyle _tailH2Style(BuildContext context) => TextStyle(
      fontSize: healthSp(context, 12),
      fontWeight: FontWeight.w500,
      color: Colors.black87,
      height: 1.35,
      letterSpacing: -0.2,
    );

TextStyle _tailPStyle(BuildContext context) => TextStyle(
      fontSize: healthSp(context, 12),
      fontWeight: FontWeight.w300,
      color: const Color(0xFF444444),
      height: 1.6,
      letterSpacing: healthSp(context, -0.84),
    );

const double _kTailSectionContentIndent = 10;

double _tailHorizontalPad(BuildContext context) => healthDp(context, 27);

Widget _tailSectionDivider(BuildContext context) => Divider(
      height: healthDp(context, 1),
      thickness: healthDp(context, 1),
      color: Colors.grey.shade300,
    );

/// 접이식 섹션 제목 앞 세로 구분 표시 (`| 배송` 형태)
Widget _expandableSectionTitle(BuildContext context, String title) {
  final style = _tailSectionTitleStyle(context);
  return Row(
    children: [
      Text('|', style: style),
      SizedBox(width: healthDp(context, 10)),
      Flexible(
        child: Text(
          title,
          style: style,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

Widget _tailExpandableSectionShell({
  required BuildContext context,
  required bool isExpanded,
  required VoidCallback onToggle,
  required Widget title,
  required Widget expandedChild,
  bool showTrailingDivider = true,
}) {
  final gap = healthDp(context, 10);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      InkWell(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        onTap: onToggle,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: gap),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: title),
              Icon(
                isExpanded ? Icons.expand_less : Icons.expand_more,
                color: Colors.grey[600],
              ),
            ],
          ),
        ),
      ),
      AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        child: isExpanded ? expandedChild : const SizedBox.shrink(),
      ),
      if (isExpanded) SizedBox(height: gap),
      if (showTrailingDivider) _tailSectionDivider(context),
    ],
  );
}

/// 제품 상세페이지 공통 정보 섹션 (배송, 처방 프로세스, 교환/환불)
class ProductTailInfoSection extends StatelessWidget {
  final bool initialExpanded;
  final bool showCertification;
  final bool showWarning;
  final bool showPrescriptionProcess;
  final String? warningText;
  final String? deliveryText;
  final String? prescriptionProcessText;
  final String? changeContentText;

  const ProductTailInfoSection({
    super.key,
    this.initialExpanded = false,
    this.showCertification = true,
    this.showWarning = true,
    this.showPrescriptionProcess = true,
    this.warningText,
    this.deliveryText,
    this.prescriptionProcessText,
    this.changeContentText,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _tailHorizontalPad(context)),
      child: Column(
        children: [
          _buildDeliverySection(),
          if (showCertification) _buildCertificationSection(),
          if (showWarning) _buildWarningSection(context),
          if (showPrescriptionProcess) _buildPrescriptionProcessSection(),
          _buildExchangeRefundSection(),
        ],
      ),
    );
  }

  /// 배송 정보 섹션
  Widget _buildDeliverySection() {
    return _DeliverySection(
      initialExpanded: initialExpanded,
      deliveryText: deliveryText,
    );
  }

  /// 처방 프로세스 섹션
  Widget _buildPrescriptionProcessSection() {
    return _PrescriptionProcessSection(
      initialExpanded: initialExpanded,
      processText: prescriptionProcessText,
    );
  }

  /// 기관인증 섹션
  Widget _buildCertificationSection() {
    return _CertificationSection(initialExpanded: initialExpanded);
  }

  /// 주의사항 섹션
  Widget _buildWarningSection(BuildContext context) {
    return _SimpleExpandableSection(
      title: '주의사항',
      rows: [
        _SimpleInfoRow(
          label: '',
          value: warningText ?? '',
        ),
      ],
      initialExpanded: initialExpanded,
      customBodyBuilder: () => _buildNoticeList(
        context,
        warningText,
        pipeAsNewlineFallback: false,
        fontWeight: FontWeight.w300,
      ),
    );
  }

  /// 교환/환불 섹션
  Widget _buildExchangeRefundSection() {
    return _ExchangeRefundSection(
      initialExpanded: initialExpanded,
      changeContentText: changeContentText,
    );
  }

  /// 프로세스 단계 위젯
  Widget _buildProcessStep(
    BuildContext context,
    String step,
    String title,
    String description,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$step ',
                style: TextStyle(
                  fontSize: healthSp(context, 12),
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              TextSpan(
                text: title,
                style: TextStyle(
                  fontSize: healthSp(context, 12),
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: TextStyle(
            fontSize: healthSp(context, 12),
            color: Colors.grey[700],
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// 배송 섹션을 위한 StatefulWidget
class _DeliverySection extends StatefulWidget {
  final bool initialExpanded;
  final String? deliveryText;

  const _DeliverySection({
    this.initialExpanded = false,
    this.deliveryText,
  });

  @override
  State<_DeliverySection> createState() => _DeliverySectionState();
}

class _DeliverySectionState extends State<_DeliverySection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return _tailExpandableSectionShell(
      context: context,
      isExpanded: _isExpanded,
      onToggle: () => setState(() => _isExpanded = !_isExpanded),
      title: _expandableSectionTitle(context, '배송'),
      expandedChild: _buildNoticeList(
        context,
        widget.deliveryText,
        pipeAsNewlineFallback: true,
        fontWeight: FontWeight.w300,
      ),
    );
  }
}

class _SimpleInfoRow {
  final String label;
  final String value;

  const _SimpleInfoRow({required this.label, required this.value});
}

String _normalizeCmsText(
  String? raw, {
  bool pipeAsNewline = true,
}) {
  if (raw == null) return '';
  var s = raw.trim();
  if (s.isEmpty) return '';

  // 1) 먼저 "줄바꿈/문단" 의미를 갖는 태그를 개행으로 치환
  s = s
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n\n')
      .replaceAll(RegExp(r'</div\s*>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</li\s*>', caseSensitive: false), '\n');

  // 2) 리스트 아이템은 앞에 점을 붙여 가독성 유지
  s = s.replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ');

  // 3) HTML 제거 및 구분자 정리
  s = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('|', pipeAsNewline ? '\n' : ' | ')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll(RegExp(r'\r\n?'), '\n');

  // 4) 라인 단위 트림 + 과도한 공백/개행 정리
  final lines = s
      .split('\n')
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      // 빈 불릿/구분자 라인 제거 (교환/환불에서 자주 발생)
      .where((e) => e != '•' && e != '·' && e != '-' && e != '—')
      .toList();
  s = lines.join('\n');
  s = s.replaceAll(RegExp(r'[ \t]+\n'), '\n');
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

  return s;
}

class _NoticeBlock {
  final String title;
  final List<String> paragraphs;

  const _NoticeBlock({
    required this.title,
    required this.paragraphs,
  });
}

String _stripTags(String input) {
  return input
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll('&nbsp;', ' ')
      .replaceAll(RegExp(r'<[^>]+>'), '')
      .replaceAll(RegExp(r'\r\n?'), '\n')
      .trim();
}

List<_NoticeBlock> _parseNoticeHtml(String? raw) {
  if (raw == null) return const [];
  final html = raw.trim();
  if (html.isEmpty) return const [];

  final liMatches =
      RegExp(r'<li[^>]*>([\s\S]*?)</li>', caseSensitive: false)
          .allMatches(html)
          .toList();
  if (liMatches.isEmpty) return const [];

  final blocks = <_NoticeBlock>[];
  for (final m in liMatches) {
    final li = m.group(1) ?? '';
    final h2 =
        RegExp(r'<h2[^>]*>([\s\S]*?)</h2>', caseSensitive: false).firstMatch(li);
    final title = _stripTags(h2?.group(1) ?? '').replaceAll('\n', ' ').trim();

    final pMatches =
        RegExp(r'<p[^>]*>([\s\S]*?)</p>', caseSensitive: false)
            .allMatches(li)
            .toList();
    final paragraphs = pMatches
        .map((pm) => _stripTags(pm.group(1) ?? ''))
        .map((t) => t.replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((t) => t.isNotEmpty)
        .toList();

    if (title.isEmpty && paragraphs.isEmpty) continue;
    blocks.add(_NoticeBlock(title: title, paragraphs: paragraphs));
  }
  return blocks;
}

Widget _buildNoticeList(
  BuildContext context,
  String? raw, {
  bool pipeAsNewlineFallback = true,
  FontWeight? fontWeight,
}) {
  final bodyStyle = fontWeight != null
      ? _tailBodyStyle(context).copyWith(fontWeight: fontWeight)
      : _tailBodyStyle(context);
  final h2Style = fontWeight != null
      ? _tailH2Style(context).copyWith(fontWeight: fontWeight)
      : _tailH2Style(context);
  final pStyle = fontWeight != null
      ? _tailPStyle(context).copyWith(fontWeight: fontWeight)
      : _tailPStyle(context);

  final blocks = _parseNoticeHtml(raw);
  if (blocks.isEmpty) {
    final text = _normalizeCmsText(raw, pipeAsNewline: pipeAsNewlineFallback);
    return Padding(
      padding: const EdgeInsets.only(left: _kTailSectionContentIndent),
      child: Text(
        text.isEmpty ? '-' : text,
        textAlign: TextAlign.start,
        style: bodyStyle,
      ),
    );
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final b in blocks) ...[
        if (b.title.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: _kTailSectionContentIndent),
            child: Text(
              b.title.trim(),
              style: h2Style,
            ),
          ),
        if (b.paragraphs.isNotEmpty) const SizedBox(height: 6),
        for (final p in b.paragraphs) ...[
          Padding(
            padding: const EdgeInsets.only(left: _kTailSectionContentIndent),
            child: Text(
              p,
              style: pStyle,
            ),
          ),
          const SizedBox(height: 6),
        ],
        const SizedBox(height: 14),
      ],
    ],
  );
}

/// 기관인증 섹션 (아이콘 1장 표시)
class _CertificationSection extends StatefulWidget {
  final bool initialExpanded;

  const _CertificationSection({this.initialExpanded = false});

  @override
  State<_CertificationSection> createState() => _CertificationSectionState();
}

class _CertificationSectionState extends State<_CertificationSection> {
  late bool _isExpanded;
  Future<Uint8List?>? _embeddedPngFuture;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
  }

  Future<Uint8List?> _loadEmbeddedPngFromSvgAsset() async {
    final svg = await rootBundle.loadString(AppAssets.productDetailCertification);
    final match = RegExp(r'data:image/png;base64,([A-Za-z0-9+/=]+)')
        .firstMatch(svg);
    if (match == null) return null;
    final b64 = match.group(1);
    if (b64 == null || b64.isEmpty) return null;
    return base64Decode(b64);
  }

  @override
  Widget build(BuildContext context) {
    return _tailExpandableSectionShell(
      context: context,
      isExpanded: _isExpanded,
      onToggle: () => setState(() => _isExpanded = !_isExpanded),
      title: _expandableSectionTitle(context, '기관인증'),
      expandedChild: ClipRRect(
        borderRadius: BorderRadius.circular(healthDp(context, 8)),
        child: ColoredBox(
          color: Colors.white,
          child: Padding(
            padding: EdgeInsets.only(left: healthDp(context, _kTailSectionContentIndent)),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth.isFinite
                    ? constraints.maxWidth
                    : MediaQuery.sizeOf(context).width -
                        _tailHorizontalPad(context) * 2;
                final targetW = (w * 0.20).clamp(70.0, 160.0);
                final h = (targetW * 0.55).clamp(35.0, 80.0);

                _embeddedPngFuture ??= _loadEmbeddedPngFromSvgAsset();

                return Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: targetW,
                    height: h,
                    child: FutureBuilder<Uint8List?>(
                      future: _embeddedPngFuture,
                      builder: (context, snapshot) {
                        final bytes = snapshot.data;
                        if (bytes != null && bytes.isNotEmpty) {
                          return Image.memory(
                            bytes,
                            fit: BoxFit.contain,
                          );
                        }
                        return SvgPicture.asset(
                          AppAssets.productDetailCertification,
                          fit: BoxFit.contain,
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SimpleExpandableSection extends StatefulWidget {
  final bool initialExpanded;
  final String title;
  final List<_SimpleInfoRow> rows;
  final Widget Function()? customBodyBuilder;

  const _SimpleExpandableSection({
    required this.title,
    required this.rows,
    this.initialExpanded = false,
    this.customBodyBuilder,
  });

  @override
  State<_SimpleExpandableSection> createState() =>
      _SimpleExpandableSectionState();
}

class _SimpleExpandableSectionState extends State<_SimpleExpandableSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return _tailExpandableSectionShell(
      context: context,
      isExpanded: _isExpanded,
      onToggle: () => setState(() => _isExpanded = !_isExpanded),
      title: _expandableSectionTitle(context, widget.title),
      expandedChild: widget.customBodyBuilder?.call() ??
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: widget.rows
                .map((row) => Padding(
                      padding: EdgeInsets.only(bottom: healthDp(context, 10)),
                      child: _buildInfoRow(row.label, row.value),
                    ))
                .toList(),
          ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    if (label.trim().isEmpty) {
      return Text(
        value,
        textAlign: TextAlign.start,
        style: _tailBodyStyle(context),
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: healthSp(context, 13),
              color: Colors.grey[600],
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: healthSp(context, 13),
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// 처방 프로세스 섹션을 위한 StatefulWidget
class _PrescriptionProcessSection extends StatefulWidget {
  final bool initialExpanded;
  final String? processText;

  const _PrescriptionProcessSection({
    this.initialExpanded = false,
    this.processText,
  });

  @override
  State<_PrescriptionProcessSection> createState() =>
      _PrescriptionProcessSectionState();
}

class _PrescriptionProcessSectionState
    extends State<_PrescriptionProcessSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return _tailExpandableSectionShell(
      context: context,
      isExpanded: _isExpanded,
      onToggle: () => setState(() => _isExpanded = !_isExpanded),
      title: _expandableSectionTitle(context, '처방 프로세스'),
      expandedChild: _buildNoticeList(context, widget.processText),
    );
  }
}

/// 교환/환불 섹션을 위한 StatefulWidget
class _ExchangeRefundSection extends StatefulWidget {
  final bool initialExpanded;
  final String? changeContentText;

  const _ExchangeRefundSection({
    this.initialExpanded = false,
    this.changeContentText,
  });

  @override
  State<_ExchangeRefundSection> createState() => _ExchangeRefundSectionState();
}

class _ExchangeRefundSectionState extends State<_ExchangeRefundSection> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initialExpanded;
  }

  @override
  Widget build(BuildContext context) {
    return _tailExpandableSectionShell(
      context: context,
      isExpanded: _isExpanded,
      onToggle: () => setState(() => _isExpanded = !_isExpanded),
      title: _expandableSectionTitle(context, '교환/환불'),
      expandedChild: _buildNoticeList(context, widget.changeContentText),
      showTrailingDivider: false,
    );
  }
}
