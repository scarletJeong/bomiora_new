import 'package:flutter/material.dart';

import '../../../data/models/product/product_model.dart';
import '../../../data/models/product/product_option_model.dart';
import '../../../data/repositories/product/product_option_repository.dart';
import '../../../data/services/cart_service.dart';
import '../../common/widgets/dropdown_btn.dart';
import '../../health/health_common/health_responsive_scale.dart';

class OptionSelectorBottomSheet extends StatefulWidget {
  final List<ProductOption> options;
  final Map<ProductOption, int> selectedOptions;
  final int basePrice;
  final String stepLabel;
  final String monthsLabel;
  final int? userPoint;
  final String? productKind;
  final Product? product;
  final List<SupplyCartLine> supplyLines;
  final Function(Map<ProductOption, int>) onOptionsChanged;
  final ValueChanged<List<SupplyCartLine>>? onSupplyLinesChanged;
  final VoidCallback onAddToCart;
  final VoidCallback onAddToPrescriptionCart;
  final VoidCallback onReserve;
  final VoidCallback onBuyNow;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;

  const OptionSelectorBottomSheet({
    super.key,
    required this.options,
    required this.selectedOptions,
    required this.basePrice,
    required this.stepLabel,
    required this.monthsLabel,
    this.userPoint,
    this.productKind,
    this.product,
    this.supplyLines = const [],
    required this.onOptionsChanged,
    this.onSupplyLinesChanged,
    required this.onAddToCart,
    required this.onAddToPrescriptionCart,
    required this.onReserve,
    required this.onBuyNow,
    this.isFavorite = false,
    this.onToggleFavorite,
  });

  @override
  State<OptionSelectorBottomSheet> createState() =>
      _OptionSelectorBottomSheetState();
}


const String _kGmarketSans = 'Gmarket Sans TTF';

/// 본상품 선택 라인 (같은 옵션이면 수량 증가, 다른 옵션이면 새 카드)
class _MainLineItem {
  final String lineId;
  final ProductOption option;
  int quantity;

  _MainLineItem({
    required this.lineId,
    required this.option,
    this.quantity = 1,
  });
}

TextStyle _optionLabelTextStyle(BuildContext context) => TextStyle(
      color: const Color(0xFF1A1A1E),
      fontSize: healthSp(context, 16),
      fontFamily: _kGmarketSans,
      fontWeight: FontWeight.w500,
    );


TextStyle _selectedCardLabelTextStyle(BuildContext context) => TextStyle(
      color: const Color(0xFF1A1A1A),
      fontSize: healthSp(context, 14),
      fontFamily: _kGmarketSans,
      fontWeight: FontWeight.w500,
    );

String _formatPrice(int value) {
  return value.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]},',
      );
}

String? _extractDiscountSuffix(ProductOption option) {
  for (final source in [option.id, option.step, option.subOption]) {
    final match = RegExp(r'\(-\s*\d+%\s*\)').firstMatch(source);
    if (match != null) return match.group(0);
  }
  return null;
}

/// 선택 카드용 짧은 상품명: 디톡스환 / 다이어트환
String _cardProductShortLabel({
  String? name,
  String? categoryId,
  String? extra,
}) {
  final blob = '${name ?? ''} ${extra ?? ''}';
  final ca = (categoryId ?? '').trim();
  if (blob.contains('디톡스') || ca == '20') return '디톡스환';
  if (blob.contains('다이어트') || ca == '10') return '다이어트환';
  final cleaned = (name ?? '').trim();
  return cleaned.isNotEmpty ? cleaned : '상품';
}

/// 선택 카드 옵션 줄: `초코 > 1주 플랜` (chr(30) 축) 또는 단계/개월
String _selectedOptionValueText(ProductOption option) {
  return option.displayText;
}

class _OptionSelectorBottomSheetState extends State<OptionSelectorBottomSheet> {
  final Map<String, List<ProductOption>> _groupedOptionsByStep = {};
  final Map<int, List<ProductOption>> _groupedOptionsByMonths = {};
  /// chr(30) 2축: 상위(step)별 하위 값 → 옵션
  final Map<String, List<ProductOption>> _groupedOptionsByAxis2 = {};
  final List<String> _stepGroups = [];
  final List<int> _monthsGroups = [];
  final List<String> _axis2Groups = [];

  String? _selectedStep;
  int? _selectedMonths;
  String? _selectedAxis2;
  late Map<ProductOption, int> _selectedOptions;
  late bool _isFavorite;

  ProductOption? _selectedDep1;
  ProductOption? _selectedDep2;
  List<ProductOption> get _dep1Options =>
      widget.options.where((o) => o.isDep1).toList();
  List<ProductOption> get _dep2Options =>
      widget.options.where((o) => o.isDep2).toList();

  List<Product> _supplyProducts = [];
  bool _supplyLoading = false;
  Product? _pickedSupplyProduct;
  List<ProductOption> _pickedSupplyOptions = [];
  ProductOption? _pickedSupplyOption;
  late List<SupplyCartLine> _supplyLines;

  /// 본상품 선택 라인 (카드 단위)
  final List<_MainLineItem> _mainLines = [];
  int _mainLineSeq = 0;

  /// 추가상품 옵션 (상위/하위) 분리용
  final Map<String, List<ProductOption>> _supplyGroupedByStep = {};
  final Map<int, List<ProductOption>> _supplyGroupedByMonths = {};
  final List<String> _supplyStepGroups = [];
  final List<int> _supplyMonthsGroups = [];
  String? _supplySelectedStep;
  int? _supplySelectedMonths;
  String _supplyStepLabel = '옵션';
  String _supplyMonthsLabel = '세부 옵션';
  /// 추가상품이 묶일 현재 본상품 라인 id
  String? _latestMainLineId;

  bool get _hasMainSelection => _mainLines.isNotEmpty;

  bool get _canCheckout => _hasMainSelection;

  bool get _showSupplyProductPicker => _supplyProducts.length > 1;

  bool get _supplyMonthsEnabled => _supplySelectedStep != null;

  String _newMainLineId() =>
      'main_${++_mainLineSeq}_${DateTime.now().microsecondsSinceEpoch}';

  void _hydrateMainLines(Map<ProductOption, int> map) {
    _mainLines.clear();
    for (final e in map.entries) {
      if (e.key.isMain || e.key.ioType == 0) {
        _mainLines.add(
          _MainLineItem(
            lineId: _newMainLineId(),
            option: e.key,
            quantity: e.value,
          ),
        );
      }
    }
    _latestMainLineId =
        _mainLines.isNotEmpty ? _mainLines.last.lineId : null;
  }

  Map<ProductOption, int> _buildOptionsMapForParent() {
    final map = <ProductOption, int>{};
    for (final line in _mainLines) {
      ProductOption? existing;
      for (final k in map.keys) {
        if (k.id == line.option.id) {
          existing = k;
          break;
        }
      }
      if (existing != null) {
        map[existing] = (map[existing] ?? 0) + line.quantity;
      } else {
        map[line.option] = line.quantity;
      }
    }
    for (final e in _selectedOptions.entries) {
      if (e.key.isDependent) {
        map[e.key] = e.value;
      }
    }
    return map;
  }

  void _emitOptionsChanged() {
    widget.onOptionsChanged(_buildOptionsMapForParent());
  }

  @override
  void initState() {
    super.initState();
    _selectedOptions = {};
    for (final e in widget.selectedOptions.entries) {
      if (e.key.isDependent) {
        _selectedOptions[e.key] = e.value;
      }
    }
    _hydrateMainLines(widget.selectedOptions);
    _supplyLines = List<SupplyCartLine>.from(widget.supplyLines);
    _isFavorite = widget.isFavorite;
    _initializeGroups();
    _loadSupplyProducts();
  }

  @override
  void didUpdateWidget(covariant OptionSelectorBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.supplyLines != widget.supplyLines) {
      setState(() {
        _supplyLines = List<SupplyCartLine>.from(widget.supplyLines);
      });
    }
    if (oldWidget.isFavorite != widget.isFavorite) {
      setState(() => _isFavorite = widget.isFavorite);
    }
  }

  Future<void> _loadSupplyProducts() async {
    final product = widget.product;
    if (product == null || product.supplyItemIds.isEmpty) return;
    setState(() => _supplyLoading = true);
    final list =
        await ProductOptionRepository.getSupplyProducts(product.id);
    if (!mounted) return;
    setState(() {
      _supplyProducts = list;
      _supplyLoading = false;
    });
    // 추가상품이 1개면 상품 선택 드롭다운 생략 → 바로 옵션 로드
    if (list.length == 1) {
      await _onSupplyProductPicked(list.first);
    }
  }

  void _resetSupplyOptionSelection({bool clearProduct = false}) {
    _pickedSupplyOption = null;
    _supplySelectedStep = null;
    _supplySelectedMonths = null;
    _supplyGroupedByStep.clear();
    _supplyGroupedByMonths.clear();
    _supplyStepGroups.clear();
    _supplyMonthsGroups.clear();
    if (clearProduct) {
      _pickedSupplyProduct = null;
      _pickedSupplyOptions = [];
    }
  }

  void _applySupplyOptionLabels(Product product) {
    final raw = product.additionalInfo?['it_option_subject']?.toString() ??
        product.additionalInfo?['itOptionSubject']?.toString() ??
        '';
    final subjectLabels = raw
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    // 기본값 — 상품 옵션 라벨이 있으면 덮어씀
    _supplyStepLabel = '옵션';
    _supplyMonthsLabel = '세부 옵션';

    if (subjectLabels.length >= 2) {
      _supplyStepLabel = subjectLabels[0];
      _supplyMonthsLabel = subjectLabels[1];
    } else if (subjectLabels.length == 1) {
      // 라벨이 1개면 보이는 드롭다운(상위 또는 하위)에 동일 적용
      final only = subjectLabels.first;
      _supplyStepLabel = only;
      _supplyMonthsLabel = only;
    }

    debugPrint(
      '[추가상품] it_option_subject="$raw" '
      '→ stepLabel="$_supplyStepLabel", monthsLabel="$_supplyMonthsLabel"',
    );
  }

  void _initializeSupplyOptionGroups() {
    _supplyGroupedByStep.clear();
    _supplyStepGroups.clear();
    _supplySelectedStep = null;
    _supplySelectedMonths = null;
    _supplyGroupedByMonths.clear();
    _supplyMonthsGroups.clear();

    for (final option in _pickedSupplyOptions) {
      final step = option.step.isNotEmpty ? option.step : option.displayText;
      if (!_supplyGroupedByStep.containsKey(step)) {
        _supplyGroupedByStep[step] = [];
        _supplyStepGroups.add(step);
      }
      _supplyGroupedByStep[step]!.add(option);
    }

    if (_supplyStepGroups.length == 1) {
      _supplySelectedStep = _supplyStepGroups.first;
    }
    _updateSupplyMonthsGroups();
  }

  void _updateSupplyMonthsGroups() {
    _supplyGroupedByMonths.clear();
    _supplyMonthsGroups.clear();
    if (_supplySelectedStep == null) return;

    final stepOptions = _supplyGroupedByStep[_supplySelectedStep] ?? [];
    for (final option in stepOptions) {
      final months = option.months;
      if (months == null) continue;
      if (!_supplyGroupedByMonths.containsKey(months)) {
        _supplyGroupedByMonths[months] = [];
        _supplyMonthsGroups.add(months);
      }
      _supplyGroupedByMonths[months]!.add(option);
    }
    _supplyMonthsGroups.sort();
  }

  /// 하위(개월)가 없을 때 같은 상위 옵션의 세부 선택지
  List<ProductOption> get _supplySubOptionsForStep {
    if (_supplySelectedStep == null) return const [];
    return _supplyGroupedByStep[_supplySelectedStep] ?? const [];
  }

  Future<void> _onSupplyProductPicked(Product product) async {
    setState(() {
      _resetSupplyOptionSelection(clearProduct: false);
      _pickedSupplyProduct = product;
      _pickedSupplyOptions = [];
      _applySupplyOptionLabels(product);
    });
    final opts =
        await ProductOptionRepository.getProductOptions(product.id);
    if (!mounted) return;

    final mainOpts = opts.where((o) => o.isMain).toList();
    final resolved = mainOpts.isNotEmpty ? mainOpts : opts;

    // ignore: avoid_print
    print('========== [추가상품 옵션] ${product.name} (${product.id}) ==========');
    // ignore: avoid_print
    print('it_option_subject: ${product.additionalInfo?['it_option_subject']}');
    // ignore: avoid_print
    print('옵션 개수: ${resolved.length} (전체 ${opts.length}, type0 ${mainOpts.length})');
    for (var i = 0; i < resolved.length; i++) {
      final o = resolved[i];
      // ignore: avoid_print
      print(
        '  [$i] id=${o.id} ioType=${o.ioType} '
        'step="${o.step}" months=${o.months} '
        'sub="${o.subOption}" price=${o.price} '
        'display="${o.displayText}"',
      );
    }
    // ignore: avoid_print
    print('========================================================');

    setState(() {
      _pickedSupplyOptions = resolved;
      _initializeSupplyOptionGroups();
      debugPrint(
        '[추가상품] groups step=${_supplyStepGroups.length} '
        'months=${_supplyMonthsGroups.length} '
        'labels=$_supplyStepLabel / $_supplyMonthsLabel',
      );
    });
  }

  void _addSupplyLineFromOption(ProductOption option) {
    if (!_hasMainSelection) return;
    setState(() => _pickedSupplyOption = option);
    _addSupplyLine();
  }

  void _addSupplyLine() {
    final product = _pickedSupplyProduct;
    if (product == null) return;
    if (!_hasMainSelection) return;
    final option = _pickedSupplyOption;
    // 옵션이 있는데 미선택이면 추가 안 함
    if (_pickedSupplyOptions.isNotEmpty && option == null) return;

    final attachId = _latestMainLineId ?? _mainLines.lastOrNull?.lineId;

    setState(() {
      _supplyLines.add(
        SupplyCartLine(
          productId: product.id,
          productName: product.name,
          basePrice: product.price,
          option: option,
          quantity: 1,
          attachedMainLineId: attachId,
        ),
      );
      // 같은 추가상품으로 다른 옵션을 더 고를 수 있게 옵션 선택만 초기화
      _pickedSupplyOption = null;
      _supplySelectedMonths = null;
      if (_supplyStepGroups.length > 1) {
        _supplySelectedStep = null;
        _updateSupplyMonthsGroups();
      } else if (_supplyStepGroups.length == 1) {
        _supplySelectedStep = _supplyStepGroups.first;
        _updateSupplyMonthsGroups();
      }
      // 복수 추가상품일 때만 상품 선택도 초기화(다시 고르게)
      if (_showSupplyProductPicker) {
        // 상품은 유지하고 옵션만 리셋 — 같은 상품 연속 추가 편의
      }
    });
    _notifySupplyChanged();
  }

  List<ProductOption> get _mainSelectableOptions {
    final mains = widget.options.where((o) => o.isMain).toList();
    if (mains.isNotEmpty) return mains;
    // io_type 미구분 데이터: 종속(2/3)만 제외
    return widget.options.where((o) => !o.isDependent).toList();
  }

  /// io_id에 chr(30) 축 구분자가 있으면 `맛 > 플랜` 2단 UI
  bool get _usesAxisDelimiter {
    return _mainSelectableOptions.any((o) => o.hasAxisDelimiter);
  }

  /// 비대면 레거시: `N개월` 단계/개월 UI.
  /// chr(30) 축이 있으면 축 UI가 우선.
  bool get _usesMonthsHierarchy {
    if (_usesAxisDelimiter) return false;
    final source = _mainSelectableOptions;
    final hasMonthsPattern = source.any(
      (o) => o.id.contains('개월') && o.months != null,
    );
    if (widget.productKind == 'general') {
      return hasMonthsPattern;
    }
    return true;
  }

  void _initializeGroups() {
    _groupedOptionsByStep.clear();
    _stepGroups.clear();
    _groupedOptionsByAxis2.clear();
    _axis2Groups.clear();
    _selectedAxis2 = null;

    final source = _mainSelectableOptions;

    // ignore: avoid_print
    print('========== [옵션 그룹핑] kind=${widget.productKind} '
        'axis=$_usesAxisDelimiter months=$_usesMonthsHierarchy ==========');
    // ignore: avoid_print
    print('전체=${widget.options.length} '
        'main=${widget.options.where((o) => o.isMain).length} '
        'dep1=${_dep1Options.length} dep2=${_dep2Options.length} '
        'source=${source.length}');
    for (var i = 0; i < widget.options.length; i++) {
      final o = widget.options[i];
      // ignore: avoid_print
      print(
        '  ALL[$i] id=${o.id.codeUnits} parts=${o.optionParts} '
        'step="${o.step}" sub="${o.subOption}" months=${o.months} '
        'display="${o.displayText}"',
      );
    }

    for (final option in source) {
      // chr(30)/개월 계층: 1축(step). 평면: 옵션 단위 키
      final stepKey = (_usesAxisDelimiter || _usesMonthsHierarchy)
          ? option.step
          : (option.displayText.isNotEmpty ? option.displayText : option.id);
      if (stepKey.isEmpty) continue;
      if (!_groupedOptionsByStep.containsKey(stepKey)) {
        _groupedOptionsByStep[stepKey] = [];
        _stepGroups.add(stepKey);
      }
      _groupedOptionsByStep[stepKey]!.add(option);
      // ignore: avoid_print
      print('  GROUP stepKey="$stepKey" ← parts=${option.optionParts}');
    }

    // ignore: avoid_print
    print('stepGroups(${_stepGroups.length})=$_stepGroups');
    // ignore: avoid_print
    print('==============================================');

    if (_stepGroups.length == 1) {
      _selectedStep = _stepGroups.first;
    }
    if (_usesAxisDelimiter) {
      _updateAxis2Groups();
    } else {
      _updateMonthsGroups();
    }
  }

  void _updateMonthsGroups() {
    _groupedOptionsByMonths.clear();
    _monthsGroups.clear();
    if (_selectedStep == null) return;

    final stepOptions = _groupedOptionsByStep[_selectedStep] ?? [];
    for (final option in stepOptions) {
      final months = option.months;
      if (months == null) continue;
      if (!_groupedOptionsByMonths.containsKey(months)) {
        _groupedOptionsByMonths[months] = [];
        _monthsGroups.add(months);
      }
      _groupedOptionsByMonths[months]!.add(option);
    }
    _monthsGroups.sort();
  }

  /// chr(30) 2축: 선택된 1축 아래의 unique 2축 값
  void _updateAxis2Groups() {
    _groupedOptionsByAxis2.clear();
    _axis2Groups.clear();
    if (_selectedStep == null) return;

    final stepOptions = _groupedOptionsByStep[_selectedStep] ?? [];
    for (final option in stepOptions) {
      final key = option.axisValue2.isNotEmpty
          ? option.axisValue2
          : (option.optionParts.length > 1
              ? option.optionParts[1]
              : option.displayText);
      if (key.isEmpty) continue;
      if (!_groupedOptionsByAxis2.containsKey(key)) {
        _groupedOptionsByAxis2[key] = [];
        _axis2Groups.add(key);
      }
      _groupedOptionsByAxis2[key]!.add(option);
    }
  }

  bool get _isMonthsEnabled => _selectedStep != null;
  bool get _isAxis2Enabled => _selectedStep != null;

  void _addOption(ProductOption option) {
    setState(() {
      if (option.isMain || option.ioType == 0) {
        final existingIndex =
            _mainLines.indexWhere((l) => l.option.id == option.id);
        if (existingIndex >= 0) {
          _mainLines[existingIndex].quantity++;
          _latestMainLineId = _mainLines[existingIndex].lineId;
        } else {
          final line = _MainLineItem(
            lineId: _newMainLineId(),
            option: option,
            quantity: 1,
          );
          _mainLines.add(line);
          _latestMainLineId = line.lineId;
        }
        _attachSelectedDepOptions();
      } else {
        ProductOption? existing;
        for (final selected in _selectedOptions.keys) {
          if (selected.id == option.id) {
            existing = selected;
            break;
          }
        }
        if (existing != null) {
          _selectedOptions[existing] = (_selectedOptions[existing] ?? 0) + 1;
        } else {
          _selectedOptions[option] = 1;
        }
      }

      _selectedMonths = null;
      if (_stepGroups.length > 1) {
        _selectedStep = null;
      }
      _updateMonthsGroups();
    });

    _emitOptionsChanged();
  }

  void _attachSelectedDepOptions() {
    void put(ProductOption? dep) {
      if (dep == null) return;
      ProductOption? existing;
      for (final selected in _selectedOptions.keys) {
        if (selected.id == dep.id) {
          existing = selected;
          break;
        }
      }
      if (existing != null) {
        _selectedOptions[existing] = (_selectedOptions[existing] ?? 0) + 1;
      } else {
        _selectedOptions[dep] = 1;
      }
    }

    put(_selectedDep1);
    put(_selectedDep2);
  }

  void _clearDepSelections() {
    _selectedDep1 = null;
    _selectedDep2 = null;
    final toRemove = _selectedOptions.keys
        .where((o) => o.isDependent)
        .toList();
    for (final o in toRemove) {
      _selectedOptions.remove(o);
    }
  }

  void _updateMainLineQuantity(_MainLineItem line, int quantity) {
    if (quantity <= 0) {
      _removeMainLine(line);
      return;
    }
    setState(() {
      line.quantity = quantity;
    });
    _emitOptionsChanged();
  }

  void _updateOptionQuantity(ProductOption option, int quantity) {
    if (quantity <= 0) {
      _removeOption(option);
      return;
    }
    setState(() {
      _selectedOptions[option] = quantity;
    });
    _emitOptionsChanged();
  }

  void _removeMainLine(_MainLineItem line) {
    setState(() {
      _mainLines.removeWhere((l) => l.lineId == line.lineId);
      _supplyLines.removeWhere((l) => l.attachedMainLineId == line.lineId);
      if (_latestMainLineId == line.lineId) {
        _latestMainLineId =
            _mainLines.isNotEmpty ? _mainLines.last.lineId : null;
      }
      if (!_hasMainSelection) {
        _clearDepSelections();
        _supplyLines.clear();
        _latestMainLineId = null;
      }
    });
    _emitOptionsChanged();
    _notifySupplyChanged();
  }

  void _removeOption(ProductOption option) {
    if (option.isMain || option.ioType == 0) {
      _MainLineItem? line;
      for (final l in _mainLines) {
        if (l.option.id == option.id) {
          line = l;
          break;
        }
      }
      if (line != null) {
        _removeMainLine(line);
        return;
      }
    }
    setState(() {
      _selectedOptions.remove(option);
    });
    _emitOptionsChanged();
  }

  int _linePriceForOption(ProductOption option, int quantity) {
    if (option.ioType == 1 || option.ioType == 2 || option.ioType == 3) {
      return option.price * quantity;
    }
    return (widget.basePrice + option.price) * quantity;
  }

  int _calculateTotalPrice() {
    int total = 0;
    for (final line in _mainLines) {
      total += _linePriceForOption(line.option, line.quantity);
    }
    _selectedOptions.forEach((option, quantity) {
      if (option.isDependent) {
        total += _linePriceForOption(option, quantity);
      }
    });
    for (final line in _supplyLines) {
      final optPrice = line.option?.price ?? 0;
      total += (line.basePrice + optPrice) * line.quantity;
    }
    return total;
  }

  int _calculateTotalQuantity() {
    final mainQty =
        _mainLines.fold<int>(0, (sum, l) => sum + l.quantity);
    final depQty = _selectedOptions.entries
        .where((e) => e.key.isDependent)
        .fold<int>(0, (sum, e) => sum + e.value);
    final supplyQty =
        _supplyLines.fold<int>(0, (sum, l) => sum + l.quantity);
    return mainQty + depQty + supplyQty;
  }

  void _notifySupplyChanged() {
    widget.onSupplyLinesChanged?.call(List<SupplyCartLine>.from(_supplyLines));
  }

  void _removeSupplyLine(int index) {
    setState(() {
      if (index >= 0 && index < _supplyLines.length) {
        _supplyLines.removeAt(index);
      }
    });
    _notifySupplyChanged();
  }

  void _updateSupplyQty(int index, int qty) {
    if (index < 0 || index >= _supplyLines.length) return;
    if (qty <= 0) {
      _removeSupplyLine(index);
      return;
    }
    final old = _supplyLines[index];
    setState(() {
      _supplyLines[index] = SupplyCartLine(
        productId: old.productId,
        productName: old.productName,
        basePrice: old.basePrice,
        option: old.option,
        quantity: qty,
        attachedMainLineId: old.attachedMainLineId,
      );
    });
    _notifySupplyChanged();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(healthDp(context, 30)),
          topRight: Radius.circular(healthDp(context, 30)),
        ),
        child: Container(
          width: double.infinity,
          color: Colors.white,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.78,
            child: DraggableScrollableSheet(
              initialChildSize: 1.0,
              minChildSize: 0.7,
              maxChildSize: 1.0,
              builder: (context, scrollController) {
                final sheetPadding = healthDp(context, 30);
                return Padding(
                  padding: EdgeInsets.fromLTRB(
                    sheetPadding,
                    healthDp(context, 10),
                    sheetPadding,
                    sheetPadding,
                  ),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: healthDp(context, 40),
                          height: healthDp(context, 4),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius:
                                BorderRadius.circular(healthDp(context, 2)),
                          ),
                        ),
                      ),
                      SizedBox(height: healthDp(context, 20)),
                      Expanded(
                        child: SingleChildScrollView(
                          controller: scrollController,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSelectionFields(),
                              if (_mainLines.isNotEmpty ||
                                  _selectedOptions.isNotEmpty ||
                                  _supplyLines.isNotEmpty) ...[
                                SizedBox(height: healthDp(context, 20)),
                                Divider(
                                  height: healthDp(context, 1),
                                  thickness: healthDp(context, 1),
                                  color: Colors.grey[300],
                                ),
                                SizedBox(height: healthDp(context, 20)),
                                _buildGroupedSelectionList(),
                                _buildTotalAmountSection(),
                              ],
                            ],
                          ),
                        ),
                      ),
                      _buildBottomActions(),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalAmountSection() {
    final totalQty = _calculateTotalQuantity();
    final totalPrice = _formatPrice(_calculateTotalPrice());
    final letterSpacing = healthSp(context, -1.44);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: healthDp(context, 20)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '총 ',
                      style: TextStyle(
                        color: const Color(0xFF1A1A1E),
                        fontSize: healthSp(context, 16),
                        fontFamily: _kGmarketSans,
                        fontWeight: FontWeight.w500,
                        letterSpacing: letterSpacing,
                      ),
                    ),
                    TextSpan(
                      text: '$totalQty',
                      style: TextStyle(
                        color: const Color(0xFFFF5A8D),
                        fontSize: healthSp(context, 16),
                        fontFamily: _kGmarketSans,
                        fontWeight: FontWeight.w500,
                        letterSpacing: letterSpacing,
                      ),
                    ),
                    TextSpan(
                      text: '개',
                      style: TextStyle(
                        color: const Color(0xFF1A1A1E),
                        fontSize: healthSp(context, 16),
                        fontFamily: _kGmarketSans,
                        fontWeight: FontWeight.w500,
                        letterSpacing: letterSpacing,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '총금액',
                    style: TextStyle(
                      color: const Color(0xFF1A1A1E),
                      fontSize: healthSp(context, 16),
                      fontFamily: _kGmarketSans,
                      fontWeight: FontWeight.w500,
                      letterSpacing: letterSpacing,
                    ),
                  ),
                  SizedBox(width: healthDp(context, 8)),
                  Text(
                    '${totalPrice}원',
                    style: TextStyle(
                      color: const Color(0xFFFF5A8D),
                      fontSize: healthSp(context, 20),
                      fontFamily: _kGmarketSans,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (widget.userPoint != null) ...[
            SizedBox(height: healthDp(context, 8)),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '보유 포인트 ${_formatPrice(widget.userPoint!)}P',
                style: TextStyle(
                  fontSize: healthSp(context, 12),
                  fontFamily: _kGmarketSans,
                  color: Colors.black,
                  fontWeight: FontWeight.w300,
                  letterSpacing: healthSp(context, -1.08),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelectionFields() {
    final dropdownHeight = healthDp(context, 40);

    final dep1Label =
        widget.product?.depOption1Label?.trim().isNotEmpty == true
            ? widget.product!.depOption1Label!
            : (widget.product?.depOption1Subject?.trim().isNotEmpty == true
                ? widget.product!.depOption1Subject!
                : '추가 선택 1');
    final dep2Label =
        widget.product?.depOption2Label?.trim().isNotEmpty == true
            ? widget.product!.depOption2Label!
            : (widget.product?.depOption2Subject?.trim().isNotEmpty == true
                ? widget.product!.depOption2Subject!
                : '추가 선택 2');

    final hasSingleSubjectFlow = _stepGroups.length <= 1;
    final monthsItems = _monthsGroups.map((months) {
      final option = _groupedOptionsByMonths[months]?.first;
      if (option == null) return '$months개월';
      final discount = _extractDiscountSuffix(option);
      final base =
          discount != null ? '$months개월 $discount' : '$months개월';
      if (option.price <= 0) return base;
      return '$base (+${option.formattedPrice.replaceAll('원', '')})';
    }).toList();

    final axis2Items = _axis2Groups.map((axis2) {
      final option = _groupedOptionsByAxis2[axis2]?.first;
      if (option == null) return axis2;
      if (option.price <= 0) return axis2;
      return '$axis2 (+${option.formattedPrice.replaceAll('원', '')})';
    }).toList();

    // 1) chr(30) 다축  2) N개월 계층  3) 평면
    final List<Widget> mainOptionFields;
    if (_usesAxisDelimiter) {
      mainOptionFields = [
        DropdownBtn(
          items: _stepGroups,
          value: _selectedStep ?? '',
          emptyText: widget.stepLabel == '다이어트환 단계'
              ? '옵션 선택'
              : widget.stepLabel,
          buttonHeight: dropdownHeight,
          itemFontSizeBase: 15.54,
          itemTextAlign: TextAlign.left,
          scrollWhenItemCountExceeds: 6,
          maxVisibleItemsWhenScrolling: 5.5,
          onChanged: (step) {
            setState(() {
              _selectedStep = step;
              _selectedAxis2 = null;
              _clearDepSelections();
              _updateAxis2Groups();
            });
            // 하위 축이 1개면 바로 담기
            if (_axis2Groups.length == 1) {
              final only = _groupedOptionsByAxis2[_axis2Groups.first]?.first;
              if (only != null) {
                setState(() => _selectedAxis2 = _axis2Groups.first);
                _addOption(only);
              }
            } else {
              _emitOptionsChanged();
            }
          },
        ),
        if (_axis2Groups.isNotEmpty) ...[
          SizedBox(height: healthDp(context, 8)),
          DropdownBtn(
            items: axis2Items,
            value: _selectedAxis2 != null
                ? (_axis2Groups.contains(_selectedAxis2)
                    ? axis2Items[_axis2Groups.indexOf(_selectedAxis2!)]
                    : '')
                : '',
            emptyText: widget.monthsLabel == '처방 개월수'
                ? '세부 옵션 선택'
                : widget.monthsLabel,
            enabled: _isAxis2Enabled || hasSingleSubjectFlow,
            buttonHeight: dropdownHeight,
            itemFontSizeBase: 15.54,
            itemTextAlign: TextAlign.left,
            scrollWhenItemCountExceeds: 6,
            maxVisibleItemsWhenScrolling: 5.5,
            onChanged: (label) {
              final idx = axis2Items.indexOf(label);
              if (idx < 0 || idx >= _axis2Groups.length) return;
              final axis2 = _axis2Groups[idx];
              final option = _groupedOptionsByAxis2[axis2]?.first;
              if (option == null) return;
              setState(() => _selectedAxis2 = axis2);
              _addOption(option);
            },
          ),
        ],
      ];
    } else if (!_usesMonthsHierarchy) {
      final flat = _mainSelectableOptions;
      final flatLabels = flat.map((o) {
        final label = o.displayText.isNotEmpty ? o.displayText : o.id;
        if (o.price <= 0) return label;
        return '$label (+${o.formattedPrice.replaceAll('원', '')})';
      }).toList();
      String selectedLabel = '';
      if (_mainLines.isNotEmpty) {
        final cur = _mainLines.last.option;
        final idx = flat.indexWhere((o) => o.id == cur.id);
        if (idx >= 0) selectedLabel = flatLabels[idx];
      }
      mainOptionFields = [
        DropdownBtn(
          items: flatLabels,
          value: selectedLabel,
          emptyText: widget.stepLabel == '다이어트환 단계'
              ? '옵션 선택'
              : widget.stepLabel,
          buttonHeight: dropdownHeight,
          itemFontSizeBase: 15.54,
          itemTextAlign: TextAlign.left,
          scrollWhenItemCountExceeds: 6,
          maxVisibleItemsWhenScrolling: 5.5,
          onChanged: (label) {
            final idx = flatLabels.indexOf(label);
            if (idx < 0 || idx >= flat.length) return;
            _addOption(flat[idx]);
          },
        ),
      ];
    } else {
      mainOptionFields = [
        if (_stepGroups.length > 1) ...[
          DropdownBtn(
            items: _stepGroups,
            value: _selectedStep ?? '',
            emptyText: widget.stepLabel,
            buttonHeight: dropdownHeight,
            itemFontSizeBase: 15.54,
            itemTextAlign: TextAlign.left,
            scrollWhenItemCountExceeds: 6,
            maxVisibleItemsWhenScrolling: 5.5,
            onChanged: (step) {
              setState(() {
                _selectedStep = step;
                _selectedMonths = null;
                _clearDepSelections();
                _updateMonthsGroups();
              });
              _emitOptionsChanged();
            },
          ),
          SizedBox(height: healthDp(context, 8)),
        ],
        DropdownBtn(
          items: monthsItems,
          value: _selectedMonths != null ? '${_selectedMonths}개월' : '',
          emptyText: widget.monthsLabel,
          enabled: _isMonthsEnabled || hasSingleSubjectFlow,
          buttonHeight: dropdownHeight,
          itemFontSizeBase: 15.54,
          itemTextAlign: TextAlign.left,
          scrollWhenItemCountExceeds: 6,
          maxVisibleItemsWhenScrolling: 5.5,
          onChanged: (label) {
            final monthsMatch = RegExp(r'^(\d+)').firstMatch(label);
            if (monthsMatch == null) return;
            final months = int.parse(monthsMatch.group(1)!);
            final option = _groupedOptionsByMonths[months]?.first;
            if (option == null) return;
            setState(() => _selectedMonths = months);
            _addOption(option);
          },
        ),
      ];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...mainOptionFields,
        if (_dep1Options.isNotEmpty) ...[
          SizedBox(height: healthDp(context, 8)),
          DropdownBtn(
            items: _dep1Options.map((o) => o.displayText).toList(),
            value: _selectedDep1?.displayText ?? '',
            emptyText: dep1Label,
            enabled: _hasMainSelection,
            buttonHeight: dropdownHeight,
            itemFontSizeBase: 15.54,
            itemTextAlign: TextAlign.left,
            scrollWhenItemCountExceeds: 6,
            maxVisibleItemsWhenScrolling: 5.5,
            onChanged: (label) {
              ProductOption? found;
              for (final o in _dep1Options) {
                if (o.displayText == label) {
                  found = o;
                  break;
                }
              }
              if (found == null) return;
              setState(() => _selectedDep1 = found);
              if (_hasMainSelection) {
                setState(() {
                  _selectedOptions[found!] =
                      (_selectedOptions[found] ?? 0) + 1;
                });
                _emitOptionsChanged();
              }
            },
          ),
        ],
        if (_dep2Options.isNotEmpty) ...[
          SizedBox(height: healthDp(context, 8)),
          DropdownBtn(
            items: _dep2Options.map((o) => o.displayText).toList(),
            value: _selectedDep2?.displayText ?? '',
            emptyText: dep2Label,
            enabled: _hasMainSelection,
            buttonHeight: dropdownHeight,
            itemFontSizeBase: 15.54,
            itemTextAlign: TextAlign.left,
            scrollWhenItemCountExceeds: 6,
            maxVisibleItemsWhenScrolling: 5.5,
            onChanged: (label) {
              ProductOption? found;
              for (final o in _dep2Options) {
                if (o.displayText == label) {
                  found = o;
                  break;
                }
              }
              if (found == null) return;
              setState(() => _selectedDep2 = found);
              if (_hasMainSelection) {
                setState(() {
                  _selectedOptions[found!] =
                      (_selectedOptions[found] ?? 0) + 1;
                });
                _emitOptionsChanged();
              }
            },
          ),
        ],
        if (_supplyProducts.isNotEmpty || _supplyLoading) ...[
          SizedBox(height: healthDp(context, 16)),
          Padding(
            padding: EdgeInsets.only(
              left: healthDp(context, 2),
              bottom: healthDp(context, 4),
            ),
            child: Text(
              '추가 상품',
              style: _optionLabelTextStyle(context),
            ),
          ),
          if (!_hasMainSelection)
            Padding(
              padding: EdgeInsets.only(bottom: healthDp(context, 4)),
              child: Text(
                '본상품 옵션을 먼저 선택해 주세요.',
                style: TextStyle(
                  color: const Color(0xFF898686),
                  fontSize: healthSp(context, 12),
                  fontFamily: _kGmarketSans,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
          if (_supplyLoading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: healthDp(context, 8)),
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else ...[
            // 추가상품 2개 이상일 때만 상품 선택 드롭다운
            if (_showSupplyProductPicker) ...[
              DropdownBtn(
                items: _supplyProducts.map((p) => p.name).toList(),
                value: _pickedSupplyProduct?.name ?? '',
                emptyText: '상품 선택',
                enabled: _hasMainSelection,
                buttonHeight: dropdownHeight,
                itemFontSizeBase: 15.54,
                itemTextAlign: TextAlign.left,
                scrollWhenItemCountExceeds: 5,
                maxVisibleItemsWhenScrolling: 4.5,
                onChanged: (name) {
                  if (!_hasMainSelection) return;
                  Product? found;
                  for (final p in _supplyProducts) {
                    if (p.name == name) {
                      found = p;
                      break;
                    }
                  }
                  if (found == null) return;
                  _onSupplyProductPicked(found);
                },
              ),
              SizedBox(height: healthDp(context, 8)),
            ],
            if (_hasMainSelection && _pickedSupplyProduct != null)
              ..._buildSupplyOptionFields(
                dropdownHeight: dropdownHeight,
              ),
          ],
        ],
      ],
    );
  }

  /// 추가상품 옵션: 상위/하위가 있으면 드롭다운 분리, 없으면 단일 선택
  List<Widget> _buildSupplyOptionFields({required double dropdownHeight}) {
    if (_pickedSupplyOptions.isEmpty) {
      return [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _addSupplyLine,
            child: const Text('추가 상품 담기'),
          ),
        ),
      ];
    }

    final widgets = <Widget>[];
    final hasSingleStep = _supplyStepGroups.length <= 1;
    final hasMonths = _supplyMonthsGroups.isNotEmpty;
    final subOptions = _supplySubOptionsForStep;

    // 상위 옵션이 2개 이상이면 상위 드롭다운
    if (_supplyStepGroups.length > 1) {
      widgets.add(
        DropdownBtn(
          items: _supplyStepGroups,
          value: _supplySelectedStep ?? '',
          emptyText: _supplyStepLabel,
          buttonHeight: dropdownHeight,
          itemFontSizeBase: 15.54,
          itemTextAlign: TextAlign.left,
          scrollWhenItemCountExceeds: 5,
          maxVisibleItemsWhenScrolling: 4.5,
          onChanged: (label) {
            if (!_supplyStepGroups.contains(label)) return;
            setState(() {
              _supplySelectedStep = label;
              _supplySelectedMonths = null;
              _pickedSupplyOption = null;
              _updateSupplyMonthsGroups();
            });
            // 하위(개월/세부)가 없고 해당 상위 옵션이 1개면 바로 담기
            final stepOpts = _supplyGroupedByStep[label] ?? const [];
            if (_supplyMonthsGroups.isEmpty && stepOpts.length == 1) {
              _addSupplyLineFromOption(stepOpts.first);
            }
          },
        ),
      );
      widgets.add(SizedBox(height: healthDp(context, 8)));
    }

    // 하위(개월) 옵션이 있으면 개월 드롭다운
    if (hasMonths) {
      final monthsItems = _supplyMonthsGroups.map((months) {
        final option = _supplyGroupedByMonths[months]?.first;
        if (option == null) return '$months개월';
        final discount = _extractDiscountSuffix(option);
        final base =
            discount != null ? '$months개월 $discount' : '$months개월';
        if (option.price <= 0) return base;
        return '$base (+${option.formattedPrice.replaceAll('원', '')})';
      }).toList();

      widgets.add(
        DropdownBtn(
          items: monthsItems,
          value: _supplySelectedMonths != null
              ? '${_supplySelectedMonths}개월'
              : '',
          emptyText: _supplyMonthsLabel,
          enabled: _supplyMonthsEnabled || hasSingleStep,
          buttonHeight: dropdownHeight,
          itemFontSizeBase: 15.54,
          itemTextAlign: TextAlign.left,
          scrollWhenItemCountExceeds: 5,
          maxVisibleItemsWhenScrolling: 4.5,
          onChanged: (label) {
            final monthsMatch = RegExp(r'^(\d+)').firstMatch(label);
            if (monthsMatch == null) return;
            final months = int.parse(monthsMatch.group(1)!);
            final option = _supplyGroupedByMonths[months]?.first;
            if (option == null) return;
            setState(() => _supplySelectedMonths = months);
            _addSupplyLineFromOption(option);
          },
        ),
      );
      // 두 번째 옵션 드롭다운용 스크롤 여유 (보유포인트 아래가 아니라 옵션 영역 쪽)
      widgets.add(SizedBox(height: healthDp(context, 180)));
      return widgets;
    }

    // 개월은 없지만 같은 상위 아래 세부 옵션이 여러 개면 하위 드롭다운
    if (_supplySelectedStep != null && subOptions.length > 1) {
      widgets.add(
        DropdownBtn(
          items: subOptions.map((o) {
            final text = o.subOption.isNotEmpty ? o.subOption : o.displayText;
            if (o.price <= 0) return text;
            return '$text (+${o.formattedPrice.replaceAll('원', '')})';
          }).toList(),
          value: _pickedSupplyOption == null
              ? ''
              : (_pickedSupplyOption!.subOption.isNotEmpty
                  ? _pickedSupplyOption!.subOption
                  : _pickedSupplyOption!.displayText),
          emptyText: _supplyMonthsLabel,
          buttonHeight: dropdownHeight,
          itemFontSizeBase: 15.54,
          itemTextAlign: TextAlign.left,
          scrollWhenItemCountExceeds: 5,
          maxVisibleItemsWhenScrolling: 4.5,
          onChanged: (label) {
            ProductOption? found;
            for (final o in subOptions) {
              final text =
                  o.subOption.isNotEmpty ? o.subOption : o.displayText;
              if (label.startsWith(text) || label == text) {
                found = o;
                break;
              }
            }
            if (found == null) return;
            _addSupplyLineFromOption(found);
          },
        ),
      );
      widgets.add(SizedBox(height: healthDp(context, 180)));
      return widgets;
    }

    // 상위만 여러 개이고 하위가 없으면: 상위 선택 시 바로 담기 (onChanged에서 처리)
    if (_supplyStepGroups.length > 1) {
      return widgets;
    }

    // 단일 옵션: 옵션 선택 드롭다운 1개
    if (subOptions.length == 1) {
      final only = subOptions.first;
      widgets.add(
        DropdownBtn(
          items: [only.displayText],
          value: '',
          emptyText: _supplyStepLabel,
          buttonHeight: dropdownHeight,
          itemFontSizeBase: 15.54,
          itemTextAlign: TextAlign.left,
          scrollWhenItemCountExceeds: 5,
          maxVisibleItemsWhenScrolling: 4.5,
          onChanged: (_) => _addSupplyLineFromOption(only),
        ),
      );
      return widgets;
    }

    // 비계층 폴백: 전체 옵션 단일 드롭다운
    widgets.add(
      DropdownBtn(
        items: _pickedSupplyOptions.map((o) => o.displayText).toList(),
        value: _pickedSupplyOption?.displayText ?? '',
        emptyText: _supplyStepLabel,
        buttonHeight: dropdownHeight,
        itemFontSizeBase: 15.54,
        itemTextAlign: TextAlign.left,
        scrollWhenItemCountExceeds: 5,
        maxVisibleItemsWhenScrolling: 4.5,
        onChanged: (label) {
          ProductOption? found;
          for (final o in _pickedSupplyOptions) {
            if (o.displayText == label) {
              found = o;
              break;
            }
          }
          if (found == null) return;
          _addSupplyLineFromOption(found);
        },
      ),
    );

    return widgets;
  }

  BorderRadius _selectionCardRadius({
    required bool roundTop,
    required bool roundBottom,
  }) {
    final r = healthDp(context, 10);
    return BorderRadius.only(
      topLeft: roundTop ? Radius.circular(r) : Radius.zero,
      topRight: roundTop ? Radius.circular(r) : Radius.zero,
      bottomLeft: roundBottom ? Radius.circular(r) : Radius.zero,
      bottomRight: roundBottom ? Radius.circular(r) : Radius.zero,
    );
  }

  Widget _buildGroupedSelectionList() {
    final deps = _selectedOptions.entries
        .where((e) => e.key.isDependent)
        .toList();
    final groupGap = healthDp(context, 16);
    final usedSupplyIndexes = <int>{};
    final children = <Widget>[];

    for (var gi = 0; gi < _mainLines.length; gi++) {
      final mainLine = _mainLines[gi];
      final supplies = <MapEntry<int, SupplyCartLine>>[];
      for (var i = 0; i < _supplyLines.length; i++) {
        if (usedSupplyIndexes.contains(i)) continue;
        final line = _supplyLines[i];
        final match = line.attachedMainLineId == mainLine.lineId ||
            (line.attachedMainLineId == null && gi == _mainLines.length - 1);
        if (!match) continue;
        usedSupplyIndexes.add(i);
        supplies.add(MapEntry(i, line));
      }

      final isLastGroup = gi == _mainLines.length - 1 && deps.isEmpty;
      final hasSupplies = supplies.isNotEmpty;

      children.add(
        _buildMainLineCard(
          mainLine,
          bottomMargin: hasSupplies ? 0 : (isLastGroup ? 0 : groupGap),
          roundTop: true,
          roundBottom: !hasSupplies,
        ),
      );
      for (var si = 0; si < supplies.length; si++) {
        final entry = supplies[si];
        final isLastSupply = si == supplies.length - 1;
        children.add(
          _buildSupplyLineCard(
            entry.key,
            entry.value,
            bottomMargin:
                isLastSupply ? (isLastGroup ? 0 : groupGap) : 0,
            roundTop: false,
            roundBottom: isLastSupply,
          ),
        );
      }
    }

    for (var i = 0; i < _supplyLines.length; i++) {
      if (usedSupplyIndexes.contains(i)) continue;
      children.add(
        _buildSupplyLineCard(
          i,
          _supplyLines[i],
          bottomMargin: groupGap,
          roundTop: true,
          roundBottom: true,
        ),
      );
    }

    for (var di = 0; di < deps.length; di++) {
      final e = deps[di];
      children.add(
        _buildDepOptionCard(
          e.key,
          e.value,
          bottomMargin: di == deps.length - 1 ? 0 : groupGap,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  Widget _buildMainLineCard(
    _MainLineItem line, {
    double? bottomMargin,
    bool roundTop = true,
    bool roundBottom = true,
  }) {
    final option = line.option;
    final quantity = line.quantity;
    final lineTotal = _linePriceForOption(option, quantity);
    final valueText = _selectedOptionValueText(option);
    final discountSuffix = _extractDiscountSuffix(option);
    final pinkValue =
        (discountSuffix != null && !valueText.contains(discountSuffix))
            ? '$valueText $discountSuffix'
            : valueText;
    final title = _cardProductShortLabel(
      name: widget.product?.name,
      categoryId: widget.product?.categoryId,
      extra: widget.stepLabel,
    );
    final marginBottom = bottomMargin ?? healthDp(context, 8);

    return Container(
      margin: EdgeInsets.only(bottom: marginBottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: _selectionCardRadius(
          roundTop: roundTop,
          roundBottom: roundBottom,
        ),
        border: Border.all(color: const Color(0x7FD2D2D2)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              healthDp(context, 12),
              healthDp(context, 10),
              healthDp(context, 30),
              healthDp(context, 10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSelectedCardTitleBlock(
                  title: title,
                  optionLine: pinkValue,
                ),
                SizedBox(height: healthDp(context, 10)),
                Row(
                  children: [
                    _buildQuantityControl(
                      quantity: quantity,
                      compact: true,
                      onDecrease: quantity > 1
                          ? () => _updateMainLineQuantity(line, quantity - 1)
                          : null,
                      onIncrease: () =>
                          _updateMainLineQuantity(line, quantity + 1),
                    ),
                    const Spacer(),
                    Text(
                      '${_formatPrice(lineTotal)}원',
                      style: TextStyle(
                        fontSize: healthSp(context, 14),
                        fontFamily: _kGmarketSans,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: healthDp(context, 6),
            right: healthDp(context, 6),
            child: InkWell(
              onTap: () => _removeMainLine(line),
              borderRadius: BorderRadius.circular(healthDp(context, 4)),
              child: Padding(
                padding: EdgeInsets.all(healthDp(context, 2)),
                child: Icon(
                  Icons.close,
                  size: healthDp(context, 16),
                  color: Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepOptionCard(
    ProductOption option,
    int quantity, {
    double? bottomMargin,
  }) {
    final lineTotal = _linePriceForOption(option, quantity);
    final valueText = _selectedOptionValueText(option);
    final title = option.isDep1
        ? (widget.product?.depOption1Label ?? '추가선택1')
        : (widget.product?.depOption2Label ?? '추가선택2');
    final marginBottom = bottomMargin ?? healthDp(context, 8);

    return Container(
      margin: EdgeInsets.only(bottom: marginBottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
        border: Border.all(color: const Color(0x7FD2D2D2)),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              healthDp(context, 12),
              healthDp(context, 10),
              healthDp(context, 30),
              healthDp(context, 10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSelectedCardTitleBlock(
                  title: title,
                  optionLine: valueText,
                ),
                SizedBox(height: healthDp(context, 10)),
                Row(
                  children: [
                    _buildQuantityControl(
                      quantity: quantity,
                      compact: true,
                      onDecrease: quantity > 1
                          ? () => _updateOptionQuantity(option, quantity - 1)
                          : null,
                      onIncrease: () =>
                          _updateOptionQuantity(option, quantity + 1),
                    ),
                    const Spacer(),
                    Text(
                      '${_formatPrice(lineTotal)}원',
                      style: TextStyle(
                        fontSize: healthSp(context, 14),
                        fontFamily: _kGmarketSans,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: healthDp(context, 6),
            right: healthDp(context, 6),
            child: InkWell(
              onTap: () => _removeOption(option),
              borderRadius: BorderRadius.circular(healthDp(context, 4)),
              child: Padding(
                padding: EdgeInsets.all(healthDp(context, 2)),
                child: Icon(
                  Icons.close,
                  size: healthDp(context, 16),
                  color: Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 선택 카드 타이틀(상품명) + 옵션줄(자리바꿈)
  Widget _buildSelectedCardTitleBlock({
    required String title,
    required String optionLine,
  }) {
    final labelStyle = _selectedCardLabelTextStyle(context);
    final optionStyle = labelStyle.copyWith(
      color: const Color(0xFFFF4081),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: labelStyle,
          softWrap: true,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (optionLine.trim().isNotEmpty)
          Text(
            optionLine,
            style: optionStyle,
            softWrap: true,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _buildSupplyLineCard(
    int index,
    SupplyCartLine line, {
    double? bottomMargin,
    bool roundTop = true,
    bool roundBottom = true,
  }) {
    final optPrice = line.option?.price ?? 0;
    final lineTotal = (line.basePrice + optPrice) * line.quantity;
    final option = line.option;
    final valueText =
        option != null ? _selectedOptionValueText(option) : '';
    final discountSuffix =
        option != null ? _extractDiscountSuffix(option) : null;
    final pinkValue =
        (discountSuffix != null && !valueText.contains(discountSuffix))
            ? '$valueText $discountSuffix'
            : valueText;
    final title =
        '추가상품 : ${_cardProductShortLabel(name: line.productName)}';
    final marginBottom = bottomMargin ?? healthDp(context, 8);

    return Container(
      margin: EdgeInsets.only(bottom: marginBottom),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: _selectionCardRadius(
          roundTop: roundTop,
          roundBottom: roundBottom,
        ),
        border: Border.all(color: const Color(0x7FD2D2D2)),
      ),
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              healthDp(context, 12),
              healthDp(context, 10),
              healthDp(context, 30),
              healthDp(context, 10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSelectedCardTitleBlock(
                  title: title,
                  optionLine: pinkValue,
                ),
                SizedBox(height: healthDp(context, 10)),
                Row(
                  children: [
                    _buildQuantityControl(
                      quantity: line.quantity,
                      compact: true,
                      onDecrease: line.quantity > 1
                          ? () => _updateSupplyQty(index, line.quantity - 1)
                          : null,
                      onIncrease: () =>
                          _updateSupplyQty(index, line.quantity + 1),
                    ),
                    const Spacer(),
                    Text(
                      '+${_formatPrice(lineTotal)}원',
                      style: TextStyle(
                        fontSize: healthSp(context, 14),
                        fontFamily: _kGmarketSans,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: healthDp(context, 6),
            right: healthDp(context, 6),
            child: InkWell(
              onTap: () => _removeSupplyLine(index),
              borderRadius: BorderRadius.circular(healthDp(context, 4)),
              child: Padding(
                padding: EdgeInsets.all(healthDp(context, 2)),
                child: Icon(
                  Icons.close,
                  size: healthDp(context, 16),
                  color: Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoriteButton() {
    if (widget.onToggleFavorite == null) return const SizedBox.shrink();
    return Container(
      width: healthDp(context, 40),
      height: healthDp(context, 40),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(healthDp(context, 8)),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          _isFavorite ? Icons.favorite : Icons.favorite_border,
          size: healthDp(context, 22),
          color: _isFavorite ? const Color(0xFFFF4081) : Colors.grey[600],
        ),
        onPressed: () {
          setState(() => _isFavorite = !_isFavorite);
          widget.onToggleFavorite?.call();
        },
      ),
    );
  }

  ButtonStyle _sheetOutlinedButtonStyle({required bool enabled}) {
    final height = healthDp(context, 40);
    return OutlinedButton.styleFrom(
      minimumSize: Size(0, height),
      maximumSize: Size(double.infinity, height),
      fixedSize: Size.fromHeight(height),
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      foregroundColor: const Color(0xFFFF5A8D),
      disabledForegroundColor: const Color(0xFFBDBDBD),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
      ),
      side: BorderSide(
        color: enabled ? const Color(0xFFFF5A8D) : const Color(0xFFD2D2D2),
      ),
    );
  }

  ButtonStyle _sheetFilledButtonStyle() {
    final height = healthDp(context, 40);
    return ElevatedButton.styleFrom(
      minimumSize: Size(0, height),
      maximumSize: Size(double.infinity, height),
      fixedSize: Size.fromHeight(height),
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      backgroundColor: const Color(0xFFFF4081),
      foregroundColor: Colors.white,
      disabledBackgroundColor: Colors.grey[300],
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
      ),
    );
  }

  Widget _buildGeneralBottomActionRow({
    required VoidCallback? onCart,
    required VoidCallback? onBuy,
  }) {
    final cartEnabled = onCart != null;
    return Row(
      children: [
        if (widget.onToggleFavorite != null) ...[
          _buildFavoriteButton(),
          SizedBox(width: healthDp(context, 10)),
        ],
        Expanded(
          child: OutlinedButton(
            onPressed: onCart,
            style: _sheetOutlinedButtonStyle(enabled: cartEnabled),
            child: Text(
              '장바구니',
              style: TextStyle(
                fontSize: healthSp(context, 16),
                fontWeight: FontWeight.w500,
                fontFamily: _kGmarketSans,
              ),
            ),
          ),
        ),
        SizedBox(width: healthDp(context, 10)),
        Expanded(
          child: ElevatedButton(
            onPressed: onBuy,
            style: _sheetFilledButtonStyle(),
            child: Text(
              '구매하기',
              style: TextStyle(
                fontSize: healthSp(context, 16),
                fontWeight: FontWeight.w500,
                fontFamily: _kGmarketSans,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions() {
    return widget.productKind == 'general'
        ? _buildGeneralBottomActionRow(
            onCart: _canCheckout ? widget.onAddToCart : null,
            onBuy: _canCheckout ? widget.onBuyNow : null,
          )
        : Row(
            children: [
              if (widget.onToggleFavorite != null) ...[
                _buildFavoriteButton(),
                SizedBox(width: healthDp(context, 10)),
              ],
              Expanded(
                child: OutlinedButton(
                  onPressed: _canCheckout
                      ? widget.onAddToPrescriptionCart
                      : null,
                  style: _sheetOutlinedButtonStyle(
                    enabled: _canCheckout,
                  ),
                  child: Text(
                    '진료담기',
                    style: TextStyle(
                      fontSize: healthSp(context, 16),
                      fontWeight: FontWeight.w500,
                      fontFamily: _kGmarketSans,
                    ),
                  ),
                ),
              ),
              SizedBox(width: healthDp(context, 10)),
              Expanded(
                child: ElevatedButton(
                  onPressed: _canCheckout ? widget.onReserve : null,
                  style: _sheetFilledButtonStyle(),
                  child: Text(
                    '처방 예약 하기',
                    style: TextStyle(
                      fontSize: healthSp(context, 16),
                      fontWeight: FontWeight.w500,
                      fontFamily: _kGmarketSans,
                    ),
                  ),
                ),
              ),
            ],
          );
  }

  Widget _buildQuantityControl({
    required int quantity,
    required VoidCallback? onDecrease,
    required VoidCallback onIncrease,
    bool compact = false,
  }) {
    final outerPadding = healthDp(context, compact ? 3 : 4);
    final outerRadius = healthDp(context, compact ? 16 : 20);
    final qtyWidth = healthDp(context, compact ? 14 : 16);
    final qtyMargin = healthDp(context, compact ? 4 : 5);
    final qtyFontSize = healthSp(context, compact ? 10 : 12);

    return Container(
      padding: EdgeInsets.all(outerPadding),
      decoration: ShapeDecoration(
        color: const Color(0xFFF6F6F6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(outerRadius),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRoundQtyButton(
            icon: Icons.remove,
            onTap: onDecrease,
            compact: compact,
          ),
          Container(
            width: qtyWidth,
            alignment: Alignment.center,
            margin: EdgeInsets.symmetric(horizontal: qtyMargin),
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF1A1A1A),
                fontSize: qtyFontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _buildRoundQtyButton(
            icon: Icons.add,
            onTap: onIncrease,
            compact: compact,
          ),
        ],
      ),
    );
  }

  Widget _buildRoundQtyButton({
    required IconData icon,
    required VoidCallback? onTap,
    bool compact = false,
  }) {
    final buttonSize = healthDp(context, compact ? 16 : 20);
    final buttonRadius = healthDp(context, compact ? 8 : 10);
    final iconSize = healthDp(context, compact ? 11 : 13);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(buttonRadius),
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          shadows: [
            BoxShadow(
              color: const Color(0x0C000000),
              blurRadius: healthDp(context, 1.07),
              offset: Offset(0, healthDp(context, 0.54)),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: onTap == null ? Colors.grey[300] : const Color(0xFFFF5A8D),
        ),
      ),
    );
  }
}

/// 옵션 없는 일반 상품 — 수량만 선택하는 바텀시트 (비대면 옵션 시트와 동일 셸·버튼 스타일).
class GeneralQuantityBottomSheet extends StatefulWidget {
  final String productName;
  final int unitPrice;
  final int? userPoint;
  final bool isFavorite;
  final VoidCallback? onToggleFavorite;
  final Future<void> Function(int quantity) onAddToCart;
  final Future<void> Function(int quantity) onBuyNow;

  const GeneralQuantityBottomSheet({
    super.key,
    required this.productName,
    required this.unitPrice,
    this.userPoint,
    this.isFavorite = false,
    this.onToggleFavorite,
    required this.onAddToCart,
    required this.onBuyNow,
  });

  @override
  State<GeneralQuantityBottomSheet> createState() =>
      _GeneralQuantityBottomSheetState();
}

class _GeneralQuantityBottomSheetState extends State<GeneralQuantityBottomSheet> {
  int _quantity = 1;
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _isFavorite = widget.isFavorite;
  }

  int get _totalPrice => widget.unitPrice * _quantity;

  String _formatPrice(int value) {
    return value.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  @override
  Widget build(BuildContext context) {
    final sheetPadding = healthDp(context, 30);

    return SizedBox(
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(healthDp(context, 30)),
          topRight: Radius.circular(healthDp(context, 30)),
        ),
        child: Container(
          color: Colors.white,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                sheetPadding,
                healthDp(context, 10),
                sheetPadding,
                sheetPadding,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: healthDp(context, 40),
                      height: healthDp(context, 4),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius:
                            BorderRadius.circular(healthDp(context, 2)),
                      ),
                    ),
                  ),
                  SizedBox(height: healthDp(context, 20)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          widget.productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xFF1A1A1E),
                            fontSize: healthSp(context, 16),
                            fontFamily: _kGmarketSans,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      SizedBox(width: healthDp(context, 12)),
                      _GeneralQtyControl(
                        quantity: _quantity,
                        onDecrease: _quantity > 1
                            ? () => setState(() => _quantity--)
                            : null,
                        onIncrease: () => setState(() => _quantity++),
                      ),
                    ],
                  ),
                  SizedBox(height: healthDp(context, 20)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '총 구매 금액',
                        style: TextStyle(
                          fontSize: healthSp(context, 14),
                          fontFamily: _kGmarketSans,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${_formatPrice(_totalPrice)}원',
                        style: TextStyle(
                          fontSize: healthSp(context, 18),
                          fontFamily: _kGmarketSans,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFFF5A8D),
                        ),
                      ),
                    ],
                  ),
                  if (widget.userPoint != null) ...[
                    SizedBox(height: healthDp(context, 5)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '보유 포인트 ${_formatPrice(widget.userPoint!)}P',
                          style: TextStyle(
                            fontSize: healthSp(context, 12),
                            fontFamily: _kGmarketSans,
                            color: Colors.black,
                            fontWeight: FontWeight.w300,
                            letterSpacing: healthSp(context, -1.08),
                          ),
                        ),
                      ],
                    ),
                  ],
                  SizedBox(height: healthDp(context, 10)),
                  Row(
                    children: [
                      if (widget.onToggleFavorite != null) ...[
                        Container(
                          width: healthDp(context, 40),
                          height: healthDp(context, 40),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius:
                                BorderRadius.circular(healthDp(context, 8)),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(
                              _isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: healthDp(context, 22),
                              color: _isFavorite
                                  ? const Color(0xFFFF4081)
                                  : Colors.grey[600],
                            ),
                            onPressed: () {
                              setState(() => _isFavorite = !_isFavorite);
                              widget.onToggleFavorite?.call();
                            },
                          ),
                        ),
                        SizedBox(width: healthDp(context, 10)),
                      ],
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => widget.onAddToCart(_quantity),
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              vertical: healthDp(context, 10),
                              horizontal: healthDp(context, 10),
                            ),
                            foregroundColor: const Color(0xFFFF5A8D),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(healthDp(context, 10)),
                            ),
                            side: const BorderSide(color: Color(0xFFFF5A8D)),
                          ),
                          child: Text(
                            '장바구니',
                            style: TextStyle(
                              fontSize: healthSp(context, 16),
                              fontWeight: FontWeight.w500,
                              fontFamily: _kGmarketSans,
                              color: const Color(0xFFFF5A8D),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: healthDp(context, 10)),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => widget.onBuyNow(_quantity),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF4081),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              vertical: healthDp(context, 10),
                              horizontal: healthDp(context, 10),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(healthDp(context, 10)),
                            ),
                          ),
                          child: Text(
                            '구매하기',
                            style: TextStyle(
                              fontSize: healthSp(context, 16),
                              fontWeight: FontWeight.w500,
                              fontFamily: _kGmarketSans,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GeneralQtyControl extends StatelessWidget {
  final int quantity;
  final VoidCallback? onDecrease;
  final VoidCallback onIncrease;

  const _GeneralQtyControl({
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(healthDp(context, 4)),
      decoration: ShapeDecoration(
        color: const Color(0xFFF6F6F6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(healthDp(context, 20)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GeneralQtyButton(icon: Icons.remove, onTap: onDecrease),
          Container(
            width: healthDp(context, 22),
            alignment: Alignment.center,
            margin: EdgeInsets.symmetric(horizontal: healthDp(context, 6)),
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: const Color(0xFF1A1A1A),
                fontSize: healthSp(context, 14),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _GeneralQtyButton(icon: Icons.add, onTap: onIncrease),
        ],
      ),
    );
  }
}

class _GeneralQtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _GeneralQtyButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final buttonSize = healthDp(context, 22);
    final buttonRadius = healthDp(context, 14);
    final iconSize = healthDp(context, 16);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(buttonRadius),
      child: Container(
        width: buttonSize,
        height: buttonSize,
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(buttonRadius),
          ),
          shadows: [
            BoxShadow(
              color: const Color(0x0C000000),
              blurRadius: healthDp(context, 1.07),
              offset: Offset(0, healthDp(context, 0.54)),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: onTap == null ? Colors.grey[300] : const Color(0xFFFF5A8D),
        ),
      ),
    );
  }
}
