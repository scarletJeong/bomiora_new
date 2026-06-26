import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../data/models/faq/faq_model.dart';
import '../../../../data/services/category_service.dart';
import '../../../../data/services/faq_service.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import '../../../common/widgets/dropdown_btn.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/centered_empty_state.dart';
import '../../../health/health_common/health_responsive_scale.dart';

class FaqListScreen extends StatefulWidget {
  const FaqListScreen({super.key});

  @override
  State<FaqListScreen> createState() => _FaqListScreenState();
}

class _FaqListScreenState extends State<FaqListScreen> {
  static const Color _kText = Color(0xFF1A1A1E);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kPink = Color(0xFFFF5B8C);
  static const Color _kCountPink = Color(0xFFFF5A8D);
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
          padding: EdgeInsets.fromLTRB(
            healthDp(context, 27),
            healthDp(context, 20),
            healthDp(context, 27),
            healthDp(context, 20),
          ),
          children: [
            _buildCategoryChips(),
            SizedBox(height: healthDp(context, 10)),
            _buildSearchBar(),
            SizedBox(height: healthDp(context, 10)),
            _buildTotalRow(),
            SizedBox(height: healthDp(context, 14)),
            if (_loading)
              Padding(
                padding: EdgeInsets.symmetric(vertical: healthDp(context, 60)),
                child: const Center(child: CircularProgressIndicator()),
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
      height: healthDp(context, 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            for (var index = 0; index < _categories.length; index++) ...[
              if (index > 0) SizedBox(width: healthDp(context, 5)),
              Builder(
                builder: (context) {
                  final category = _categories[index];
                  final selected = category == _selectedTabCategory;
                  return InkWell(
                    borderRadius: BorderRadius.circular(healthDp(context, 20)),
                    onTap: () => _load(page: 1, category: category),
                    child: Container(
                      height: healthDp(context, 24),
                      padding: EdgeInsets.symmetric(
                        horizontal: healthDp(context, 10),
                        vertical: healthDp(context, 2),
                      ),
                      alignment: Alignment.center,
                      decoration: ShapeDecoration(
                        color: selected ? _kPink : null,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(healthDp(context, 20)),
                        ),
                      ),
                      child: Text(
                        category,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected ? Colors.white : _kMuted,
                          fontSize: healthSp(context, 14),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                          height: 1.43,
                        ),
                        textHeightBehavior: const TextHeightBehavior(
                          applyHeightToFirstAscent: false,
                          applyHeightToLastDescent: false,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTotalRow() {
    final count = _visibleItems.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: healthDp(context, 1), color: _kBorder),
        SizedBox(height: healthDp(context, 5)),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '총 ',
                style: TextStyle(
                  color: _kMuted,
                  fontSize: healthSp(context, 12),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextSpan(
                text: '$count',
                style: TextStyle(
                  color: _kCountPink,
                  fontSize: healthSp(context, 12),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: '건',
                style: TextStyle(
                  color: _kMuted,
                  fontSize: healthSp(context, 12),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: healthDp(context, 5)),
        Container(height: healthDp(context, 1), color: _kBorder),
      ],
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
        SizedBox(width: healthDp(context, 8)),
        Expanded(
          flex: 5,
          child: Container(
            height: healthDp(context, 36),
            padding: EdgeInsets.only(
              left: healthDp(context, 10),
              right: healthDp(context, 4),
            ),
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  width: healthDp(context, 1),
                  color: _kBorder,
                ),
                borderRadius: BorderRadius.circular(healthDp(context, 10)),
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
                    style: TextStyle(
                      fontSize: healthSp(context, 14),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w400,
                      color: _kText,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '검색',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: _kMuted,
                        fontSize: healthSp(context, 14),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                      ),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () =>
                      _load(page: 1, query: _searchController.text.trim()),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.all(healthDp(context, 6)),
                    child: SvgPicture.asset(
                      AppAssets.searchIcon,
                      width: healthDp(context, 18),
                      height: healthDp(context, 18),
                      fit: BoxFit.contain,
                    ),
                  ),
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
      margin: EdgeInsets.only(bottom: healthDp(context, 14)),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 0.5),
            color: _kBorder,
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
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
              padding: EdgeInsets.symmetric(
                horizontal: healthDp(context, 12),
                vertical: healthDp(context, 14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      item.question,
                      style: TextStyle(
                        color: _kText,
                        fontSize: healthSp(context, 14),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                        letterSpacing: healthSp(context, -1.26),
                      ),
                    ),
                  ),
                  SizedBox(width: healthDp(context, 6)),
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
            Divider(
              height: healthDp(context, 1),
              thickness: healthDp(context, 0.5),
              color: _kBorder,
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(healthDp(context, 12)),
              decoration: const BoxDecoration(color: Colors.white),
              child: Text(
                _normalizeHtmlToText(item.answer),
                style: TextStyle(
                  color: _kText,
                  fontSize: healthSp(context, 12),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w300,
                  height: 1.67,
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
      padding: EdgeInsets.symmetric(vertical: healthDp(context, 50)),
      child: Center(
        child: Text(
          _error!,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _kMuted,
            fontSize: healthSp(context, 14),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: healthDp(context, 40)),
      child: const CenteredEmptyState(
        icon: Icons.help_outline,
        message: '조건에 맞는 FAQ가 없습니다.',
      ),
    );
  }
}
