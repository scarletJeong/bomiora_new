import 'package:flutter/material.dart';



import '../health_responsive_scale.dart';



/// 건강 화면 공통 AppBar (뒤로가기, 제목, 선택적 액션).

/// 375 기준: AppBar 위 여백 20 + 툴바 28, 제목 세로 패딩 5.

class HealthAppBar extends StatelessWidget implements PreferredSizeWidget {

  static const double topGapBase = 20;

  static const double toolbarHeightBase = 28;

  static const double titlePaddingVerticalBase = 5;



  final String title;

  final bool centerTitle;

  final List<Widget>? actions;

  final VoidCallback? onBack;

  /// null이면 375 기준 16 ([healthSp]).

  final double? titleFontSize;

  /// null이면 기본 아이콘 크기.

  final double? leadingIconSize;



  const HealthAppBar({

    super.key,

    required this.title,

    this.centerTitle = false,

    this.actions,

    this.onBack,

    this.titleFontSize,

    this.leadingIconSize,

  });



  @override

  Size get preferredSize {

    final views = WidgetsBinding.instance.platformDispatcher.views;

    if (views.isEmpty) {

      return const Size.fromHeight(topGapBase + toolbarHeightBase);

    }

    final view = views.first;

    final logicalWidth = view.physicalSize.width / view.devicePixelRatio;

    return Size.fromHeight(healthAppBarTotalHeightForWidth(logicalWidth));

  }



  @override

  Widget build(BuildContext context) {

    final topGap = healthAppBarTopGap(context);

    final toolbarH = healthAppBarHeight(context);

    final titlePadV = healthAppBarTitlePaddingV(context);

    final totalH = topGap + toolbarH;



    final iconSize = leadingIconSize ?? healthDp(context, 24);

    final leadingSlot = healthDp(context, 56);

    final iconRight = (leadingSlot - iconSize) / 2 + iconSize;

    final chevronToTitleGap = healthDp(context, 4);

    final titleSpacing = iconRight + chevronToTitleGap - leadingSlot;



    final titleWidget = Padding(

      padding: EdgeInsets.symmetric(vertical: titlePadV),

      child: Text(

        title,

        textScaler: TextScaler.noScaling,

        style: TextStyle(

          fontFamily: 'Gmarket Sans TTF',

          fontWeight: FontWeight.w700,

          color: Colors.black,

          fontSize: titleFontSize ?? healthSp(context, 16),

          height: 1,

        ),

      ),

    );



    return AppBar(

      toolbarHeight: totalH,

      leadingWidth: leadingSlot,

      titleSpacing: titleSpacing,

      leading: Padding(

        padding: EdgeInsets.only(top: topGap),

        child: SizedBox(

          height: toolbarH,

          child: IconButton(

            padding: EdgeInsets.zero,

            visualDensity: VisualDensity.compact,

            constraints: BoxConstraints(

              minWidth: leadingSlot,

              minHeight: toolbarH,

            ),

            icon: Icon(

              Icons.chevron_left,

              color: Colors.black,

              size: iconSize,

            ),

            onPressed: onBack ?? () => Navigator.pop(context),

          ),

        ),

      ),

      title: Padding(

        padding: EdgeInsets.only(top: topGap),

        child: SizedBox(

          height: toolbarH,

          child: centerTitle

              ? Center(child: titleWidget)

              : Align(

                  alignment: Alignment.centerLeft,

                  child: titleWidget,

                ),

        ),

      ),

      centerTitle: centerTitle,

      actions: actions == null

          ? null

          : [

              Padding(

                padding: EdgeInsets.only(top: topGap),

                child: SizedBox(

                  height: toolbarH,

                  child: Row(

                    mainAxisSize: MainAxisSize.min,

                    children: actions!,

                  ),

                ),

              ),

            ],

      backgroundColor: Colors.white,

      elevation: 0,

      scrolledUnderElevation: 0,

      surfaceTintColor: Colors.transparent,

    );

  }

}


