import 'package:flutter/material.dart';

import '../../health/health_common/health_responsive_scale.dart';

/// 제목 + 스크롤 본문 + 확인 버튼 공통 콘텐츠 팝업
class ContentPopup extends StatelessWidget {
  const ContentPopup({
    super.key,
    required this.title,
    this.subtitle,
    required this.body,
    this.confirmLabel = '확인',
  });

  final String title;
  final String? subtitle;
  final String body;
  final String confirmLabel;

  static const Color _kInk = Color(0xFF1A1A1E);
  static const Color _kPink = Color(0xFFFF5A8D);
  static const Color _kDivider = Color(0x7FD2D2D2);
  static const String _kFontFamily = 'Gmarket Sans TTF';

  static Future<bool> show(
    BuildContext context, {
    required String title,
    String? subtitle,
    required String body,
    String confirmLabel = '확인',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => ContentPopup(
        title: title,
        subtitle: subtitle,
        body: body,
        confirmLabel: confirmLabel,
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final scrollController = ScrollController();

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 10),
        vertical: healthDp(context, 24),
      ),
      child: Container(
        width: healthDp(context, 355),
        height: healthDp(context, 607),
        padding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 20),
          vertical: healthDp(context, 30),
        ),
        clipBehavior: Clip.antiAlias,
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: _kInk,
                      fontSize: healthSp(context, 20),
                      fontFamily: _kFontFamily,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(false),
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: EdgeInsets.only(left: healthDp(context, 8)),
                    child: Icon(
                      Icons.close,
                      size: healthDp(context, 24),
                      color: _kInk,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: healthDp(context, 20)),
            Container(
              width: double.infinity,
              height: healthDp(context, 1),
              color: _kDivider,
            ),
            SizedBox(height: healthDp(context, 20)),
            Expanded(
              child: Scrollbar(
                controller: scrollController,
                thumbVisibility: true,
                thickness: healthDp(context, 2),
                radius: Radius.circular(healthDp(context, 10)),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.only(right: healthDp(context, 8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: _kInk,
                            fontSize: healthSp(context, 16),
                            fontFamily: _kFontFamily,
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                        SizedBox(height: healthDp(context, 10)),
                      ],
                      Text(
                        body,
                        style: TextStyle(
                          color: _kInk,
                          fontSize: healthSp(context, 14),
                          fontFamily: _kFontFamily,
                          fontWeight: FontWeight.w300,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: healthDp(context, 20)),
            SizedBox(
              width: double.infinity,
              height: healthDp(context, 40),
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  backgroundColor: _kPink,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.all(healthDp(context, 10)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(healthDp(context, 10)),
                  ),
                ),
                child: Text(
                  confirmLabel,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: healthSp(context, 16),
                    fontFamily: _kFontFamily,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
