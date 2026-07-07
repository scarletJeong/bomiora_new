import 'package:flutter/material.dart';

import '../../../data/models/product/product_option_model.dart';
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
  final Function(Map<ProductOption, int>) onOptionsChanged;
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
    required this.onOptionsChanged,
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

String _extractStepShort(String step) {
  final match = RegExp(r'\[?0*(\d+)단계\]?').firstMatch(step);
  if (match != null) return '${match.group(1)}단계';
  return step.trim();
}

String? _extractDiscountSuffix(ProductOption option) {
  for (final source in [option.id, option.step, option.subOption]) {
    final match = RegExp(r'\(-\s*\d+%\s*\)').firstMatch(source);
    if (match != null) return match.group(0);
  }
  return null;
}

String _selectedOptionValueText(ProductOption option) {
  final stepShort = _extractStepShort(option.step);
  final months = option.months;
  if (months != null) {
    return '$stepShort/${months}개월';
  }
  if (option.subOption.isNotEmpty) {
    if (stepShort.isNotEmpty && stepShort != option.step) {
      return '$stepShort/${option.subOption}';
    }
    return option.subOption;
  }
  return stepShort.isNotEmpty ? stepShort : option.step;
}

class _OptionSelectorBottomSheetState extends State<OptionSelectorBottomSheet> {
  final Map<String, List<ProductOption>> _groupedOptionsByStep = {};
  final Map<int, List<ProductOption>> _groupedOptionsByMonths = {};
  final List<String> _stepGroups = [];
  final List<int> _monthsGroups = [];

  String? _selectedStep;
  int? _selectedMonths;
  late Map<ProductOption, int> _selectedOptions;
  late bool _isFavorite;

  @override
  void initState() {
    super.initState();
    _selectedOptions = Map<ProductOption, int>.from(widget.selectedOptions);
    _isFavorite = widget.isFavorite;
    _initializeGroups();
  }

  @override
  void didUpdateWidget(covariant OptionSelectorBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedOptions != widget.selectedOptions) {
      setState(() {
        _selectedOptions = Map<ProductOption, int>.from(widget.selectedOptions);
      });
    }
    if (oldWidget.isFavorite != widget.isFavorite) {
      setState(() => _isFavorite = widget.isFavorite);
    }
  }

  void _initializeGroups() {
    _groupedOptionsByStep.clear();
    _stepGroups.clear();

    for (final option in widget.options) {
      final step = option.step;
      if (!_groupedOptionsByStep.containsKey(step)) {
        _groupedOptionsByStep[step] = [];
        _stepGroups.add(step);
      }
      _groupedOptionsByStep[step]!.add(option);
    }

    if (_stepGroups.length == 1) {
      _selectedStep = _stepGroups.first;
    }
    _updateMonthsGroups();
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

  bool get _isMonthsEnabled => _selectedStep != null;

  void _addOption(ProductOption option) {
    setState(() {
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

      _selectedMonths = null;
      if (_stepGroups.length > 1) {
        _selectedStep = null;
      }
      _updateMonthsGroups();
    });

    widget.onOptionsChanged(Map<ProductOption, int>.from(_selectedOptions));
  }

  void _updateOptionQuantity(ProductOption option, int quantity) {
    if (quantity <= 0) {
      _removeOption(option);
      return;
    }
    setState(() {
      _selectedOptions[option] = quantity;
    });
    widget.onOptionsChanged(Map<ProductOption, int>.from(_selectedOptions));
  }

  void _removeOption(ProductOption option) {
    setState(() {
      _selectedOptions.remove(option);
    });
    widget.onOptionsChanged(Map<ProductOption, int>.from(_selectedOptions));
  }

  int _calculateTotalPrice() {
    int total = 0;
    _selectedOptions.forEach((option, quantity) {
      total += (widget.basePrice + option.price) * quantity;
    });
    return total;
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
          color: Colors.white,
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: DraggableScrollableSheet(
              initialChildSize: 1.0,
              minChildSize: 0.6,
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
                              if (_selectedOptions.isNotEmpty) ...[
                                SizedBox(height: healthDp(context, 20)),
                                Divider(
                                  height: healthDp(context, 1),
                                  thickness: healthDp(context, 1),
                                  color: Colors.grey[300],
                                ),
                                SizedBox(height: healthDp(context, 20)),
                                _buildSelectedOptionsList(),
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

  Widget _buildSelectionFields() {
    final hasSingleSubjectFlow = _stepGroups.length <= 1;
    final dropdownHeight = healthDp(context, 40);
    final monthsItems = _monthsGroups.map((months) {
      final option = _groupedOptionsByMonths[months]?.first;
      if (option == null) return '$months개월';
      if (option.price <= 0) return '$months개월';
      return '$months개월 (+${option.formattedPrice.replaceAll('원', '')})';
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_stepGroups.length > 1) ...[
          _buildSelectionLabel(widget.stepLabel),
          DropdownBtn(
            items: _stepGroups,
            value: _selectedStep ?? '',
            emptyText: '옵션 선택',
            buttonHeight: dropdownHeight,
            itemFontSizeBase: 15.54,
            itemTextAlign: TextAlign.left,
            onChanged: (step) {
              setState(() {
                _selectedStep = step;
                _selectedMonths = null;
                _updateMonthsGroups();
              });
            },
          ),
          SizedBox(height: healthDp(context, 8)),
        ],
        _buildSelectionLabel(widget.monthsLabel),
        DropdownBtn(
          items: monthsItems,
          value: _selectedMonths != null ? '${_selectedMonths}개월' : '',
          emptyText: _isMonthsEnabled ? '옵션 선택' : '상위 옵션 선택',
          enabled: _isMonthsEnabled || hasSingleSubjectFlow,
          buttonHeight: dropdownHeight,
          itemFontSizeBase: 15.54,
          itemTextAlign: TextAlign.left,
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
      ],
    );
  }

  Widget _buildSelectionLabel(String text) {
    return Padding(
      padding: EdgeInsets.only(
        left: healthDp(context, 2),
        bottom: healthDp(context, 4),
      ),
      child: Text(
        text,
        style: _optionLabelTextStyle(context),
      ),
    );
  }

  Widget _buildSelectedOptionsList() {
    return Column(
      children: _selectedOptions.entries.map((entry) {
        final option = entry.key;
        final quantity = entry.value;
        return _buildSelectedOptionCard(option, quantity);
      }).toList(),
    );
  }

  Widget _buildSelectedOptionCard(ProductOption option, int quantity) {
    final lineTotal = (widget.basePrice + option.price) * quantity;
    final valueText = _selectedOptionValueText(option);
    final discountSuffix = _extractDiscountSuffix(option);
    final pinkValue = discountSuffix != null
        ? '$valueText $discountSuffix'
        : valueText;

    return Container(
      margin: EdgeInsets.only(bottom: healthDp(context, 8)),
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
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: widget.stepLabel,
                        style: _selectedCardLabelTextStyle(context),
                      ),
                      TextSpan(
                        text: ' | ',
                        style: _selectedCardLabelTextStyle(context).copyWith(
                          color: const Color(0xFFBDBDBD),
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                      TextSpan(
                        text: pinkValue,
                        style: _selectedCardLabelTextStyle(context).copyWith(
                          color: const Color(0xFFFF4081),
                        ),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
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

  Widget _buildGeneralBottomActionRow({
    required VoidCallback? onCart,
    required VoidCallback? onBuy,
  }) {
    return Row(
      children: [
        if (widget.onToggleFavorite != null) ...[
          _buildFavoriteButton(),
          SizedBox(width: healthDp(context, 10)),
        ],
        Expanded(
          child: OutlinedButton(
            onPressed: onCart,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                vertical: healthDp(context, 10),
                horizontal: healthDp(context, 10),
              ),
              foregroundColor: const Color(0xFFFF5A8D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(healthDp(context, 10)),
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
            onPressed: onBuy,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF4081),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                vertical: healthDp(context, 10),
                horizontal: healthDp(context, 10),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(healthDp(context, 10)),
              ),
              disabledBackgroundColor: Colors.grey[300],
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
    );
  }

  Widget _buildBottomActions() {
    return Column(
      children: [
          if (_selectedOptions.isNotEmpty) ...[
            SizedBox(height: healthDp(context, 3)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '총 구매 금액',
                  style: TextStyle(
                    fontSize: healthSp(context, 16),
                    fontFamily: _kGmarketSans,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '${_calculateTotalPrice().toString().replaceAllMapped(
                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                        (Match m) => '${m[1]},',
                      )}원',
                  style: TextStyle(
                    fontSize: healthSp(context, 20),
                    fontFamily: _kGmarketSans,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFFFF5A8D),
                  ),
                ),
              ],
            ),
            SizedBox(height: healthDp(context, 5)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  '보유 포인트 ${(widget.userPoint ?? 0).toString().replaceAllMapped(
                        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                        (Match m) => '${m[1]},',
                      )}P',
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
          if (_selectedOptions.isNotEmpty) SizedBox(height: healthDp(context, 10)),
          widget.productKind == 'general'
              ? _buildGeneralBottomActionRow(
                  onCart:
                      _selectedOptions.isEmpty ? null : widget.onAddToCart,
                  onBuy: _selectedOptions.isEmpty ? null : widget.onBuyNow,
                )
                : Row(
                    children: [
                      if (widget.onToggleFavorite != null) ...[
                        _buildFavoriteButton(),
                        SizedBox(width: healthDp(context, 10)),
                      ],
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              _selectedOptions.isEmpty ? null : () {},
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
                            '진료담기',
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
                          onPressed: _selectedOptions.isEmpty
                              ? null
                              : widget.onReserve,
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
                            disabledBackgroundColor: Colors.grey[300],
                          ),
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
                          fontSize: healthSp(context, 16),
                          fontFamily: _kGmarketSans,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${_formatPrice(_totalPrice)}원',
                        style: TextStyle(
                          fontSize: healthSp(context, 20),
                          fontFamily: _kGmarketSans,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFFF5A8D),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: healthDp(context, 5)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '보유 포인트 ${_formatPrice(widget.userPoint ?? 0)}P',
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
