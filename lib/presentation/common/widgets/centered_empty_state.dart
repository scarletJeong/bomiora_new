import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../health/health_common/health_responsive_scale.dart';

/// 빈 화면 아이콘 기본 색 (선이 진하지 않은 연한 회색)
const Color kEmptyStateIconColor = Color(0xFFBDBDBD);

/// 빈 화면 중앙 아이콘 + 안내 문구 (로그인 필요, 목록 비어 있음 등 공통)
class CenteredEmptyState extends StatelessWidget {
  const CenteredEmptyState({
    super.key,
    required this.message,
    this.subtitle,
    this.icon,
    this.iconWidget,
    this.iconColor = kEmptyStateIconColor,
    this.messageStyle,
    this.subtitleStyle,
    this.gap,
    this.trailingGap,
    this.trailing,
    this.fillAvailable = true,
  });

  final String message;
  final String? subtitle;
  final IconData? icon;
  final Widget? iconWidget;
  final Color iconColor;
  final TextStyle? messageStyle;
  final TextStyle? subtitleStyle;
  final double? gap;
  final double? trailingGap;
  final List<Widget>? trailing;

  /// 남는 영역을 채울지. `SliverFillRemaining` 안에서는 부모 제약만으로 중앙 정렬한다.
  final bool fillAvailable;

  static TextStyle defaultMessageStyle(BuildContext context) => TextStyle(
        fontSize: healthSp(context, 14),
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: FontWeight.w500,
        color: const Color(0xFFC0C0C0),
        height: 1.0,
      );

  static TextStyle defaultSubtitleStyle(BuildContext context) => TextStyle(
        fontSize: healthSp(context, 12),
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: FontWeight.w300,
        color: const Color(0xFFB0B0B0),
        height: 1.0,
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
            style: messageStyle ?? CenteredEmptyState.defaultMessageStyle(context),
          ),
        ),
        if (subtitle != null) ...[
          SizedBox(height: healthDp(context, 10)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: healthDp(context, 27)),
            child: Text(
              subtitle!,
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              style: subtitleStyle ??
                  CenteredEmptyState.defaultSubtitleStyle(context),
            ),
          ),
        ],
        if (trailing != null) ...[
          SizedBox(height: trailingGap ?? spacing),
          ...trailing!,
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(child: _buildContent(context));
  }
}
