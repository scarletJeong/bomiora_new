import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../health/health_common/health_responsive_scale.dart';

/// 빈 화면 아이콘 기본 색 (선이 진하지 않은 연한 회색)
const Color kEmptyStateIconColor = Color(0xFFBDBDBD);

/// 빈 화면 중앙 아이콘 + 안내 문구 (로그인 필요, 목록 비어 있음 등 공통)
///
/// 남는 본문 영역이 아니라 **화면(페이지) 세로 중앙**에 맞춘다.
class CenteredEmptyState extends StatefulWidget {
  const CenteredEmptyState({
    super.key,
    required this.message,
    this.icon,
    this.iconWidget,
    this.iconColor = kEmptyStateIconColor,
    this.messageStyle,
    this.gap,
    this.trailingGap,
    this.trailing,
    this.fillAvailable = true,
  });

  final String message;
  final IconData? icon;
  final Widget? iconWidget;
  final Color iconColor;
  final TextStyle? messageStyle;
  final double? gap;
  final double? trailingGap;
  final List<Widget>? trailing;
  final bool fillAvailable;

  static TextStyle defaultMessageStyle(BuildContext context) => TextStyle(
        fontSize: healthSp(context, 15),
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: FontWeight.w300,
        color: const Color(0xFFBDBDBD),
        height: 1.4,
      );

  /// 빈 화면 / 로그인 유도용 SVG 아이콘 (문구 위)
  static Widget assetIcon(BuildContext context, String assetPath) {
    final size = healthDp(context, 70);
    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }

  /// `로그인 후 이용 가능합니다` 등 문구 아래 붙이는 로그인 버튼
  static List<Widget> loginButtonTrailing(
    BuildContext context, {
    VoidCallback? onPressed,
    String label = '로그인하기',
  }) {
    return [
      Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed ?? () => Navigator.pushNamed(context, '/login'),
          borderRadius: BorderRadius.circular(healthDp(context, 50)),
          child: Ink(
            height: healthDp(context, 40),
            padding: EdgeInsets.symmetric(
              horizontal: healthDp(context, 14),
              vertical: healthDp(context, 10),
            ),
            decoration: ShapeDecoration(
              color: const Color(0xFFFF5A8D),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(healthDp(context, 50)),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  label,
                  textScaler: TextScaler.noScaling,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: healthSp(context, 16),
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  @override
  State<CenteredEmptyState> createState() => _CenteredEmptyStateState();
}

class _CenteredEmptyStateState extends State<CenteredEmptyState> {
  double _pageCenterDy = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_syncPageCenter);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback(_syncPageCenter);
  }

  @override
  void didUpdateWidget(covariant CenteredEmptyState oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback(_syncPageCenter);
  }

  void _syncPageCenter(Duration _) {
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final top = box.localToGlobal(Offset.zero).dy;
    final boxH = box.size.height;
    final screenH = MediaQuery.sizeOf(context).height;
    // 카드/섹션 안 작은 빈 상태는 페이지 중앙으로 끌어올리지 않는다.
    final dy = (!widget.fillAvailable || boxH < screenH * 0.28)
        ? 0.0
        : (screenH / 2) - (top + boxH / 2);
    if ((dy - _pageCenterDy).abs() > 0.5) {
      setState(() => _pageCenterDy = dy);
    }
  }

  Widget _buildContent(BuildContext context) {
    final iconSize = healthDp(context, 70);
    final spacing = widget.gap ?? healthDp(context, 15);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.iconWidget != null) ...[
          SizedBox(width: iconSize, height: iconSize, child: widget.iconWidget),
          SizedBox(height: spacing),
        ] else if (widget.icon != null) ...[
          Icon(
            widget.icon,
            size: iconSize,
            color: widget.iconColor,
          ),
          SizedBox(height: spacing),
        ],
        Padding(
          padding: EdgeInsets.symmetric(horizontal: healthDp(context, 27)),
          child: Text(
            widget.message,
            textAlign: TextAlign.center,
            textScaler: TextScaler.noScaling,
            style: widget.messageStyle ??
                CenteredEmptyState.defaultMessageStyle(context),
          ),
        ),
        if (widget.trailing != null) ...[
          SizedBox(height: widget.trailingGap ?? spacing),
          ...widget.trailing!,
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Transform.translate(
      offset: Offset(0, _pageCenterDy),
      child: _buildContent(context),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;
        final centered = Center(child: content);

        if (!widget.fillAvailable ||
            !maxHeight.isFinite ||
            maxHeight <= 0) {
          return centered;
        }

        return SizedBox.expand(child: centered);
      },
    );
  }
}
