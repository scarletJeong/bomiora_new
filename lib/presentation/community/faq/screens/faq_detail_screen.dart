import 'package:flutter/material.dart';

import '../../../../core/utils/date_formatter.dart';
import '../../../../data/models/faq/faq_model.dart';
import '../../../../data/services/faq_service.dart';
import '../../../common/widgets/app_bar.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';

class FaqDetailScreen extends StatefulWidget {
  final int faqId;

  const FaqDetailScreen({
    super.key,
    required this.faqId,
  });

  @override
  State<FaqDetailScreen> createState() => _FaqDetailScreenState();
}

class _FaqDetailScreenState extends State<FaqDetailScreen> {
  static const Color _kText = Color(0xFF1A1A1A);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kBorder = Color(0x7FD2D2D2);

  bool _loading = true;
  String? _error;
  FaqModel? _item;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await FaqService.getFaqDetail(widget.faqId);
    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _item = result['item'] as FaqModel?;
      });
    } else {
      setState(() {
        _error = result['message']?.toString() ?? 'FAQ를 불러오지 못했습니다.';
      });
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: const HealthAppBar(
        title: 'FAQ',
        centerTitle: true,
      ),
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Gmarket Sans TTF',
                      color: _kMuted,
                    ),
                  ),
                )
              : _item == null
                  ? const Center(
                      child: Text(
                        'FAQ를 찾을 수 없습니다.',
                        style: TextStyle(
                          fontSize: 14,
                          fontFamily: 'Gmarket Sans TTF',
                          color: _kMuted,
                        ),
                      ),
                    )
                  : _buildContent(_item!),
    );
  }

  Widget _buildContent(FaqModel item) {
    final createdDate = item.createdAt == null
        ? '-'
        : DateDisplayFormatter.formatYmd(item.createdAt!);

    return ListView(
      padding: const EdgeInsets.fromLTRB(27, 20, 27, 20),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: ShapeDecoration(
                color: const Color(0xFFFF5B8C),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                item.category,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Text(
              '등록일: $createdDate',
              style: const TextStyle(
                color: _kMuted,
                fontSize: 12,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              '조회: ${item.viewCount}',
              style: const TextStyle(
                color: _kMuted,
                fontSize: 12,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 0.5, color: _kBorder),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            item.question,
            style: const TextStyle(
              color: _kText,
              fontSize: 16,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
              letterSpacing: -1.2,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: ShapeDecoration(
            color: const Color(0xFFFDF8FA),
            shape: RoundedRectangleBorder(
              side: const BorderSide(width: 0.5, color: _kBorder),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            item.answer,
            style: const TextStyle(
              color: _kText,
              fontSize: 14,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w400,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}
