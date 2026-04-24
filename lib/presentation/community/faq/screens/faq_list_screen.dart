import 'package:flutter/material.dart';

import '../../../../data/models/faq/faq_model.dart';
import '../../../../data/services/category_service.dart';
import '../../../../data/services/faq_service.dart';
import '../../../common/widgets/app_bar.dart';
import '../../../common/widgets/dropdown_btn.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';

class FaqListScreen extends StatefulWidget {
  const FaqListScreen({super.key});

  @override
  State<FaqListScreen> createState() => _FaqListScreenState();
}

class _FaqListScreenState extends State<FaqListScreen> {
  static const Color _kText = Color(0xFF1A1A1A);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kPink = Color(0xFFFF5B8C);
  static const Color _kBorder = Color(0xFFD2D2D2);

  final TextEditingController _searchController = TextEditingController();
  final int _size = 20;

  bool _loading = false;
  String? _error;
  List<FaqModel> _items = const [];
  List<String> _categories = const ['전체'];
  Set<int> _expandedIds = <int>{};
  String _selectedTabCategory = '전체';
  String _selectedDropdownCategory = '전체';
  String _query = '';
  int _page = 1;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({int? page, String? query, String? category}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final targetPage = page ?? _page;
    final targetQuery = query ?? _query;
    final targetCategory = category ?? _selectedTabCategory;

    final resultList = await Future.wait([
      FaqService.getFaqList(
        page: targetPage,
        size: _size,
        query: targetQuery,
        category: '전체',
      ),
      CategoryService.getCategoriesByGroup('faq'),
    ]);
    final result = resultList[0] as Map<String, dynamic>;
    final categoryResult = resultList[1] as Map<String, dynamic>;

    if (!mounted) return;
    if (result['success'] == true) {
      setState(() {
        _items = (result['items'] as List<FaqModel>?) ?? [];
        final fetchedCategories =
            (categoryResult['categories'] as List<String>?) ?? const <String>[];
        _categories = ['전체', ...fetchedCategories];
        if (!_categories.contains(targetCategory)) {
          _selectedTabCategory = '전체';
        }
        _total = (result['total'] as num?)?.toInt() ?? 0;
        _page = (result['page'] as num?)?.toInt() ?? targetPage;
        _query = targetQuery;
        _selectedTabCategory =
            _categories.contains(targetCategory) ? targetCategory : '전체';
        if (!_categories.contains(_selectedDropdownCategory)) {
          _selectedDropdownCategory = '전체';
        }
        _expandedIds = <int>{};
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
        centerTitle: false,
      ),
      child: RefreshIndicator(
        onRefresh: () => _load(page: 1),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(27, 16, 27, 20),
          children: [
            _buildCategoryChips(),
            const SizedBox(height: 12),
            _buildSearchBar(),
            const SizedBox(height: 12),
            Text(
              '총 ${_visibleItems.length}건',
              style: const TextStyle(
                color: _kMuted,
                fontSize: 12,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              _buildError()
            else if (_items.isEmpty)
              _buildEmpty()
            else
              ..._visibleItems.map(_buildFaqCard),
          ],
        ),
      ),
    );
  }

  List<FaqModel> get _visibleItems {
    return _items.where((item) {
      final tabOk = _selectedTabCategory == '전체' ||
          item.category == _selectedTabCategory;
      final dropdownOk = _selectedDropdownCategory == '전체' ||
          item.category == _selectedDropdownCategory;
      return tabOk && dropdownOk;
    }).toList();
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 34,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 5),
        itemBuilder: (context, index) {
          final category = _categories[index];
          final selected = category == _selectedTabCategory;
          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _load(page: 1, category: category),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: ShapeDecoration(
                color: selected ? _kPink : null,
                shape: RoundedRectangleBorder(
                  side: BorderSide.none,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                category,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : _kMuted,
                  fontSize: 12,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                  height: 1.67,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchBar() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          flex: 5,
          child: DropdownBtn(
            items: _categories,
            value: _selectedDropdownCategory,
            onChanged: (value) {
              setState(() {
                _selectedDropdownCategory = value;
              });
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: Container(
            height: 36,
            padding: const EdgeInsets.only(left: 10, right: 4),
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                side: const BorderSide(width: 1, color: _kBorder),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) =>
                        _load(page: 1, query: _searchController.text.trim()),
                    style: const TextStyle(
                      fontSize: 14,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w400,
                      color: _kText,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      hintText: '검색',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: _kMuted,
                        fontSize: 14,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(Icons.search, size: 16, color: _kMuted),
                  onPressed: () =>
                      _load(page: 1, query: _searchController.text.trim()),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFaqCard(FaqModel item) {
    final expanded = _expandedIds.contains(item.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 0.5, color: _kBorder),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              setState(() {
                if (expanded) {
                  _expandedIds.remove(item.id);
                } else {
                  _expandedIds.add(item.id);
                }
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
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
                  const SizedBox(width: 6),
                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: _kMuted,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, thickness: 0.5, color: _kBorder),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(color: Colors.white),
              child: Text(
                _normalizeHtmlToText(item.answer),
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
        ],
      ),
    );
  }

  String _normalizeHtmlToText(String raw) {
    var text = raw;
    text = text.replaceAll(r'\n', '\n');
    text = text.replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'</p\s*>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<p[^>]*>', caseSensitive: false), '');
    text = text.replaceAll('&nbsp;', ' ');
    text = text.replaceAll('&amp;', '&');
    text = text.replaceAll('&lt;', '<');
    text = text.replaceAll('&gt;', '>');
    text = text.replaceAll('&quot;', '"');
    text = text.replaceAll('&#39;', "'");
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    return text
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'\s+'), ' ').trim())
        .join('\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 50),
      child: Center(
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: _kMuted,
            fontSize: 14,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 50),
      child: Center(
        child: Text(
          '조건에 맞는 FAQ가 없습니다.',
          style: TextStyle(
            color: _kMuted,
            fontSize: 14,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
