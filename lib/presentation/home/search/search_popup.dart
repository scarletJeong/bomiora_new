import 'package:flutter/material.dart';

import '../../../data/services/recent_search_service.dart';
import '../../health/health_common/health_responsive_scale.dart';
import 'search_list_screen.dart';

/// 앱바 검색 아이콘용: 오버레이 스타일 검색·최근 검색어 팝업 후 [SearchListScreen]으로 이동.
class SearchPopup {
  SearchPopup._();

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: const Color(0x991A1A1A),
      builder: (ctx) => const _SearchPopupDialog(),
    );
  }
}

class _SearchPopupDialog extends StatefulWidget {
  const _SearchPopupDialog();

  @override
  State<_SearchPopupDialog> createState() => _SearchPopupDialogState();
}

class _SearchPopupDialogState extends State<_SearchPopupDialog> {
  final TextEditingController _controller = TextEditingController();
  List<String> _recent = const [];
  bool _loadingRecent = true;

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final list = await RecentSearchService.getQueries();
    if (!mounted) return;
    setState(() {
      _recent = list;
      _loadingRecent = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    await RecentSearchService.addQuery(q);
    if (!mounted) return;
    final nav = Navigator.of(context, rootNavigator: true);
    nav.pop();
    nav.push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SearchListScreen(initialQuery: q),
      ),
    );
  }

  Future<void> _onTapRecent(String q) async {
    _controller.text = q;
    await _submit();
  }

  Future<void> _removeRecent(String q) async {
    await RecentSearchService.removeQuery(q);
    await _loadRecent();
  }

  @override
  Widget build(BuildContext context) {
    final w = healthDp(context, 321);
    final radius = healthDp(context, 20);

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: w,
          padding: EdgeInsets.all(healthDp(context, 20)),
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
            ),
            shadows: const [
              BoxShadow(
                color: Color(0x19000000),
                blurRadius: 8.14,
                offset: Offset(0, 0),
                spreadRadius: 0,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.only(right: healthDp(context, 28)),
                    child: Text(
                      '검색어를 입력하세요',
                      style: TextStyle(
                        color: const Color(0xFF1A1A1A),
                        fontSize: healthSp(context, 20),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(height: healthDp(context, 12)),
                  Container(
                    height: healthDp(context, 36),
                    padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
                    alignment: Alignment.center,
                    decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        side: const BorderSide(
                          width: 1,
                          color: Color(0xFFD2D2D2),
                        ),
                        borderRadius: BorderRadius.circular(healthDp(context, 10)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            autofocus: true,
                            onSubmitted: (_) => _submit(),
                            style: TextStyle(
                              color: const Color(0xFF1A1A1A),
                              fontSize: healthSp(context, 14),
                              fontFamily: 'Gmarket Sans TTF',
                              fontWeight: FontWeight.w400,
                            ),
                            decoration: InputDecoration(
                              isCollapsed: true,
                              border: InputBorder.none,
                              hintText: '검색',
                              hintStyle: TextStyle(
                                color: const Color(0xFF898686),
                                fontSize: healthSp(context, 14),
                                fontFamily: 'Gmarket Sans TTF',
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                            textInputAction: TextInputAction.search,
                          ),
                        ),
                        IconButton(
                          onPressed: _submit,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                          icon: Icon(
                            Icons.search,
                            size: healthDp(context, 20),
                            color: const Color(0xFF898686),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: healthDp(context, 16)),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '최근 검색어',
                      style: TextStyle(
                        color: const Color(0xFF898686),
                        fontSize: healthSp(context, 14),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  SizedBox(height: healthDp(context, 10)),
                  if (_loadingRecent)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: healthDp(context, 16)),
                      child: const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  else if (_recent.isEmpty)
                    SizedBox(
                      height: healthDp(context, 68),
                      child: Center(
                        child: Text(
                          '최근 검색어가 없습니다.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF898686),
                            fontSize: healthSp(context, 16),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w300,
                            height: 1.63,
                          ),
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: healthDp(context, 160)),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _recent.length,
                        separatorBuilder: (_, __) =>
                            SizedBox(height: healthDp(context, 4)),
                        itemBuilder: (context, i) {
                          final item = _recent[i];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _onTapRecent(item),
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  vertical: healthDp(context, 6),
                                  horizontal: healthDp(context, 4),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: const Color(0xFF1A1A1A),
                                          fontSize: healthSp(context, 14),
                                          fontFamily: 'Gmarket Sans TTF',
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => _removeRecent(item),
                                      icon: Icon(
                                        Icons.close,
                                        size: healthDp(context, 18),
                                        color: const Color(0xFFB0B0B0),
                                      ),
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 32,
                                        minHeight: 32,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
              Positioned(
                right: -healthDp(context, 4),
                top: -healthDp(context, 4),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Color(0xFF1A1A1A)),
                  tooltip: '닫기',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
