import 'package:flutter/material.dart';

class DropdownBtn extends StatefulWidget {
  final List<String> items;
  final String value;
  final ValueChanged<String> onChanged;
  final double buttonHeight;
  final double panelMaxHeight;
  final String emptyText;

  const DropdownBtn({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.buttonHeight = 36,
    this.panelMaxHeight = 260,
    this.emptyText = '선택',
  });

  @override
  State<DropdownBtn> createState() => _DropdownBtnState();
}

class _DropdownBtnState extends State<DropdownBtn> {
  static const String _fontFamily = 'Gmarket Sans TTF';

  OverlayEntry? _overlayEntry;
  final GlobalKey _anchorKey = GlobalKey();

  bool get _open => _overlayEntry != null;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _closeAndRebuild() {
    _removeOverlay();
    if (mounted) setState(() {});
  }

  void _toggle() {
    if (_open) {
      _closeAndRebuild();
      return;
    }

    final ctx = _anchorKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final size = box.size;
    final offset = box.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeAndRebuild,
              ),
            ),
            Positioned(
              left: offset.dx,
              top: offset.dy + size.height + 6,
              width: size.width,
              child: Material(
                color: Colors.white,
                elevation: 4,
                borderRadius: BorderRadius.circular(10),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: widget.panelMaxHeight),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < widget.items.length; i++)
                          Material(
                            color: Colors.white,
                            child: InkWell(
                              onTap: () {
                                widget.onChanged(widget.items[i]);
                                _closeAndRebuild();
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
                                      width: i == widget.items.length - 1 ? 0 : 0.5,
                                      color: const Color(0x7FD2D2D2),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      widget.items[i],
                                      style: TextStyle(
                                        color: widget.items[i] == widget.value
                                            ? const Color(0xFFFF5B8C)
                                            : const Color(0xFF1A1A1A),
                                        fontSize: 14,
                                        fontFamily: _fontFamily,
                                        fontWeight: widget.items[i] == widget.value
                                            ? FontWeight.w600
                                            : FontWeight.w400,
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

    Overlay.of(ctx).insert(_overlayEntry!);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.value.trim().isNotEmpty;
    final display = hasValue ? widget.value : widget.emptyText;

    return SizedBox(
      height: widget.buttonHeight,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _toggle,
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
                  style: const TextStyle(
                    color: Color(0xFF1A1A1A),
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
                color: const Color(0xFF898686),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
