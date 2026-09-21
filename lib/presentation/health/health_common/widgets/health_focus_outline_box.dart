import 'package:flutter/material.dart';

import '../health_responsive_scale.dart';

/// 건강 입력칸. 포커스되면 테두리가 핑크색이 된다.
class HealthFocusOutlineBox extends StatefulWidget {
  const HealthFocusOutlineBox({
    super.key,
    required this.builder,
    this.focusNode,
    this.height,
    this.padding,
    this.borderRadius,
    this.fillColor,
  });

  static const Color focusColor = Color(0xFFFF5A8D);
  static const Color idleColor = Color(0x7FD2D2D2);

  final Widget Function(FocusNode focusNode) builder;
  final FocusNode? focusNode;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final double? borderRadius;
  final Color? fillColor;

  @override
  State<HealthFocusOutlineBox> createState() => _HealthFocusOutlineBoxState();
}

class _HealthFocusOutlineBoxState extends State<HealthFocusOutlineBox> {
  FocusNode? _owned;
  late FocusNode _node;

  @override
  void initState() {
    super.initState();
    _attach(widget.focusNode);
  }

  @override
  void didUpdateWidget(covariant HealthFocusOutlineBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _detach(_node);
      _owned?.dispose();
      _owned = null;
      _attach(widget.focusNode);
    }
  }

  void _attach(FocusNode? external) {
    _node = external ?? (_owned = FocusNode());
    _node.addListener(_onFocus);
  }

  void _detach(FocusNode node) {
    node.removeListener(_onFocus);
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _detach(_node);
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height ?? healthDp(context, 40),
      padding: widget.padding ??
          EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
      alignment: Alignment.centerLeft,
      clipBehavior: Clip.none,
      decoration: ShapeDecoration(
        color: widget.fillColor,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: healthDp(context, 1),
            color: _node.hasFocus
                ? HealthFocusOutlineBox.focusColor
                : HealthFocusOutlineBox.idleColor,
          ),
          borderRadius: BorderRadius.circular(
            widget.borderRadius ?? healthDp(context, 7),
          ),
        ),
      ),
      child: widget.builder(_node),
    );
  }
}
