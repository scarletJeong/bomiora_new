import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/constants/app_assets.dart';
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

  /// 공지사항 아이콘이 80 칸에서 실제로 차지하는 긴 변.
  static const double _noticeBox = 80;
  static const double _noticeInk = 52.3;

  /// viewBox 긴 변, 선까지 포함한 그림의 긴 변.
  static const Map<String, List<double>> _iconInk = {
    AppAssets.emptyNoticeIcon: [80, 52.3],
    AppAssets.emptyEventIcon: [60, 59.2],
    AppAssets.emptyQAIcon: [67, 66.9],
    AppAssets.emptyAddressIcon: [70, 69.2],
    AppAssets.emptyAlarmIcon: [63, 62.9],
    AppAssets.emptyCartIcon: [72, 58.2],
    AppAssets.emptyCartGeneralIcon: [72, 58.2],
    AppAssets.emptyCategoryIcon: [63, 62.7],
    AppAssets.emptyContentIcon: [80, 55.8],
    AppAssets.emptyCouponIcon: [70, 60.3],
    AppAssets.emptyDeliveryIcon: [72, 56.7],
    AppAssets.emptyHealthIcon: [80, 64.0],
    AppAssets.emptyPointIcon: [70, 60.3],
    AppAssets.emptyProductReviewIcon: [72, 55.2],
    AppAssets.emptyRefundIcon: [80, 62.5],
    AppAssets.emptyReviewIcon: [80, 62.5],
    AppAssets.searchEmptyIcon: [80, 62.5],
    AppAssets.qaSelectCartIcon: [80, 60.4],
    AppAssets.emptyOrderDeliveryIcon: [80, 65.7],
    AppAssets.emptyReturnIcon: [80, 62.7],
    AppAssets.qaSelectWishlistIcon: [80, 61.8],
    AppAssets.emptySettingIcon: [72, 61.0],
    AppAssets.emptyWishlistIcon: [62, 61.8],
  };

  /// 빈 화면 SVG. 캔버스 여백이 달라도 공지사항 아이콘과 같은 크기로 보인다.
  /// [slot]은 아이콘이 놓이는 칸. 페이지 빈 화면은 70, 홈 한 줄은 28.
  static Widget assetIcon(
    BuildContext context,
    String assetPath, {
    double slot = 70,
  }) {
    final box = healthDp(context, slot);
    final spec = _iconInk[assetPath];
    final draw = spec == null
        ? box
        : box * (_noticeInk / _noticeBox) * (spec[0] / spec[1]);
    return SizedBox(
      width: box,
      height: box,
      child: Center(
        child: SvgPicture.asset(
          assetPath,
          width: draw,
          height: draw,
          fit: BoxFit.contain,
        ),
      ),
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

/// 앱바 아래 페이지 세로 가운데에 빈 안내를 올린다.
/// 안내 밖 터치는 아래의 검색창·탭으로 통과한다.
class PageCenteredEmptyOverlay extends StatelessWidget {
  const PageCenteredEmptyOverlay({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            alignment: Alignment.center,
            children: [
              UnconstrainedBox(
                constrainedAxis: Axis.horizontal,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: child,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
