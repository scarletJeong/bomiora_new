import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/product/product_model.dart';
import '../../../data/services/content_service.dart';
import '../../../data/services/search_service.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import 'widgets/search_product_card.dart';
import '../../health/health_common/health_responsive_scale.dart';

/// 통합 검색 결과 (비대면 진료 / 스토어 / 콘텐츠 탭).
class SearchListScreen extends StatefulWidget {
  const SearchListScreen({
    super.key,
    required this.initialQuery,
  });

  final String initialQuery;

  @override
  State<SearchListScreen> createState() => _SearchListScreenState();
}

class _SearchListScreenState extends State<SearchListScreen> {
  static const Color _ink = Color(0xFF1A1A1A);
  static const Color _muted = Color(0xFF898686);
  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _border = Color(0xFFD2D2D2);

  late final TextEditingController _queryController;
  Timer? _debounce;

  List<Product> _rx = const [];
  List<Product> _store = const [];
  List<Map<String, dynamic>> _content = const [];
  bool _loading = true;
  bool _initialLoad = true;
  String? _error;

  int _tab = 0; // 0: 비대면 진료, 1: 스토어, 2: 콘텐츠

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery.trim());
    _queryController.addListener(_onQueryChanged);
    _runSearch(_queryController.text);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _queryController.removeListener(_onQueryChanged);
    _queryController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _runSearch(_queryController.text);
    });
  }

  void _selectBestTab() {
    if (_rx.isNotEmpty) {
      _tab = 0;
    } else if (_store.isNotEmpty) {
      _tab = 1;
    } else if (_content.isNotEmpty) {
      _tab = 2;
    } else {
      _tab = 0;
    }
  }

  Future<void> _runSearch(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) {
      setState(() {
        _rx = const [];
        _store = const [];
        _content = const [];
        _loading = false;
        _initialLoad = false;
        _error = null;
        _tab = 0;
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (!mounted) return;
      final result = await SearchService.searchAll(q);
      if (!mounted) return;
      setState(() {
        _rx = result.prescriptionProducts;
        _store = result.storeProducts;
        _content = result.contents;
        _loading = false;
        _initialLoad = false;
        _selectBestTab();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _initialLoad = false;
        _error = e.toString();
      });
    }
  }

  int get _total => _rx.length + _store.length + _content.length;

  int get _tabResultCount {
    switch (_tab) {
      case 0:
        return _rx.length;
      case 1:
        return _store.length;
      case 2:
        return _content.length;
      default:
        return 0;
    }
  }

  void _openProduct(Product p, {required bool general}) {
    final route = general ? '/product-general/${p.id}' : '/product/${p.id}';
    Navigator.pushNamed(context, route);
  }

  void _openContent(Map<String, dynamic> item) {
    final idRaw = item['id'];
    final id = idRaw is num ? idRaw.toInt() : int.tryParse('$idRaw');
    if (id == null) return;
    final cat = (item['category'] ?? '').toString().trim();
    Navigator.pushNamed(
      context,
      '/content/detail',
      arguments: {
        'id': id,
        if (cat.isNotEmpty) 'category': cat,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      appBar: const HealthAppBar(title: '검색', centerTitle: false),
      child: _initialLoad && _loading
          ? const Center(child: CircularProgressIndicator(color: _pink))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(healthDp(context, 24)),
                    child: Text(
                      '검색 중 오류가 발생했습니다.\n$_error',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: healthSp(context, 14),
                        color: _muted,
                        fontFamily: 'Gmarket Sans TTF',
                      ),
                    ),
                  ),
                )
              : _buildResults(),
    );
  }

  Widget _buildResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            healthDp(context, 27),
            healthDp(context, 20),
            healthDp(context, 27),
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearchBar(),
              SizedBox(height: healthDp(context, 20)),
              _buildTabRow(),
              SizedBox(height: healthDp(context, 10)),
              _buildResultCountRow(),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: _pink))
              : _total == 0
                  ? _buildGlobalEmpty()
                  : Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: healthDp(context, 27)),
                      child: IndexedStack(
                        index: _tab,
                        children: [
                          _buildProductGrid(_rx, general: false),
                          _buildProductGrid(_store, general: true),
                          _buildContentList(),
                        ],
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildResultCountRow() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(height: healthDp(context, 1), color: _border),
        SizedBox(height: healthDp(context, 5)),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '검색 결과 ',
                style: TextStyle(
                  color: _muted,
                  fontSize: healthSp(context, 12),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextSpan(
                text: '$_tabResultCount',
                style: TextStyle(
                  color: _pink,
                  fontSize: healthSp(context, 12),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                ),
              ),
              TextSpan(
                text: '개',
                style: TextStyle(
                  color: _muted,
                  fontSize: healthSp(context, 12),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: healthDp(context, 5)),
        Container(height: healthDp(context, 1), color: _border),
      ],
    );
  }

  Widget _buildGlobalEmpty() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        healthDp(context, 27),
        healthDp(context, 20),
        healthDp(context, 27),
        healthDp(context, 20),
      ),
      child: Column(
        children: [
          SvgPicture.asset(
            AppAssets.searchEmptyIcon,
            width: healthDp(context, 80),
            height: healthDp(context, 80),
            fit: BoxFit.contain,
          ),
          SizedBox(height: healthDp(context, 10)),
          Text(
            '검색 결과가 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ink,
              fontSize: healthSp(context, 16),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            '검색어를 다시 입력해주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: healthSp(context, 14),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: healthDp(context, 36),
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: _border),
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _queryController,
              onSubmitted: (s) => _runSearch(s),
              style: TextStyle(
                color: _ink,
                fontSize: healthSp(context, 16),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: '검색',
                hintStyle: TextStyle(
                  color: _muted,
                  fontSize: healthSp(context, 14),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w300,
                ),
              ),
              textInputAction: TextInputAction.search,
            ),
          ),
          GestureDetector(
            onTap: () => _runSearch(_queryController.text),
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
    );
  }

  Widget _buildTabRow() {
    final labels = ['비대면 진료', '스토어', '콘텐츠'];
    return Row(
      children: [
        for (int i = 0; i < 3; i++) ...[
          if (i > 0) ...[
            Container(
              width: 0.5,
              height: healthDp(context, 11),
              color: _border,
            ),
          ],
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _tab = i),
              borderRadius: BorderRadius.circular(4),
              child: Container(
                padding: EdgeInsets.only(bottom: healthDp(context, 5)),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      width: 1,
                      color: _tab == i ? _pink : Colors.transparent,
                    ),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _tab == i ? _pink : const Color(0xFF898686),
                    fontSize: healthSp(context, 14),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: _tab == i ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProductGrid(List<Product> list, {required bool general}) {
    if (list.isEmpty) {
      return Center(
        child: Text(
          '해당 탭에 검색 결과가 없습니다.',
          style: TextStyle(
            color: _muted,
            fontSize: healthSp(context, 14),
            fontFamily: 'Gmarket Sans TTF',
          ),
        ),
      );
    }
    return GridView.builder(
      padding: EdgeInsets.only(
        top: healthDp(context, 10),
        bottom: healthDp(context, 24),
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: SearchProductCard.preferredMainAxisExtent(context),
        crossAxisSpacing: healthDp(context, 12),
        mainAxisSpacing: healthDp(context, 16),
      ),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final p = list[i];
        return SearchProductCard(
          product: p,
          onTap: () => _openProduct(p, general: general),
        );
      },
    );
  }

  String _contentThumb(Map<String, dynamic> item) {
    final raw = item['thumbnail_url']?.toString();
    final thumb = ContentService.resolveThumbnailUrl(raw, fallback: '');
    if (thumb.isNotEmpty) return thumb;
    return ContentService.resolveDisplayImageUrl(
      thumbnail: raw,
      contentHtml: item['content_html']?.toString(),
      fallback: '${ImageUrlHelper.imageBaseUrl}/data/item/no_img.png',
    );
  }

  Widget _buildContentList() {
    if (_content.isEmpty) {
      return Center(
        child: Text(
          '해당 탭에 검색 결과가 없습니다.',
          style: TextStyle(
            color: _muted,
            fontSize: healthSp(context, 14),
            fontFamily: 'Gmarket Sans TTF',
          ),
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.only(
        top: healthDp(context, 10),
        bottom: healthDp(context, 24),
      ),
      itemCount: _content.length,
      separatorBuilder: (_, __) => SizedBox(height: healthDp(context, 16)),
      itemBuilder: (context, i) {
        final item = _content[i];
        final title = item['title']?.toString().trim() ?? '';
        final url = _contentThumb(item);

        return InkWell(
          onTap: () => _openContent(item),
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(healthDp(context, 10)),
                child: SizedBox(
                  width: double.infinity,
                  height: healthDp(context, 200),
                  child: url.isEmpty
                      ? Container(
                          color: Colors.grey.shade200,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.article_outlined,
                            color: Colors.grey.shade400,
                            size: healthDp(context, 40),
                          ),
                        )
                      : Image.network(
                          url,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.article_outlined,
                              color: Colors.grey.shade400,
                              size: healthDp(context, 40),
                            ),
                          ),
                        ),
                ),
              ),
              SizedBox(height: healthDp(context, 12)),
              Text(
                title,
                style: TextStyle(
                  color: _ink,
                  fontSize: healthSp(context, 14),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                  letterSpacing: healthSp(context, -1.26),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
