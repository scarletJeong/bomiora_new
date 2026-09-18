import 'package:flutter/material.dart';

import '../../health/health_common/health_responsive_scale.dart';
import 'dropdown_btn.dart';

/// 배송 요청사항 드롭다운 + 직접 입력 필드.
/// 주문 상세 배송지 섹션과 동일한 프리셋·스타일을 결제 화면에서도 쓴다.
class DeliveryMemoDropdown extends StatefulWidget {
  const DeliveryMemoDropdown({
    super.key,
    required this.value,
    this.onChanged,
    this.readOnly = false,
    this.showLabel = true,
    this.commitCustomOnUnfocus = true,
  });

  static const String customLabel = '직접 입력';
  static const String emptyText = '배송메모를 선택해주세요';
  static const List<String> presets = [
    '부재시 경비실에 맡겨 주세요',
    '부재시 문 앞에 놓아주세요',
    '배송 전 연락 바랍니다',
    '직접 받겠습니다',
  ];

  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _muted = Color(0xFF898686);
  static const Color _ink = Color(0xFF1A1A1E);
  static const Color _border = Color(0xFFD2D2D2);
  static const String _font = 'Gmarket Sans TTF';

  final String value;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final bool showLabel;

  /// true면 직접 입력 내용은 포커스 해제/엔터 때 [onChanged] 호출 (주문 상세).
  /// false면 입력할 때마다 호출 (결제 — 제출 직전 값 유지).
  final bool commitCustomOnUnfocus;

  static bool isCustomMemo(String memo) {
    final t = memo.trim();
    return t.isNotEmpty && !presets.contains(t);
  }

  @override
  State<DeliveryMemoDropdown> createState() => _DeliveryMemoDropdownState();
}

class _DeliveryMemoDropdownState extends State<DeliveryMemoDropdown> {
  late final TextEditingController _customController;
  late final FocusNode _customFocusNode;
  late bool _isCustom;
  bool _customDirty = false;
  bool _customFocused = false;

  @override
  void initState() {
    super.initState();
    _isCustom = DeliveryMemoDropdown.isCustomMemo(widget.value);
    _customController = TextEditingController(
      text: _isCustom ? widget.value : '',
    );
    _customFocusNode = FocusNode();
    _customFocusNode.addListener(_onCustomFocus);
  }

  @override
  void didUpdateWidget(DeliveryMemoDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == widget.value) return;
    final custom = DeliveryMemoDropdown.isCustomMemo(widget.value);
    _isCustom = custom;
    _customDirty = false;
    final nextText = custom ? widget.value : '';
    if (_customController.text != nextText) {
      _customController.text = nextText;
    }
  }

  void _onCustomFocus() {
    final focused = _customFocusNode.hasFocus;
    if (_customFocused != focused) {
      setState(() => _customFocused = focused);
    }
    if (!focused) _flushCustomMemo();
  }

  void _flushCustomMemo() {
    if (!_isCustom || !_customDirty) return;
    _customDirty = false;
    widget.onChanged?.call(_customController.text.trim());
  }

  void _onPresetChanged(String value) {
    if (value == DeliveryMemoDropdown.customLabel) {
      setState(() {
        _isCustom = true;
        if (DeliveryMemoDropdown.presets.contains(widget.value.trim())) {
          _customController.clear();
          _customDirty = false;
        } else {
          _customController.text = widget.value;
        }
      });
      return;
    }
    setState(() {
      _isCustom = false;
      _customDirty = false;
    });
    widget.onChanged?.call(value);
  }

  @override
  void dispose() {
    _customFocusNode.removeListener(_onCustomFocus);
    _customFocusNode.dispose();
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final memo = widget.value.trim();
    final dropdownValue = _isCustom
        ? DeliveryMemoDropdown.customLabel
        : (DeliveryMemoDropdown.presets.contains(memo) ? memo : '');
    final memoItems = [
      ...DeliveryMemoDropdown.presets,
      DeliveryMemoDropdown.customLabel,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showLabel) ...[
          Text(
            '배송 요청 사항',
            style: TextStyle(
              color: DeliveryMemoDropdown._muted,
              fontSize: healthSp(context, 12),
              fontFamily: DeliveryMemoDropdown._font,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: healthDp(context, 5)),
        ],
        if (widget.readOnly || widget.onChanged == null)
          _readOnlyBox(context, memo)
        else ...[
          DropdownBtn(
            buttonHeight: healthDp(context, 45),
            items: memoItems,
            value: dropdownValue,
            emptyText: DeliveryMemoDropdown.emptyText,
            emptyTextColor: DeliveryMemoDropdown._muted,
            valueTextColor: DeliveryMemoDropdown._ink,
            borderColor: DeliveryMemoDropdown._border,
            itemFontSizeBase: 12,
            itemTextAlign: TextAlign.left,
            onChanged: _onPresetChanged,
          ),
          if (_isCustom) ...[
            SizedBox(height: healthDp(context, 10)),
            _customField(context),
          ],
        ],
      ],
    );
  }

  Widget _readOnlyBox(BuildContext context, String memo) {
    return Container(
      width: double.infinity,
      height: healthDp(context, 45),
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
      alignment: Alignment.centerLeft,
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1),
            color: DeliveryMemoDropdown._border,
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
        ),
      ),
      child: Text(
        memo.isEmpty ? '-' : memo,
        style: TextStyle(
          color: DeliveryMemoDropdown._ink,
          fontSize: healthSp(context, 12),
          fontFamily: DeliveryMemoDropdown._font,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _customField(BuildContext context) {
    return Container(
      width: double.infinity,
      height: healthDp(context, 45),
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
      alignment: Alignment.centerLeft,
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1),
            color: _customFocused
                ? DeliveryMemoDropdown._pink
                : DeliveryMemoDropdown._border,
          ),
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
        ),
      ),
      child: TextField(
        controller: _customController,
        focusNode: _customFocusNode,
        cursorColor: const Color(0xFF1A1A1A),
        textAlignVertical: TextAlignVertical.center,
        style: TextStyle(
          color: DeliveryMemoDropdown._ink,
          fontSize: healthSp(context, 12),
          fontFamily: DeliveryMemoDropdown._font,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          hintText: '배송 요청사항을 입력해 주세요.',
          hintStyle: TextStyle(
            color: DeliveryMemoDropdown._muted,
            fontSize: healthSp(context, 12),
            fontFamily: DeliveryMemoDropdown._font,
            fontWeight: FontWeight.w300,
            height: 1.2,
          ),
        ),
        onChanged: (text) {
          _customDirty = true;
          if (!widget.commitCustomOnUnfocus) {
            widget.onChanged?.call(text.trim());
          }
        },
        onSubmitted: (_) => _flushCustomMemo(),
      ),
    );
  }
}
