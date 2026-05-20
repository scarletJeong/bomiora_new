import 'dart:ui';

import 'package:flutter/material.dart';

class DropdownBtn extends StatefulWidget {
  static OverlayEntry? _sharedOverlayEntry;

  final List<String> items;
  final String value;
  final ValueChanged<String> onChanged;
  final double buttonHeight;
  final double panelMaxHeight;
  final String emptyText;
  final bool enabled;

  /// 앵커 위젯 기준으로 드롭다운 메뉴 표시 (사진 추가 등 커스텀 버튼용)
  static void showMenu({
    required BuildContext context,
    GlobalKey? anchorKey,
    BuildContext? anchorContext,
    required List<String> items,
    required ValueChanged<String> onSelected,
    double gap = 6,
    double panelMaxHeight = 260,
    double? menuWidth,
    double itemFontSize = 14,
    String itemFontFamily = 'Gmarket Sans TTF',
    FontWeight itemFontWeight = FontWeight.w300,
    bool blurBackdrop = false,
    double blurSigma = 4,
    double backdropOpacity = 0.72,
  }) {
    closeMenu();

    final ctx = anchorContext ?? anchorKey?.currentContext;
    if (ctx == null || items.isEmpty) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final size = box.size;
    final offset = box.localToGlobal(Offset.zero);
    final panelWidth = menuWidth ?? size.width;

    void close() {
      closeMenu();
    }

    final overlay = Overlay.of(context);

    _sharedOverlayEntry = OverlayEntry(
      builder: (overlayContext) {
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
              top: offset.dy + size.height + gap,
              width: panelWidth,
              child: Material(
                color: Colors.white,
                elevation: 4,
                borderRadius: BorderRadius.circular(10),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: panelMaxHeight),
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  border: Border(
                                    bottom: BorderSide(
                                      width: i == items.length - 1 ? 0 : 0.5,
                                      color: const Color(0x7FD2D2D2),
                                    ),
                                  ),
                                ),
                                child: Text(
                                  items[i],
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: const Color(0xFF1A1A1A),
                                    fontSize: itemFontSize,
                                    fontFamily: itemFontFamily,
                                    fontWeight: itemFontWeight,
                                    height: 1.2,
                                  ),
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

  static void closeMenu() {
    _sharedOverlayEntry?.remove();
    _sharedOverlayEntry = null;
  }

  const DropdownBtn({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.buttonHeight = 36,
    this.panelMaxHeight = 260,
    this.emptyText = '선택',
    this.enabled = true,
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

  void _toggle() {
    if (!widget.enabled || widget.items.isEmpty) return;
    if (_open) {
      _closeAndRebuild();
      return;
    }

    DropdownBtn.showMenu(
      context: context,
      anchorKey: _anchorKey,
      items: widget.items,
      panelMaxHeight: widget.panelMaxHeight,
      onSelected: (item) {
        widget.onChanged(item);
        if (mounted) setState(() {});
      },
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.value.trim().isNotEmpty;
    final display = hasValue ? widget.value : widget.emptyText;
    final canOpen = widget.enabled && widget.items.isNotEmpty;
    final displayColor = !widget.enabled
        ? const Color(0xFFBDBDBD)
        : (hasValue ? const Color(0xFF1A1A1A) : const Color(0xFF898686));

    return SizedBox(
      height: widget.buttonHeight,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: canOpen ? _toggle : null,
        child: Opacity(
          opacity: widget.enabled ? 1 : 0.55,
          child: Container(
            key: _anchorKey,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: ShapeDecoration(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                side: const BorderSide(width: 1, color: Color(0xFFD2D2D2)),
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    display,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: displayColor,
                      fontSize: 14,
                      fontFamily: _fontFamily,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  _open
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 16,
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
