import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../../core/utils/image_picker_utils.dart';
import '../../../../core/utils/image_url_helper.dart';
import '../../../../data/repositories/health/food/food_repository.dart';
import '../../../common/widgets/dropdown_btn.dart';
import '../../health_common/health_responsive_scale.dart';
import '../../health_common/widgets/health_delete_popup.dart';

/// 칼로리 검색 입력 + 검색 결과 카드 블록 (각 식사 카드 아래에 배치)
/// "음식을 검색하세요" 입력 후 검색 시 API 연동, 카드 탭 시 해당 식사에 추가
/// addedItems: 이 식사에 이미 추가된 음식 리스트 (검색 블록 아래에 표시)
class CalorieSearchBlock extends StatefulWidget {
  final String mealKey;
  final DateTime selectedDate;
  final String mbId;
  final String foodRecordId;
  final List<String> mealImagePaths;
  final List<FoodRecordItemSummary> addedItems;
  final VoidCallback? onItemAdded;

  const CalorieSearchBlock({
    super.key,
    required this.mealKey,
    required this.selectedDate,
    required this.mbId,
    this.foodRecordId = '',
    this.mealImagePaths = const [],
    this.addedItems = const [],
    this.onItemAdded,
  });

  @override
  State<CalorieSearchBlock> createState() => _CalorieSearchBlockState();
}

class _CalorieSearchBlockState extends State<CalorieSearchBlock> {
  static const int _pageSize = 20;
  List<String> _localImagePaths = [];
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _resultsScrollController = ScrollController();
  List<FoodSearchItem> _results = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = false;
  bool _isAdding = false;
  bool _isUploadingPhoto = false;
  String _currentKeyword = '';
  int _currentOffset = 0;
  static const List<String> _photoSourceLabels = [
    '라이브러리에서 선택',
    '사진찍기',
    '파일가져오기',
  ];

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
    if (position.pixels >= position.maxScrollExtent - healthDp(context, 24)) {
      _loadMoreResults();
    }
  }

  Future<void> _addToMealRecord(FoodSearchItem item) async {
    if (_isAdding) return;
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
          return;
        }
        record = created;
      }
      final ok = await FoodRepository.addItemToRecord(record.id, item);
      if (mounted) {
        if (ok) {
          widget.onItemAdded?.call();
          setState(() {
            _results = [];
            _searchController.clear();
          });
        }
      }
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<String?> _ensureFoodRecordId() async {
    if (widget.foodRecordId.isNotEmpty) return widget.foodRecordId;
    if (widget.mbId.isEmpty) return null;
    final created = await FoodRepository.createRecord(
      widget.mbId,
      widget.selectedDate,
      widget.mealKey,
    );
    return created?.id;
  }

  void _openPhotoSourceDropdown(BuildContext anchorContext) {
    if (_isUploadingPhoto) return;
    DropdownBtn.showMenu(
      context: context,
      anchorContext: anchorContext,
      items: _photoSourceLabels,
      menuWidth: healthDp(context, 110),
      itemFontSize: healthDp(context, 10),
      itemFontFamily: 'Gmarket Sans TTF',
      itemFontWeight: FontWeight.w300,
      blurBackdrop: true,
      blurSigma: 2,
      backdropOpacity: 0.35,
      onSelected: _onPhotoSourceSelected,
    );
  }

  Future<void> _onPhotoSourceSelected(String label) async {
    XFile? image;
    switch (label) {
      case '라이브러리에서 선택':
        image = await ImagePickerUtils.pickImageFromGallery();
        break;
      case '사진찍기':
        image = await ImagePickerUtils.pickImageFromCamera();
        break;
      case '파일가져오기':
        image = await ImagePickerUtils.pickImageFromFile();
        break;
    }
    await _uploadPickedMealPhoto(image);
  }

  Future<void> _setRepresentativePhoto(int index) async {
    final paths = List<String>.from(_localImagePaths);
    if (index <= 0 || index >= paths.length) return;
    final recordId = widget.foodRecordId;
    if (recordId.isEmpty) return;
    final reordered = [
      paths[index],
      ...paths.sublist(0, index),
      ...paths.sublist(index + 1),
    ];
    final ok =
        await FoodRepository.updateRecordImagePaths(recordId, reordered);
    if (!mounted) return;
    if (ok) {
      setState(() => _localImagePaths = _sanitizeImagePaths(reordered));
      _notifyParentRefresh();
    }
  }

  void _notifyParentRefresh() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onItemAdded?.call();
    });
  }

  Future<void> _uploadPickedMealPhoto(XFile? image) async {
    if (image == null || !mounted) return;
    setState(() => _isUploadingPhoto = true);
    try {
      final recordId = await _ensureFoodRecordId();
      if (recordId == null || recordId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('식사 기록을 먼저 만들 수 없습니다.')),
          );
        }
        return;
      }

      final imageUrl = kIsWeb
          ? await FoodRepository.uploadMealImage(image)
          : await FoodRepository.uploadMealImage(File(image.path));

      if (imageUrl == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('사진 업로드에 실패했습니다.')),
          );
        }
        return;
      }

      final current = List<String>.from(_localImagePaths);
      if (current.length >= FoodRepository.maxMealImages) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '사진은 최대 ${FoodRepository.maxMealImages}장까지 등록할 수 있습니다.',
              ),
            ),
          );
        }
        return;
      }

      final updated = [...current, imageUrl];
      final ok =
          await FoodRepository.updateRecordImagePaths(recordId, updated);
      if (!mounted) return;
      if (ok) {
        setState(() => _localImagePaths = _sanitizeImagePaths(updated));
        _notifyParentRefresh();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '사진 저장에 실패했습니다. DB에 photos 컬럼이 있는지 확인해 주세요.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
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
      widget.onItemAdded?.call();
    }
  }

  @override
  void dispose() {
    DropdownBtn.closeMenu();
    _searchController.dispose();
    _focusNode.dispose();
    _resultsScrollController.dispose();
    super.dispose();
  }

  List<String> _sanitizeImagePaths(List<String> paths) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in paths) {
      if (ImageUrlHelper.isCorruptStoredImagePath(raw)) continue;
      final key = FoodRepository.normalizeMealImagePathForStorage(raw);
      if (key.isEmpty || seen.contains(key)) continue;
      seen.add(key);
      out.add(key);
      if (out.length >= FoodRepository.maxMealImages) break;
    }
    return out;
  }

  bool _pathsContentChanged(List<String> a, List<String> b) {
    final na = _sanitizeImagePaths(a);
    final nb = _sanitizeImagePaths(b);
    if (na.length != nb.length) return true;
    for (var i = 0; i < na.length; i++) {
      if (na[i] != nb[i]) return true;
    }
    return false;
  }

  List<String> _mergeImagePathLists(List<String> primary, List<String> secondary) {
    final seen = <String>{};
    final out = <String>[];
    for (final list in [primary, secondary]) {
      for (final raw in list) {
        if (ImageUrlHelper.isCorruptStoredImagePath(raw)) continue;
        final key = FoodRepository.normalizeMealImagePathForStorage(raw);
        if (key.isEmpty || seen.contains(key)) continue;
        seen.add(key);
        out.add(key);
        if (out.length >= FoodRepository.maxMealImages) return out;
      }
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    _localImagePaths = _sanitizeImagePaths(widget.mealImagePaths);
    _resultsScrollController.addListener(_onResultsScroll);
  }

  @override
  void didUpdateWidget(CalorieSearchBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.foodRecordId != widget.foodRecordId) {
      _localImagePaths = _sanitizeImagePaths(widget.mealImagePaths);
      return;
    }
    if (_pathsContentChanged(oldWidget.mealImagePaths, widget.mealImagePaths)) {
      final fromParent = _sanitizeImagePaths(widget.mealImagePaths);
      if (fromParent.length >= _localImagePaths.length) {
        _localImagePaths = fromParent;
      } else if (fromParent.isEmpty) {
        // 부모가 아직 갱신 전이면 로컬 유지
      } else {
        _localImagePaths = _mergeImagePathLists(_localImagePaths, fromParent);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MealPhotoStrip(
          imagePaths: _localImagePaths,
          isUploading: _isUploadingPhoto,
          onAddTap: _openPhotoSourceDropdown,
          onPhotoTap: _setRepresentativePhoto,
        ),
        SizedBox(height: healthDp(context, 5)),
        Row(
          children: [
            const Text(
              '음식 검색',
              style: TextStyle(
                color: Colors.black,
                fontSize: 16,
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
              ),
            ),
            const Spacer(),
            Padding(
              padding: EdgeInsets.only(top: healthDp(context, 4)),
              child: MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.noScaling),
                child: Text(
                  '출처: 식품영양성분 데이터베이스',
                  style: TextStyle(
                    color: const Color(0xFF898686),
                    fontSize: healthSp(context, 10),
                    height: 1.0,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: healthDp(context, 5)),
        Container(
          height: healthDp(context, 35),
          padding: EdgeInsets.symmetric(
            horizontal: healthDp(context, 10),
            vertical: 0,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              width: healthDp(context, 1),
              color: const Color(0xFFD2D2D2),
            ),
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
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
                child: SizedBox(
                  width: healthDp(context, 24),
                  height: healthDp(context, 24),
                  child: SvgPicture.asset(
                    AppAssets.searchIcon,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_isLoading) ...[
          SizedBox(height: healthDp(context, 3)),
          Center(
            child: Padding(
              padding: EdgeInsets.all(healthDp(context, 12)),
              child: SizedBox(
                width: healthDp(context, 24),
                height: healthDp(context, 24),
                child: CircularProgressIndicator(
                  strokeWidth: healthDp(context, 2),
                  color: const Color(0xFFFF5A8D),
                ),
              ),
            ),
          ),
        ] else if (_searchController.text.trim().isNotEmpty && _results.isEmpty) ...[
          SizedBox(height: healthDp(context, 3)),
          Container(
            padding: EdgeInsets.symmetric(vertical: healthDp(context, 12)),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFD2D2D2)),
              borderRadius: BorderRadius.circular(healthDp(context, 10)),
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
          SizedBox(height: healthDp(context, 3)),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFD2D2D2)),
              borderRadius: BorderRadius.circular(healthDp(context, 10)),
            ),
            constraints: BoxConstraints(maxHeight: healthDp(context, 220)),
            child: ListView.separated(
              controller: _resultsScrollController,
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: _results.length + (_isLoadingMore ? 1 : 0),
              separatorBuilder: (_, __) => Divider(
                height: healthDp(context, 1),
                thickness: healthDp(context, 1),
                color: const Color(0xFFF1F1F1),
              ),
              itemBuilder: (context, i) {
                if (i >= _results.length) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: healthDp(context, 10)),
                    child: Center(
                      child: SizedBox(
                        width: healthDp(context, 18),
                        height: healthDp(context, 18),
                        child: CircularProgressIndicator(
                          strokeWidth: healthDp(context, 2),
                          color: const Color(0xFFFF5A8D),
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
          SizedBox(height: healthDp(context, 5)),
          ...List.generate(widget.addedItems.length, (i) {
            final item = widget.addedItems[i];
            return Padding(
              padding: EdgeInsets.only(
                bottom: i < widget.addedItems.length - 1
                    ? healthDp(context, 6)
                    : 0,
              ),
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
    final noScale = MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(healthDp(context, 10)),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
        border: Border.all(
          width: healthDp(context, 0.5),
          color: const Color(0xFFD9D9D9),
        ),
      ),
      child: MediaQuery(
        data: noScale,
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: healthSp(context, 12),
                        height: 1.0,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: healthDp(context, 6)),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '$kcal',
                          style: TextStyle(
                            color: const Color(0xFF1A1A1A),
                            fontSize: healthSp(context, 10),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                        TextSpan(
                          text: ' kcal',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: healthSp(context, 10),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (desc.isNotEmpty) ...[
                    SizedBox(width: healthDp(context, 6)),
                    Flexible(
                      child: Text(
                        desc,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: healthSp(context, 8),
                          height: 1.0,
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
                  padding: EdgeInsets.only(left: healthDp(context, 8)),
                  child: SizedBox(
                    width: healthDp(context, 14),
                    height: healthDp(context, 14),
                    child: Icon(
                      Icons.close,
                      size: healthDp(context, 14),
                      color: const Color(0xFF898383),
                    ),
                  ),
                ),
              ),
          ],
        ),
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
    final noScale = MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling);
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 12),
        vertical: healthDp(context, 10),
      ),
      child: MediaQuery(
        data: noScale,
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      '$name ${kcal}kcal',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: healthSp(context, 12),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (desc.isNotEmpty) ...[
                    SizedBox(width: healthDp(context, 6)),
                    Flexible(
                      child: Text(
                        desc,
                        style: TextStyle(
                          color: const Color(0xFF898383),
                          fontSize: healthSp(context, 10),
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
            SizedBox(width: healthDp(context, 8)),
            SizedBox(
              width: healthDp(context, 26),
              height: healthDp(context, 19),
              child: TextButton(
                onPressed: onSelect,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size(
                    healthDp(context, 26),
                    healthDp(context, 19),
                  ),
                  fixedSize: Size(
                    healthDp(context, 26),
                    healthDp(context, 19),
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  overlayColor: Colors.transparent,
                  splashFactory: NoSplash.splashFactory,
                  side: const BorderSide(color: Color(0xFFD2D2D2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(healthDp(context, 4)),
                  ),
                ),
                child: Text(
                  '선택',
                  style: TextStyle(
                    color: const Color(0xFF898383),
                    fontSize: healthSp(context, 8),
                    height: 1.0,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
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
    final noScale = MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(healthDp(context, 10)),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
          border: Border.all(
            width: healthDp(context, 0.5),
            color: const Color(0xFFD9D9D9),
          ),
        ),
        child: MediaQuery(
          data: noScale,
          child: Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: healthSp(context, 12),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    SizedBox(width: healthDp(context, 6)),
                    Text(
                      '$kcal kcal',
                      style: TextStyle(
                        color: const Color(0xFF1A1A1A),
                        fontSize: healthSp(context, 10),
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                    if (desc.isNotEmpty) ...[
                      SizedBox(width: healthDp(context, 6)),
                      Flexible(
                        child: Text(
                          desc,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: healthSp(context, 8),
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
              Icon(
                Icons.add,
                size: healthDp(context, 14),
                color: const Color(0xFF898383),
              ),
            ],
          ),
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
          width: healthDp(context, 10),
          height: healthDp(context, 10),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: healthDp(context, 3)),
        MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.noScaling),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.black,
              fontSize: healthSp(context, 10),
              height: 1.0,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ],
    );
  }
}

/// 사진추가 카드 + 업로드된 사진(최대 3, 첫 장 = 대표)
class _MealPhotoStrip extends StatelessWidget {
  const _MealPhotoStrip({
    required this.imagePaths,
    required this.isUploading,
    required this.onAddTap,
    required this.onPhotoTap,
  });

  final List<String> imagePaths;
  final bool isUploading;
  final void Function(BuildContext anchorContext) onAddTap;
  final void Function(int index) onPhotoTap;

  @override
  Widget build(BuildContext context) {
    final paths = imagePaths
        .where((p) => !ImageUrlHelper.isCorruptStoredImagePath(p))
        .take(FoodRepository.maxMealImages)
        .toList();
    final tile = healthDp(context, 80);
    final gap = healthDp(context, 6);

    return Builder(
      builder: (anchorContext) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              if (paths.length < FoodRepository.maxMealImages)
                _MealPhotoAddTile(
                  size: tile,
                  isUploading: isUploading,
                  onTap: isUploading
                      ? null
                      : () => onAddTap(anchorContext),
                ),
              for (var i = 0; i < paths.length; i++) ...[
                if (i > 0 || paths.length < FoodRepository.maxMealImages)
                  SizedBox(width: gap),
                _MealPhotoThumbnail(
                  size: tile,
                  imagePath: paths[i],
                  isRepresentative: i == 0,
                  onTap: i == 0 ? null : () => onPhotoTap(i),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MealPhotoAddTile extends StatelessWidget {
  const _MealPhotoAddTile({
    required this.size,
    required this.isUploading,
    this.onTap,
  });

  final double size;
  final bool isUploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0xFFD9D9D9),
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
        ),
        child: isUploading
            ? Center(
                child: SizedBox(
                  width: healthDp(context, 24),
                  height: healthDp(context, 24),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: healthDp(context, 50),
                    height: healthDp(context, 50),
                    child: SvgPicture.asset(
                      AppAssets.foodCamera,
                      fit: BoxFit.cover,
                    ),
                  ),
                  SizedBox(height: healthDp(context, 4)),
                  const Text(
                    '사진추가하기',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      height: 1.0,
                      fontFamily: 'Gmarket Sans TTF',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _MealPhotoThumbnail extends StatelessWidget {
  const _MealPhotoThumbnail({
    required this.size,
    required this.imagePath,
    required this.isRepresentative,
    this.onTap,
  });

  final double size;
  final String imagePath;
  final bool isRepresentative;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(healthDp(context, 10));
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                ImageUrlHelper.getImageUrl(imagePath),
                key: ValueKey(imagePath),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: Color(0xFF6C6C6C)),
              ),
              if (isRepresentative)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: healthDp(context, 6),
                      vertical: healthDp(context, 4),
                    ),
                    color: const Color(0xB2FF5A8D),
                    child: Text(
                      '대표사진',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: healthSp(context, 10),
                        height: 1.0,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
