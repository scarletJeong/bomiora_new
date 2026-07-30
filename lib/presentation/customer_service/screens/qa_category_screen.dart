import 'package:flutter/material.dart';

import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../models/qa_inquiry_draft.dart';
import 'qa_input_screen.dart';
import 'qa_item_select_screen.dart';

/// 1:1 문의 — 카테고리 선택 (주문 / 상품 / 기타)
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
  String? _majorCategory;

  bool get _canNext {
    if (_selected == null) return false;
    if (_selected == '기타') return true;
    return _majorCategory != null && _majorCategory!.isNotEmpty;
  }

  void _onSelectCategory(String category) {
    setState(() {
      if (_selected == category) {
        _selected = null;
        _majorCategory = null;
        return;
      }
      _selected = category;
      if (category == '기타') {
        _majorCategory = null;
      }
    });
  }

  Future<void> _onNext() async {
    final selected = _selected;
    if (selected == null || !_canNext) return;

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
          majorCategory: _majorCategory!,
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
                  title: '주문',
                  description: '주문 관련 문의를 남겨주세요',
                  selected: _selected == '주문',
                  onTap: () => _onSelectCategory('주문'),
                ),
                if (_selected == '주문') ...[
                  SizedBox(height: healthDp(context, 10)),
                  _MajorCategoryPanel(
                    selected: _majorCategory,
                    onSelected: (v) => setState(() => _majorCategory = v),
                  ),
                ],
                SizedBox(height: healthDp(context, 12)),
                _CategoryCard(
                  title: '상품',
                  description: '상품 관련 문의를 남겨주세요',
                  selected: _selected == '상품',
                  onTap: () => _onSelectCategory('상품'),
                ),
                if (_selected == '상품') ...[
                  SizedBox(height: healthDp(context, 10)),
                  _MajorCategoryPanel(
                    selected: _majorCategory,
                    onSelected: (v) => setState(() => _majorCategory = v),
                  ),
                ],
                SizedBox(height: healthDp(context, 12)),
                _CategoryCard(
                  title: '기타',
                  description: '운영 관련 문의를 남겨주세요',
                  selected: _selected == '기타',
                  onTap: () => _onSelectCategory('기타'),
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
                onTap: _canNext ? _onNext : null,
                child: Container(
                  width: double.infinity,
                  height: healthDp(context, 40),
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: _canNext ? _pink : _pink.withValues(alpha: 0.4),
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

class _MajorCategoryPanel extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelected;

  const _MajorCategoryPanel({
    required this.selected,
    required this.onSelected,
  });

  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _ink = Color(0xFF1A1A1A);
  static const Color _muted = Color(0xFF898686);
  static const Color _border = Color(0x7FD2D2D2);
  static const String _font = 'Gmarket Sans TTF';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 12)),
      decoration: ShapeDecoration(
        color: const Color(0xFFFAFAFA),
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _border),
          borderRadius: BorderRadius.circular(healthDp(context, 12)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '문의유형을 선택해주세요',
            style: TextStyle(
              color: _muted,
              fontSize: healthSp(context, 12),
              fontFamily: _font,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: healthDp(context, 10)),
          for (final major in QaInquiryDraft.majorCategories) ...[
            InkWell(
              onTap: () => onSelected(major),
              borderRadius: BorderRadius.circular(healthDp(context, 8)),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                  horizontal: healthDp(context, 12),
                  vertical: healthDp(context, 10),
                ),
                decoration: ShapeDecoration(
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      width: healthDp(
                        context,
                        selected == major ? 1.5 : 1,
                      ),
                      color: selected == major ? _pink : _border,
                    ),
                    borderRadius: BorderRadius.circular(healthDp(context, 8)),
                  ),
                ),
                child: Text(
                  major,
                  style: TextStyle(
                    color: selected == major ? _pink : _ink,
                    fontSize: healthSp(context, 13),
                    fontFamily: _font,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            if (major != QaInquiryDraft.majorCategories.last)
              SizedBox(height: healthDp(context, 8)),
          ],
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryCard({
    required this.title,
    required this.description,
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
                width: healthDp(context, selected ? 1.5 : 1),
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
            ],
          ),
        ),
      ),
    );
  }
}
