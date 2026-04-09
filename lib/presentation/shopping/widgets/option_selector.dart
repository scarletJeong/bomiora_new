import 'package:flutter/material.dart';

import '../../../data/models/product/product_option_model.dart';

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
  final VoidCallback onReserve;
  final VoidCallback onBuyNow;

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
    required this.onReserve,
    required this.onBuyNow,
  });

  @override
  State<OptionSelectorBottomSheet> createState() =>
      _OptionSelectorBottomSheetState();
}

enum _ExpandedType { step, months }

class _OptionSelectorBottomSheetState extends State<OptionSelectorBottomSheet> {
  final Map<String, List<ProductOption>> _groupedOptionsByStep = {};
  final Map<int, List<ProductOption>> _groupedOptionsByMonths = {};
  final List<String> _stepGroups = [];
  final List<int> _monthsGroups = [];

  String? _selectedStep;
  int? _selectedMonths;
  _ExpandedType? _expandedType;
  late Map<ProductOption, int> _selectedOptions;

  @override
  void initState() {
    super.initState();
    _selectedOptions = Map<ProductOption, int>.from(widget.selectedOptions);
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
      _expandedType = null;
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
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(30),
        topRight: Radius.circular(30),
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
              return Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSelectionFields(),
                          if (_expandedType != null) ...[
                            const SizedBox(height: 6),
                            _buildExpandedOptionsList(),
                          ],
                          if (_selectedOptions.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 8),
                            _buildSelectedOptionsList(),
                          ],
                        ],
                      ),
                    ),
                  ),
                  _buildBottomActions(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionFields() {
    final hasSingleSubjectFlow = _stepGroups.length <= 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_stepGroups.length > 1) ...[
          _buildSelectionLabel(widget.stepLabel),
          _buildSelectionField(
            text: _selectedStep ?? '옵션 선택',
            enabled: true,
            expanded: _expandedType == _ExpandedType.step,
            onTap: () {
              setState(() {
                _expandedType = _expandedType == _ExpandedType.step
                    ? null
                    : _ExpandedType.step;
              });
            },
          ),
          const SizedBox(height: 2),
        ],
        _buildSelectionLabel(widget.monthsLabel),
        _buildSelectionField(
          text: _selectedMonths != null
              ? '${_selectedMonths}개월'
              : (_isMonthsEnabled ? '옵션 선택' : '상위 옵션 선택'),
          enabled: _isMonthsEnabled || hasSingleSubjectFlow,
          expanded: _expandedType == _ExpandedType.months,
          onTap: (_isMonthsEnabled || hasSingleSubjectFlow)
              ? () {
                  setState(() {
                    _expandedType = _expandedType == _ExpandedType.months
                        ? null
                        : _ExpandedType.months;
                  });
                }
              : null,
        ),
      ],
    );
  }

  Widget _buildSelectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildSelectionField({
    required String text,
    required bool enabled,
    required bool expanded,
    required VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: enabled ? Colors.grey[300]! : Colors.grey[200]!,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: onTap,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  color: enabled ? Colors.black87 : Colors.grey[400],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: enabled ? Colors.grey[700] : Colors.grey[350],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedOptionsList() {
    if (_expandedType == _ExpandedType.step) {
      return Column(
        children: _stepGroups.map((step) {
          final isSelected = _selectedStep == step;
          return InkWell(
            onTap: () {
              setState(() {
                _selectedStep = step;
                _selectedMonths = null;
                _expandedType = null;
                _updateMonthsGroups();
              });
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color:
                      isSelected ? const Color(0xFFFF4081) : Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    step,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFFFF4081),
                      size: 18,
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    }

    return Column(
      children: _monthsGroups.map((months) {
        final optionForMonths = _groupedOptionsByMonths[months]?.first;
        if (optionForMonths == null) return const SizedBox.shrink();
        final isSelected = _selectedMonths == months;
        return InkWell(
          onTap: () {
            setState(() {
              _selectedMonths = months;
            });
            _addOption(optionForMonths);
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? const Color(0xFFFF4081) : Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${months}개월',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                Row(
                  children: [
                    if (optionForMonths.price > 0)
                      Text(
                        '+${optionForMonths.formattedPrice.replaceAll('원', '')}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    if (isSelected) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFFFF4081),
                        size: 18,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSelectedOptionsList() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: _selectedOptions.entries.map((entry) {
          final option = entry.key;
          final quantity = entry.value;
          final itemPrice = option.price * quantity;
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 22),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option.displayText,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            _buildQuantityControl(
                              quantity: quantity,
                              onDecrease: quantity > 1
                                  ? () => _updateOptionQuantity(
                                      option, quantity - 1)
                                  : null,
                              onIncrease: () =>
                                  _updateOptionQuantity(option, quantity + 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '+${itemPrice.toString().replaceAllMapped(
                              RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                              (Match m) => '${m[1]},',
                            )}원',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[800],
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: IconButton(
                    onPressed: () => _removeOption(option),
                    icon: const Icon(Icons.close, size: 17),
                    padding: const EdgeInsets.all(2),
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          if (_selectedOptions.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '총 결제금액',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${_calculateTotalPrice().toString().replaceAllMapped(
                          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                          (Match m) => '${m[1]},',
                        )}원',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFFF4081),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '보유 포인트 ${(widget.userPoint ?? 0).toString().replaceAllMapped(
                          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                          (Match m) => '${m[1]},',
                        )}P',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
          Padding(
            padding: const EdgeInsets.all(16),
            child: widget.productKind == 'general'
                ? Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _selectedOptions.isEmpty
                              ? null
                              : widget.onAddToCart,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            side: BorderSide(color: Colors.grey[300]!),
                          ),
                          child: const Text(
                            '장바구니',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed:
                              _selectedOptions.isEmpty ? null : widget.onBuyNow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF4081),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            disabledBackgroundColor: Colors.grey[300],
                          ),
                          child: const Text(
                            '구매하기',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : ElevatedButton(
                    onPressed:
                        _selectedOptions.isEmpty ? null : widget.onReserve,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF4081),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: const SizedBox(
                      width: double.infinity,
                      child: Text(
                        '처방예약하기',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityControl({
    required int quantity,
    required VoidCallback? onDecrease,
    required VoidCallback onIncrease,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(
        color: const Color(0xFFF6F6F6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRoundQtyButton(icon: Icons.remove, onTap: onDecrease),
          Container(
            width: 16,
            alignment: Alignment.center,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          _buildRoundQtyButton(icon: Icons.add, onTap: onIncrease),
        ],
      ),
    );
  }

  Widget _buildRoundQtyButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 20,
        height: 20,
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          shadows: const [
            BoxShadow(
              color: Color(0x0C000000),
              blurRadius: 1.07,
              offset: Offset(0, 0.54),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 13,
          color: onTap == null ? Colors.grey[300] : const Color(0xFFFF5A8D),
        ),
      ),
    );
  }
}
