import 'package:flutter/material.dart';

import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/product/product_model.dart';
import '../../../data/services/content_service.dart';
import '../../../data/services/search_service.dart';
import '../../common/widgets/app_bar.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/product_card.dart';
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

  List<Product> _rx = const [];
  List<Product> _store = const [];
  List<Map<String, dynamic>> _content = const [];
  bool _loading = true;
  String? _error;

  int _tab = 0; // 0: 비대면 진료, 1: 스토어, 2: 콘텐츠

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery.trim());
    _runSearch(_queryController.text);
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) {
      setState(() {
        _rx = const [];
        _store = const [];
        _content = const [];
        _loading = false;
        _error = null;
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
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  int get _total => _rx.length + _store.length + _content.length;

  void _openProduct(Product p, {required bool general}) {
    final route =
        general ? '/product-general/${p.id}' : '/product/${p.id}';
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
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: const HealthAppBar(title: '검색', centerTitle: true),
        body: _loading
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
                : _total == 0
                    ? _buildGlobalEmpty()
                    : _buildResults(),
      ),
    );
  }

  Widget _buildGlobalEmpty() {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        healthDp(context, 27),
        healthDp(context, 20),
        healthDp(context, 27),
        healthDp(context, 24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchBar(),
          SizedBox(height: healthDp(context, 40)),
          Icon(
            Icons.search_off_outlined,
            size: healthDp(context, 80),
            color: Colors.grey.shade300,
          ),
          SizedBox(height: healthDp(context, 16)),
          Text(
            '검색 결과가 없습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ink,
              fontSize: healthSp(context, 20),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
              height: 1.6,
            ),
          ),
          SizedBox(height: healthDp(context, 8)),
          Text(
            '검색어를 다시 입력해주세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: healthSp(context, 16),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
              height: 1.63,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            healthDp(context, 27),
            healthDp(context, 8),
            healthDp(context, 27),
            healthDp(context, 8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSearchBar(),
              SizedBox(height: healthDp(context, 12)),
              _buildTabRow(),
              SizedBox(height: healthDp(context, 10)),
              Text(
                '검색 결과 $_total개',
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
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: healthDp(context, 27)),
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
          IconButton(
            onPressed: () => _runSearch(_queryController.text),
            padding: EdgeInsets.zero,
            constraints: BoxConstraints(
              minWidth: healthDp(context, 32),
              minHeight: healthDp(context, 32),
            ),
            icon: Icon(
              Icons.search,
              size: healthDp(context, 20),
              color: _muted,
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
        childAspectRatio: 0.58,
        crossAxisSpacing: healthDp(context, 12),
        mainAxisSpacing: healthDp(context, 16),
      ),
      itemCount: list.length,
      itemBuilder: (context, i) {
        final p = list[i];
        return ProductCatalogCard(
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
        final thumbWidget = url.isEmpty
            ? Container(
                width: healthDp(context, 100),
                height: healthDp(context, 72),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(healthDp(context, 8)),
                ),
                alignment: Alignment.center,
                child:
                    Icon(Icons.article_outlined, color: Colors.grey.shade400),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(healthDp(context, 8)),
                child: Image.network(
                  url,
                  width: healthDp(context, 100),
                  height: healthDp(context, 72),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: healthDp(context, 100),
                    height: healthDp(context, 72),
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.article_outlined,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
              );
        return InkWell(
          onTap: () => _openContent(item),
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              thumbWidget,
              SizedBox(width: healthDp(context, 12)),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(top: healthDp(context, 4)),
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _ink,
                      fontSize: healthSp(context, 15),
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
