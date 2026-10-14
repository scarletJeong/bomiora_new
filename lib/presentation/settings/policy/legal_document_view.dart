import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../health/health_common/health_responsive_scale.dart';

/// `legal/` 마크다운을 제목·본문·목록으로 표시합니다.
class LegalDocumentView extends StatefulWidget {
  final String assetPath;
  final EdgeInsetsGeometry? padding;

  const LegalDocumentView({
    super.key,
    required this.assetPath,
    this.padding,
  });

  @override
  State<LegalDocumentView> createState() => _LegalDocumentViewState();
}

class _LegalDocumentViewState extends State<LegalDocumentView> {
  static const String _font = 'Gmarket Sans TTF';
  String? _markdown;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final text = await rootBundle.loadString(widget.assetPath);
      if (!mounted) return;
      setState(() => _markdown = text);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = widget.padding ?? EdgeInsets.all(healthDp(context, 20));

    if (_failed) {
      final iconSz = healthDp(context, 40);
      return Padding(
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              AppAssets.emptyNoticeIcon,
              width: iconSz,
              height: iconSz,
              fit: BoxFit.contain,
            ),
            SizedBox(height: healthDp(context, 8)),
            Text(
              '등록된 약관이 없습니다.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0x665B3F43),
                fontSize: healthSp(context, 12),
                fontFamily: _font,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    if (_markdown == null) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFFF5A8D)),
      );
    }

    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _blocks(context, _markdown!),
      ),
    );
  }

  List<Widget> _blocks(BuildContext context, String markdown) {
    final lines = markdown.replaceAll('\r\n', '\n').split('\n');
    final widgets = <Widget>[];
    final gap = healthDp(context, 8);

    for (final raw in lines) {
      final line = raw.trimRight();
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        widgets.add(SizedBox(height: gap));
        continue;
      }
      if (trimmed == '---') {
        widgets.add(Padding(
          padding: EdgeInsets.symmetric(vertical: gap),
          child: Container(
            width: double.infinity,
            height: 1,
            color: const Color(0xFFE6E6E6),
          ),
        ));
        continue;
      }

      if (trimmed.startsWith('### ')) {
        widgets.add(_heading(context, trimmed.substring(4), 13));
      } else if (trimmed.startsWith('## ')) {
        widgets.add(_heading(context, trimmed.substring(3), 15));
      } else if (trimmed.startsWith('# ')) {
        widgets.add(_heading(context, trimmed.substring(2), 18));
      } else if (trimmed.startsWith('> ')) {
        widgets.add(_quote(context, trimmed.substring(2)));
      } else if (trimmed.startsWith('- ')) {
        widgets.add(_bullet(context, trimmed.substring(2)));
      } else {
        widgets.add(_paragraph(context, trimmed));
      }
      widgets.add(SizedBox(height: healthDp(context, 4)));
    }
    return widgets;
  }

  Widget _heading(BuildContext context, String text, double size) {
    return Padding(
      padding: EdgeInsets.only(top: healthDp(context, 8)),
      child: Text.rich(
        _spans(text, FontWeight.w500),
        style: TextStyle(
          fontFamily: _font,
          fontSize: healthSp(context, size),
          fontWeight: FontWeight.w500,
          color: Colors.black,
          height: 1.45,
        ),
      ),
    );
  }

  Widget _paragraph(BuildContext context, String text) {
    return Text.rich(
      _spans(text, FontWeight.w300),
      style: TextStyle(
        fontFamily: _font,
        fontSize: healthSp(context, 13),
        fontWeight: FontWeight.w300,
        color: Colors.black87,
        height: 1.6,
      ),
    );
  }

  Widget _bullet(BuildContext context, String text) {
    return Padding(
      padding: EdgeInsets.only(left: healthDp(context, 8)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '·  ',
            style: TextStyle(
              fontFamily: _font,
              fontSize: healthSp(context, 13),
              color: Colors.black87,
              height: 1.6,
            ),
          ),
          Expanded(child: _paragraph(context, text)),
        ],
      ),
    );
  }

  Widget _quote(BuildContext context, String text) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(left: healthDp(context, 10)),
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Color(0xFFFF5A8D), width: 2),
        ),
      ),
      child: _paragraph(context, text),
    );
  }

  TextSpan _spans(String text, FontWeight baseWeight) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    var start = 0;
    for (final match in pattern.allMatches(text)) {
      if (match.start > start) {
        spans.add(TextSpan(text: text.substring(start, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: const TextStyle(fontWeight: FontWeight.w500),
      ));
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }
    if (spans.isEmpty) spans.add(TextSpan(text: text));
    return TextSpan(
      style: TextStyle(fontWeight: baseWeight),
      children: spans,
    );
  }
}
