import 'package:flutter/material.dart';

import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../models/qa_inquiry_draft.dart';
import 'qa_input_screen.dart';
import 'qa_item_select_screen.dart';

/// 1:1 문의 — 카테고리 선택 (상품 / 주문 / 기타)
class QaCategoryScreen extends StatefulWidget {
  const QaCategoryScreen({super.key});

  @override
  State<QaCategoryScreen> createState() => _QaCategoryScreenState();
}

class _QaCategoryScreenState extends State<QaCategoryScreen> {
  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _ink = Color(0xFF1A1A1A);
  static const String _font = 'Gmarket Sans TTF';

  String? _selected;

  Future<void> _onNext() async {
    final selected = _selected;
    if (selected == null) return;

    if (selected == '기타') {
      final result = await Navigator.push<Object>(
        context,
        MaterialPageRoute(
          builder: (_) => const QaInputScreen(
            draft: QaInquiryDraft(category: '기타'),
          ),
        ),
      );
      if (mounted && result != null) Navigator.pop(context, result);
      return;
    }

    final result = await Navigator.push<Object>(
      context,
      MaterialPageRoute(
        builder: (_) => QaItemSelectScreen(
          mode: selected == '상품'
              ? QaItemSelectMode.product
              : QaItemSelectMode.order,
        ),
      ),
    );
    if (mounted && result != null) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.white,
      appBar: const HealthAppBar(
        title: '문의하기',
        centerTitle: false,
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                healthDp(context, 27),
                healthDp(context, 0),
                healthDp(context, 27),
                healthDp(context, 5),
              ),
              children: [
                Text(
                  '어떤 점이 궁금하신가요?',
                  style: TextStyle(
                    color: _ink,
                    fontSize: healthSp(context, 16),
                    fontFamily: _font,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: healthDp(context, 20)),
                _CategoryCard(
                  title: '상품',
                  description: '상품 관련 문의를 남겨주세요',
                  examples: const [
                    '배송 기간이 궁금해요',
                    '옵션/구성이 궁금해요',
                  ],
                  selected: _selected == '상품',
                  onTap: () => setState(() => _selected = '상품'),
                ),
                SizedBox(height: healthDp(context, 12)),
                _CategoryCard(
                  title: '주문',
                  description: '주문 관련 문의를 남겨주세요',
                  examples: const [
                    '배송 상태를 확인하고 싶어요',
                    '교환/반품이 필요해요',
                  ],
                  selected: _selected == '주문',
                  onTap: () => setState(() => _selected = '주문'),
                ),
                SizedBox(height: healthDp(context, 12)),
                _CategoryCard(
                  title: '기타',
                  description: '운영 관련 문의를 남겨주세요',
                  examples: const [],
                  selected: _selected == '기타',
                  onTap: () => setState(() => _selected = '기타'),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                healthDp(context, 27),
                healthDp(context, 0),
                healthDp(context, 27),
                healthDp(context, 5),
              ),
              child: GestureDetector(
                onTap: _selected == null ? null : _onNext,
                child: Container(
                  width: double.infinity,
                  height: healthDp(context, 40),
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: _selected == null
                        ? _pink.withValues(alpha: 0.4)
                        : _pink,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 10)),
                    ),
                  ),
                  child: Text(
                    '다음',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: healthSp(context, 16),
                      fontFamily: _font,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final String description;
  final List<String> examples;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.description,
    required this.examples,
    required this.selected,
    required this.onTap,
  });

  static const Color _ink = Color(0xFF1A1A1A);
  static const Color _muted = Color(0xFF898686);
  static const Color _border = Color(0x7FD2D2D2);
  static const Color _pink = Color(0xFFFF5A8D);
  static const String _font = 'Gmarket Sans TTF';

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(healthDp(context, 12)),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(healthDp(context, 16)),
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: selected ? 1.5 : 1,
                color: selected ? _pink : _border,
              ),
              borderRadius: BorderRadius.circular(healthDp(context, 12)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: selected ? _pink : _ink,
                  fontSize: healthSp(context, 16),
                  fontFamily: _font,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: healthDp(context, 6)),
              Text(
                description,
                style: TextStyle(
                  color: _muted,
                  fontSize: healthSp(context, 10),
                  fontFamily: _font,
                  fontWeight: FontWeight.w400,
                  height: 1.4,
                ),
              ),
              if (examples.isNotEmpty) ...[
                SizedBox(height: healthDp(context, 12)),
                for (final example in examples)
                  Padding(
                    padding: EdgeInsets.only(bottom: healthDp(context, 6)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: healthDp(context, 6),
                            vertical: healthDp(context, 2),
                          ),
                          decoration: ShapeDecoration(
                            shape: RoundedRectangleBorder(
                              side: const BorderSide(
                                width: 1,
                                color: _border,
                              ),
                              borderRadius:
                                  BorderRadius.circular(healthDp(context, 4)),
                            ),
                          ),
                          child: Text(
                            '예시',
                            style: TextStyle(
                              color: _muted,
                              fontSize: healthSp(context, 8),
                              fontFamily: _font,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                            ),
                          ),
                        ),
                        SizedBox(width: healthDp(context, 8)),
                        Expanded(
                          child: Text(
                            example,
                            style: TextStyle(
                              color: _muted,
                              fontSize: healthSp(context, 10),
                              fontFamily: _font,
                              fontWeight: FontWeight.w400,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
