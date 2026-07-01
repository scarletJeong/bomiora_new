import 'package:flutter/material.dart';

import '../../health/health_common/health_responsive_scale.dart';

/// 빈 화면 아이콘 기본 색 (선이 진하지 않은 연한 회색)
const Color kEmptyStateIconColor = Color(0xFFBDBDBD);

/// 화면 중앙 아이콘 + 안내 문구 (로그인 필요, 목록 비어 있음 등 공통)
class CenteredEmptyState extends StatelessWidget {
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
    this.fillAvailable = false,
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
        fontSize: healthSp(context, 14),
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: FontWeight.w500,
        color: const Color(0xFFBDBDBD),
        height: 1.4,
      );

  Widget _buildContent(BuildContext context) {
    final iconSize = healthDp(context, 70);
    final spacing = gap ?? healthDp(context, 15);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (iconWidget != null) ...[
          SizedBox(width: iconSize, height: iconSize, child: iconWidget),
          SizedBox(height: spacing),
        ] else if (icon != null) ...[
          Icon(
            icon,
            size: iconSize,
            color: iconColor,
          ),
          SizedBox(height: spacing),
        ],
        Padding(
          padding: EdgeInsets.symmetric(horizontal: healthDp(context, 27)),
          child: Text(
            message,
            textAlign: TextAlign.center,
            textScaler: TextScaler.noScaling,
            style: messageStyle ?? defaultMessageStyle(context),
          ),
        ),
        if (trailing != null) ...[
          SizedBox(height: trailingGap ?? spacing),
          ...trailing!,
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!fillAvailable) {
      return Center(child: _buildContent(context));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;
        final content = Center(child: _buildContent(context));

        // ScrollView 자식 등 높이가 무한인 경우 minHeight를 쓰면 레이아웃 오류 발생
        if (!maxHeight.isFinite || maxHeight <= 0) {
          return content;
        }

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: maxHeight),
            child: content,
          ),
        );
      },
    );
  }
}
