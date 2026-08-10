import 'dart:ui';

import 'package:flutter/material.dart';

import '../../health/health_common/health_responsive_scale.dart';

class DropdownBtn extends StatefulWidget {
  static OverlayEntry? _sharedOverlayEntry;

  final List<String> items;
  final String value;
  final ValueChanged<String> onChanged;
  final double buttonHeight;
  /// [scrollWhenItemCountExceeds] 미사용 시 패널 최대 높이(px)
  final double? panelMaxHeight;
  final String emptyText;
  final bool enabled;
  /// 375 기준 글자 크기 ([healthSp]로 스케일)
  final double itemFontSizeBase;
  final TextAlign itemTextAlign;
  final Widget? Function(String item)? leadingBuilder;
  /// 375 기준 간격 ([healthDp]로 스케일)
  final double itemLeadingGapBase;
  final EdgeInsetsGeometry? itemPadding;
  /// 미선택(플레이스홀더) 텍스트 색 — null이면 `#898686`
  final Color? emptyTextColor;
  /// 선택된 값 텍스트 색 — null이면 `#1A1A1A`
  final Color? valueTextColor;
  /// 테두리 색 — null이면 `#D2D2D2`
  final Color? borderColor;

  /// 아이템 수가 이 값을 **초과**하면 스크롤 모드.
  /// 예: 6 → 7개 이상일 때 [maxVisibleItemsWhenScrolling]개만 노출
  final int? scrollWhenItemCountExceeds;

  /// 스크롤 모드일 때 보이는 아이템 수 (예: 5.5, 4.5)
  final double? maxVisibleItemsWhenScrolling;

  /// 아이템 1개당 예상 높이 (패딩 + 텍스트 + divider)
  static double estimateItemExtent({
    required BuildContext context,
    required double itemFontSizeBase,
    required EdgeInsetsGeometry itemPadding,
  }) {
    final pad = itemPadding.resolve(TextDirection.ltr);
    final textH = healthSp(context, itemFontSizeBase) * 1.2;
    final dividerW = healthDp(context, 0.5);
    return pad.vertical + textH + dividerW;
  }

  /// 패널 maxHeight 계산
  static double resolvePanelMaxHeight({
    required BuildContext context,
    required int itemCount,
    required double itemFontSizeBase,
    required EdgeInsetsGeometry itemPadding,
    double? panelMaxHeight,
    int? scrollWhenItemCountExceeds,
    double? maxVisibleItemsWhenScrolling,
  }) {
    final extent = estimateItemExtent(
      context: context,
      itemFontSizeBase: itemFontSizeBase,
      itemPadding: itemPadding,
    );

    if (scrollWhenItemCountExceeds != null &&
        maxVisibleItemsWhenScrolling != null &&
        itemCount > 0) {
      if (itemCount > scrollWhenItemCountExceeds) {
        return extent * maxVisibleItemsWhenScrolling;
      }
      return extent * itemCount;
    }

    return panelMaxHeight ?? healthDp(context, 260);
  }

  /// 앵커 위젯 기준으로 드롭다운 메뉴 표시
  static void showMenu({
    required BuildContext context,
    GlobalKey? anchorKey,
    BuildContext? anchorContext,
    required List<String> items,
    required ValueChanged<String> onSelected,
    double? gap,
    double? panelMaxHeight,
    double? menuWidth,
    double itemFontSizeBase = 14,
    String itemFontFamily = 'Gmarket Sans TTF',
    FontWeight itemFontWeight = FontWeight.w300,
    TextAlign itemTextAlign = TextAlign.center,
    Widget? Function(String item)? leadingBuilder,
    double itemLeadingGapBase = 8,
    EdgeInsetsGeometry? itemPadding,
    bool blurBackdrop = false,
    double blurSigma = 4,
    double backdropOpacity = 0.72,
    int? scrollWhenItemCountExceeds,
    double? maxVisibleItemsWhenScrolling,
  }) {
    closeMenu();

    final ctx = anchorContext ?? anchorKey?.currentContext;
    if (ctx == null || items.isEmpty) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final menuGap = gap ?? healthDp(context, 6);
    final menuRadius = healthDp(context, 10);
    final itemFontSize = healthSp(context, itemFontSizeBase);
    final itemLeadingGap = healthDp(context, itemLeadingGapBase);
    final resolvedItemPadding = itemPadding ??
        EdgeInsets.symmetric(
          vertical: healthDp(context, 10),
          horizontal: healthDp(context, 8),
        );
    final dividerWidth = healthDp(context, 0.5);

    final size = box.size;
    final offset = box.localToGlobal(Offset.zero);
    final panelWidth = menuWidth ?? size.width;
    var maxPanelH = resolvePanelMaxHeight(
      context: context,
      itemCount: items.length,
      itemFontSizeBase: itemFontSizeBase,
      itemPadding: resolvedItemPadding,
      panelMaxHeight: panelMaxHeight,
      scrollWhenItemCountExceeds: scrollWhenItemCountExceeds,
      maxVisibleItemsWhenScrolling: maxVisibleItemsWhenScrolling,
    );

    // 항상 아래로 열림. 화면 하단을 넘지 않도록 높이만 클램프.
    final media = MediaQuery.of(context);
    final screenH = media.size.height;
    final safeBottom = media.padding.bottom;
    final spaceBelow =
        screenH - safeBottom - (offset.dy + size.height + menuGap);
    if (spaceBelow > 0 && maxPanelH > spaceBelow) {
      maxPanelH = spaceBelow;
    }
    final menuTop = offset.dy + size.height + menuGap;

    void close() {
      closeMenu();
    }

    final overlay = Overlay.of(context);

    _sharedOverlayEntry = OverlayEntry(
      builder: (overlayContext) {
        if (!overlayContext.mounted) {
          return const SizedBox.shrink();
        }
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: close,
                child: blurBackdrop
                    ? BackdropFilter(
                        filter: ImageFilter.blur(
                          sigmaX: blurSigma,
                          sigmaY: blurSigma,
                        ),
                        child: Container(
                          color: Colors.white.withValues(alpha: backdropOpacity),
                        ),
                      )
                    : const ColoredBox(color: Colors.transparent),
              ),
            ),
            Positioned(
              left: offset.dx,
              top: menuTop,
              width: panelWidth,
              child: Material(
                color: Colors.white,
                elevation: 4,
                borderRadius: BorderRadius.circular(menuRadius),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxPanelH),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < items.length; i++)
                          Material(
                            color: Colors.white,
                            child: InkWell(
                              onTap: () {
                                onSelected(items[i]);
                                close();
                              },
                              child: Container(
                                width: double.infinity,
                                padding: resolvedItemPadding,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    bottom: BorderSide(
                                      width: i == items.length - 1
                                          ? 0
                                          : dividerWidth,
                                      color: const Color(0x7FD2D2D2),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      itemTextAlign == TextAlign.center
                                          ? MainAxisAlignment.center
                                          : MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    if (leadingBuilder != null) ...[
                                      leadingBuilder(items[i]) ??
                                          const SizedBox.shrink(),
                                      SizedBox(width: itemLeadingGap),
                                    ],
                                    Flexible(
                                      child: Text(
                                        items[i],
                                        textAlign: itemTextAlign,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: const Color(0xFF1A1A1A),
                                          fontSize: itemFontSize,
                                          fontFamily: itemFontFamily,
                                          fontWeight: itemFontWeight,
                                          height: 1.2,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(_sharedOverlayEntry!);
  }

  /// 아래로 열 공간이 부족하면 조상 [Scrollable]을 스크롤해 여유를 만든다.
  static Future<void> ensureSpaceBelowForMenu({
    required BuildContext context,
    GlobalKey? anchorKey,
    BuildContext? anchorContext,
    required double neededHeight,
    double? gap,
  }) async {
    final ctx = anchorContext ?? anchorKey?.currentContext;
    if (ctx == null || !ctx.mounted) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final menuGap = gap ?? healthDp(context, 6);
    final media = MediaQuery.of(context);
    final screenH = media.size.height;
    final safeBottom = media.padding.bottom;
    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    final spaceBelow =
        screenH - safeBottom - (offset.dy + size.height + menuGap);
    if (spaceBelow >= neededHeight) return;

    final scrollable = Scrollable.maybeOf(ctx);
    if (scrollable == null) return;
    final position = scrollable.position;
    if (!position.hasContentDimensions) return;

    final deficit = neededHeight - spaceBelow + healthDp(context, 12);
    final target = (position.pixels + deficit).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if ((target - position.pixels).abs() < 1) return;

    await position.animateTo(
      target,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
    // 레이아웃 반영 대기
    await Future<void>.delayed(Duration.zero);
  }

  static void closeMenu() {
    final entry = _sharedOverlayEntry;
    if (entry == null) return;
    _sharedOverlayEntry = null;
    try {
      entry.remove();
    } catch (_) {
      // Hot reload 중 overlay가 이미 제거된 경우 무시
    }
  }

  const DropdownBtn({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.buttonHeight = 36,
    this.panelMaxHeight,
    this.emptyText = '선택',
    this.enabled = true,
    this.itemFontSizeBase = 14,
    this.itemTextAlign = TextAlign.center,
    this.leadingBuilder,
    this.itemLeadingGapBase = 8,
    this.itemPadding,
    this.emptyTextColor,
    this.valueTextColor,
    this.borderColor,
    this.scrollWhenItemCountExceeds,
    this.maxVisibleItemsWhenScrolling,
  });

  @override
  State<DropdownBtn> createState() => _DropdownBtnState();
}

class _DropdownBtnState extends State<DropdownBtn> {
  static const String _fontFamily = 'Gmarket Sans TTF';

  final GlobalKey _anchorKey = GlobalKey();

  bool get _open => DropdownBtn._sharedOverlayEntry != null;

  @override
  void dispose() {
    DropdownBtn.closeMenu();
    super.dispose();
  }

  void _closeAndRebuild() {
    DropdownBtn.closeMenu();
    if (mounted) setState(() {});
  }

  Future<void> _toggle() async {
    if (!widget.enabled || widget.items.isEmpty) return;
    if (_open) {
      _closeAndRebuild();
      return;
    }

    final itemPadding = widget.itemPadding ??
        EdgeInsets.symmetric(
          vertical: healthDp(context, 10),
          horizontal: healthDp(context, 8),
        );

    final neededHeight = DropdownBtn.resolvePanelMaxHeight(
      context: context,
      itemCount: widget.items.length,
      itemFontSizeBase: widget.itemFontSizeBase,
      itemPadding: itemPadding,
      panelMaxHeight: widget.panelMaxHeight,
      scrollWhenItemCountExceeds: widget.scrollWhenItemCountExceeds,
      maxVisibleItemsWhenScrolling: widget.maxVisibleItemsWhenScrolling,
    );

    await DropdownBtn.ensureSpaceBelowForMenu(
      context: context,
      anchorKey: _anchorKey,
      neededHeight: neededHeight,
    );
    if (!mounted) return;

    DropdownBtn.showMenu(
      context: context,
      anchorKey: _anchorKey,
      items: widget.items,
      panelMaxHeight: widget.panelMaxHeight,
      itemFontSizeBase: widget.itemFontSizeBase,
      itemTextAlign: widget.itemTextAlign,
      leadingBuilder: widget.leadingBuilder,
      itemLeadingGapBase: widget.itemLeadingGapBase,
      itemPadding: itemPadding,
      scrollWhenItemCountExceeds: widget.scrollWhenItemCountExceeds,
      maxVisibleItemsWhenScrolling: widget.maxVisibleItemsWhenScrolling,
      onSelected: (item) {
        widget.onChanged(item);
        if (mounted) setState(() {});
      },
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.value.trim().isNotEmpty;
    final display = hasValue ? widget.value : widget.emptyText;
    final canOpen = widget.enabled && widget.items.isNotEmpty;
    final displayColor = !widget.enabled
        ? const Color(0xFFBDBDBD)
        : (hasValue
            ? (widget.valueTextColor ?? const Color(0xFF1A1A1A))
            : (widget.emptyTextColor ?? const Color(0xFF898686)));
    final leading = hasValue && widget.leadingBuilder != null
        ? widget.leadingBuilder!(widget.value)
        : null;

    final radius = healthDp(context, 10);
    final padH = healthDp(context, 10);
    final borderW = healthDp(context, 1);
    final borderColor = widget.borderColor ?? const Color(0xFFD2D2D2);
    final chevronSize = healthDp(context, 16);
    final itemFontSize = healthSp(context, widget.itemFontSizeBase);
    final itemLeadingGap = healthDp(context, widget.itemLeadingGapBase);

    return SizedBox(
      height: widget.buttonHeight,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: canOpen ? _toggle : null,
        child: Opacity(
          opacity: widget.enabled ? 1 : 0.55,
          child: Container(
            key: _anchorKey,
            padding: EdgeInsets.symmetric(horizontal: padH),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                side: BorderSide(width: borderW, color: borderColor),
                borderRadius: BorderRadius.circular(radius),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (leading != null) ...[
                  leading,
                  SizedBox(width: itemLeadingGap),
                ],
                Expanded(
                  child: Text(
                    display,
                    overflow: TextOverflow.ellipsis,
                    textAlign: widget.itemTextAlign,
                    style: TextStyle(
                      color: displayColor,
                      fontSize: itemFontSize,
                      fontFamily: _fontFamily,
                      fontWeight: FontWeight.w500,
                      height: 1.0,
                    ),
                  ),
                ),
                Icon(
                  _open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: chevronSize,
                  color: canOpen
                      ? const Color(0xFF898686)
                      : const Color(0xFFBDBDBD),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
