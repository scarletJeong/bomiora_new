import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../data/repositories/health/food/food_repository.dart';
import '../../health_common/widgets/health_delete_popup.dart';

/// 칼로리 검색 입력 + 검색 결과 카드 블록 (각 식사 카드 아래에 배치)
/// "음식을 검색하세요" 입력 후 검색 시 API 연동, 카드 탭 시 해당 식사에 추가
/// addedItems: 이 식사에 이미 추가된 음식 리스트 (검색 블록 아래에 표시)
class CalorieSearchBlock extends StatefulWidget {
  final String mealKey;
  final DateTime selectedDate;
  final String mbId;
  final String foodRecordId;
  final List<FoodRecordItemSummary> addedItems;
  final VoidCallback? onItemAdded;

  const CalorieSearchBlock({
    super.key,
    required this.mealKey,
    required this.selectedDate,
    required this.mbId,
    this.foodRecordId = '',
    this.addedItems = const [],
    this.onItemAdded,
  });

  @override
  State<CalorieSearchBlock> createState() => _CalorieSearchBlockState();
}

class _CalorieSearchBlockState extends State<CalorieSearchBlock> {
  static const int _pageSize = 20;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _resultsScrollController = ScrollController();
  List<FoodSearchItem> _results = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _isAdding = false;
  String _currentKeyword = '';
  int _currentOffset = 0;

  Future<void> _doSearch() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _results = [];
        _currentKeyword = '';
        _currentOffset = 0;
        _hasMore = false;
      });
      return;
    }
    setState(() {
      _isLoading = true;
      _isLoadingMore = false;
      _currentKeyword = keyword;
      _currentOffset = 0;
      _hasMore = false;
    });
    try {
      final list = await FoodRepository.searchFood(
        keyword,
        limit: _pageSize,
        offset: 0,
      );
      if (mounted) {
        setState(() {
          _results = list;
          _currentOffset = list.length;
          _hasMore = list.length == _pageSize;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _results = [];
          _currentOffset = 0;
          _hasMore = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadMoreResults() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    final keyword = _currentKeyword.trim();
    if (keyword.isEmpty) return;
    setState(() => _isLoadingMore = true);
    try {
      final list = await FoodRepository.searchFood(
        keyword,
        limit: _pageSize,
        offset: _currentOffset,
      );
      if (!mounted) return;
      setState(() {
        _results.addAll(list);
        _currentOffset += list.length;
        _hasMore = list.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _onResultsScroll() {
    if (!_resultsScrollController.hasClients) return;
    final position = _resultsScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 24) {
      _loadMoreResults();
    }
  }

  Future<void> _addToMealRecord(FoodSearchItem item) async {
    if (_isAdding) return;
    if (kDebugMode) {
      debugPrint('[+] 선택한 음식: "${item.foodName}" | food_code: ${item.foodCode} | energy: ${item.energy} | 식사: ${widget.mealKey}');
    }
    setState(() => _isAdding = true);
    try {
      final records = await FoodRepository.getRecordsForDate(widget.mbId, widget.selectedDate);
      final foodTime = FoodRepository.foodTimeFromMealKey(widget.mealKey);
      FoodRecordSummary? record;
      for (final r in records) {
        if (r.foodTime == foodTime) {
          record = r;
          break;
        }
      }
      if (record == null) {
        final created = await FoodRepository.createRecord(
          widget.mbId,
          widget.selectedDate,
          widget.mealKey,
        );
        if (created == null) {
          if (mounted) _showSnackBar('식사 기록 추가에 실패했습니다.');
          return;
        }
        record = created;
      }
      final ok = await FoodRepository.addItemToRecord(record.id, item);
      if (mounted) {
        if (ok) {
          _showSnackBar('${item.foodName}을(를) 식사 기록에 추가했습니다.');
          widget.onItemAdded?.call();
          setState(() {
            _results = [];
            _searchController.clear();
          });
        } else {
          _showSnackBar('식사 기록 추가에 실패했습니다.');
        }
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _deleteItem(BuildContext context, String foodRecordId, String itemId, String foodName) async {
    final confirmed = await showHealthDeletePopup(
      context: context,
      title: '음식 삭제',
      message: '이 음식을 식사 기록에서 삭제할까요?\n$foodName',
    );
    if (confirmed != true || !mounted) return;
    final ok = await FoodRepository.deleteRecordItem(foodRecordId, itemId);
    if (!mounted) return;
    if (ok) {
      _showSnackBar('삭제되었습니다.');
      widget.onItemAdded?.call();
    } else {
      _showSnackBar('삭제에 실패했습니다.');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _resultsScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _resultsScrollController.addListener(_onResultsScroll);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 사진 추가하기 (기능 미구현)
        Container(
          width: 80,
          height: 80,
          clipBehavior: Clip.antiAlias,
          decoration: ShapeDecoration(
            color: const Color(0xFFD9D9D9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 50,
                height: 50,
                clipBehavior: Clip.antiAlias,
                decoration: const BoxDecoration(),
                child: const Stack(),
              ),
              const Text(
                '사진추가하기',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          '음식 검색',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          height: 35,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          decoration: BoxDecoration(
            border: Border.all(width: 1, color: const Color(0xFFD2D2D2)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  decoration: const InputDecoration(
                    hintText: '음식을 입력하세요.',
                    hintStyle: TextStyle(
                      color: Color(0xFF898383),
                      fontSize: 14,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w300,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                  ),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                  onSubmitted: (_) => _doSearch(),
                ),
              ),
              GestureDetector(
                onTap: _isLoading ? null : _doSearch,
                child: Icon(
                  Icons.search,
                  color: _isLoading ? const Color(0xFFCCCCCC) : const Color(0xFF898383),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
        if (_isLoading) ...[
          const SizedBox(height: 10),
          const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFF5A8D)),
              ),
            ),
          ),
        ] else if (_searchController.text.trim().isNotEmpty && _results.isEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFD2D2D2)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Center(
              child: Text(
                '검색 결과가 없습니다.',
                style: TextStyle(
                  color: Color(0xFF898383),
                  fontSize: 12,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          ),
        ],
        // 검색 결과 리스트 (항상 보이는 일반 컬럼 렌더링)
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFD2D2D2)),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A000000),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.separated(
              controller: _resultsScrollController,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _results.length + (_isLoadingMore ? 1 : 0),
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, thickness: 1, color: Color(0xFFF1F1F1)),
              itemBuilder: (context, i) {
                if (i >= _results.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFFF5A8D),
                        ),
                      ),
                    ),
                  );
                }
                final item = _results[i];
                return SearchResultRow(
                  name: item.foodName,
                  kcal: item.energy?.toInt() ?? 0,
                  desc: item.desc,
                  onSelect: _isAdding ? null : () => _addToMealRecord(item),
                );
              },
            ),
          ),
        ],
        if (widget.addedItems.isNotEmpty) ...[
          const SizedBox(height: 14),
          ...List.generate(widget.addedItems.length, (i) {
            final item = widget.addedItems[i];
            return Padding(
              padding:
                  EdgeInsets.only(bottom: i < widget.addedItems.length - 1 ? 6 : 0),
              child: AddedFoodCard(
                name: item.foodName,
                kcal: item.kcal?.toInt() ?? 0,
                desc: item.desc,
                itemId: item.itemId,
                foodRecordId: widget.foodRecordId,
                onDelete: widget.foodRecordId.isNotEmpty && item.itemId.isNotEmpty
                    ? () => _deleteItem(
                          context,
                          widget.foodRecordId,
                          item.itemId,
                          item.foodName,
                        )
                    : null,
              ),
            );
          }),
        ],
      ],
    );
  }
}

/// 이미 추가된 음식 카드 (검색 블록 아래 리스트용, 오른쪽에 삭제 X 버튼)
class AddedFoodCard extends StatelessWidget {
  final String name;
  final int kcal;
  final String desc;
  final String itemId;
  final String foodRecordId;
  final VoidCallback? onDelete;

  const AddedFoodCard({
    super.key,
    required this.name,
    required this.kcal,
    required this.desc,
    required this.itemId,
    required this.foodRecordId,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        shadows: const [
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 4.17,
            offset: Offset(0, 0),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$kcal',
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 10,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      const TextSpan(
                        text: ' kcal',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
                  ),
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      desc,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 8,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onDelete != null)
            GestureDetector(
              onTap: onDelete,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: Icon(Icons.close, size: 14, color: const Color(0xFF898383)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 드롭다운 검색 결과 한 행: "음식명 190kcal (지방 2g, ...)" + "선택" 버튼
class SearchResultRow extends StatelessWidget {
  final String name;
  final int kcal;
  final String desc;
  final VoidCallback? onSelect;

  const SearchResultRow({
    super.key,
    required this.name,
    required this.kcal,
    required this.desc,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    '$name ${kcal}kcal',
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      desc,
                      style: const TextStyle(
                        color: Color(0xFF898383),
                        fontSize: 10,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 28,
            child: TextButton(
              onPressed: onSelect,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                side: const BorderSide(color: Color(0xFFD2D2D2)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
              child: const Text(
                '선택',
                style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 12,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SearchResultCard extends StatelessWidget {
  final String name;
  final int kcal;
  final String desc;
  final String? foodCode;
  final VoidCallback? onTap;

  const SearchResultCard({
    super.key,
    required this.name,
    required this.kcal,
    required this.desc,
    this.foodCode,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [
          BoxShadow(color: Color(0x19000000), blurRadius: 4.17),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$kcal kcal',
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
                    fontSize: 10,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      desc,
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 8,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.add, size: 14, color: Color(0xFF898383)),
        ],
      ),
    ),
    );
  }
}

class MacroLegend extends StatelessWidget {
  final Color color;
  final String label;

  const MacroLegend({
    super.key,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16.23,
          height: 16.23,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 10,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }
}
