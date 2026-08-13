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
  /// (문진표 빈 화면 CTA와 동일: 12sp / w500 / radius 8 / padding 20×12)
  static List<Widget> loginButtonTrailing(
    BuildContext context, {
    VoidCallback? onPressed,
    String label = '로그인하기',
  }) {
    return [
      Align(
        alignment: Alignment.center,
        widthFactor: 1,
        child: ElevatedButton(
          onPressed: onPressed ?? () => Navigator.pushNamed(context, '/login'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF5A8D),
            foregroundColor: Colors.white,
            elevation: 0,
            shadowColor: Colors.transparent,
            padding: EdgeInsets.symmetric(
              horizontal: healthDp(context, 20),
              vertical: healthDp(context, 12),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(healthDp(context, 8)),
            ),
          ),
          child: Text(
            label,
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontSize: healthSp(context, 12),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
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
