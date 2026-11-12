import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../health/health_common/health_responsive_scale.dart';

/// 확인 체크 후에만 진행할 수 있는 알림.
class AcknowledgeAlertDialog extends StatefulWidget {
  const AcknowledgeAlertDialog({
    super.key,
    required this.title,
    required this.message,
    required this.summaryLabel,
    required this.summaryValue,
    required this.detail,
    this.checkboxLabel = '삭제되는 정보와 유의사항을 확인했습니다.',
    this.stayText = '더 이용할게요',
    this.confirmText = '탈퇴하기',
  });

  final String title;
  final String message;
  final String summaryLabel;
  final String summaryValue;
  final String detail;
  final String checkboxLabel;
  final String stayText;
  final String confirmText;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    required String summaryLabel,
    required String summaryValue,
    required String detail,
    String checkboxLabel = '삭제되는 정보와 유의사항을 확인했습니다.',
    String stayText = '더 이용할게요',
    String confirmText = '탈퇴하기',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AcknowledgeAlertDialog(
        title: title,
        message: message,
        summaryLabel: summaryLabel,
        summaryValue: summaryValue,
        detail: detail,
        checkboxLabel: checkboxLabel,
        stayText: stayText,
        confirmText: confirmText,
      ),
    );
    return result ?? false;
  }

  @override
  State<AcknowledgeAlertDialog> createState() => _AcknowledgeAlertDialogState();
}

class _AcknowledgeAlertDialogState extends State<AcknowledgeAlertDialog> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.sizeOf(context).width;
    final margin = healthDp(context, 16);
    final dialogW = math.min(healthDp(context, 362), screenW - margin * 2);
    final radius = healthDp(context, 22);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: EdgeInsets.symmetric(horizontal: margin),
      child: Container(
        width: dialogW,
        padding: EdgeInsets.fromLTRB(
          healthDp(context, 16),
          healthDp(context, 12),
          healthDp(context, 16),
          healthDp(context, 16),
        ),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          shadows: [
            BoxShadow(
              color: const Color(0x3D000000),
              blurRadius: healthDp(context, 80),
              offset: Offset(0, healthDp(context, 24)),
            ),
          ],
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(false),
                  borderRadius: BorderRadius.circular(healthDp(context, 18)),
                  child: SizedBox(
                    width: healthDp(context, 36),
                    height: healthDp(context, 36),
                    child: Icon(
                      Icons.close,
                      size: healthDp(context, 20),
                      color: const Color(0xFF76767C),
                    ),
                  ),
                ),
              ),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF19191B),
                  fontSize: healthSp(context, 22),
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                  letterSpacing: healthSp(context, -0.96),
                ),
              ),
              SizedBox(height: healthDp(context, 12)),
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: const Color(0xFF76767C),
                  fontSize: healthSp(context, 13),
                  fontWeight: FontWeight.w300,
                  height: 1.6,
                  letterSpacing: healthSp(context, -0.38),
                ),
              ),
              SizedBox(height: healthDp(context, 14)),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(healthDp(context, 12)),
                decoration: ShapeDecoration(
                  color: const Color(0xFFF7F7F9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(healthDp(context, 14)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.summaryLabel,
                            style: TextStyle(
                              color: const Color(0xFF77777D),
                              fontSize: healthSp(context, 11),
                              fontWeight: FontWeight.w300,
                              height: 1.5,
                            ),
                          ),
                        ),
                        SizedBox(width: healthDp(context, 12)),
                        Flexible(
                          child: Text(
                            widget.summaryValue,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: const Color(0xFFF23F78),
                              fontSize: healthSp(context, 13),
                              fontWeight: FontWeight.w500,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: double.infinity,
                      margin: EdgeInsets.only(top: healthDp(context, 8)),
                      padding: EdgeInsets.only(top: healthDp(context, 8)),
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(width: 1, color: Color(0xFFE6E6E9)),
                        ),
                      ),
                      child: Text(
                        widget.detail,
                        style: TextStyle(
                          color: const Color(0xFF69696F),
                          fontSize: healthSp(context, 11),
                          fontWeight: FontWeight.w300,
                          height: 1.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: healthDp(context, 12)),
              InkWell(
                onTap: () => setState(() => _checked = !_checked),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: healthDp(context, 18),
                      height: healthDp(context, 18),
                      alignment: Alignment.center,
                      decoration: ShapeDecoration(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(
                            width: 1,
                            color: _checked
                                ? const Color(0xFFF23F78)
                                : const Color(0xFF767676),
                          ),
                          borderRadius: BorderRadius.circular(healthDp(context, 2)),
                        ),
                      ),
                      child: _checked
                          ? Icon(
                              Icons.check,
                              size: healthDp(context, 14),
                              color: const Color(0xFFF23F78),
                            )
                          : null,
                    ),
                    SizedBox(width: healthDp(context, 9)),
                    Expanded(
                      child: Text(
                        widget.checkboxLabel,
                        style: TextStyle(
                          color: const Color(0xFF4F4F54),
                          fontSize: healthSp(context, 11),
                          fontWeight: FontWeight.w300,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: healthDp(context, 14)),
              _DialogButton(
                label: widget.stayText,
                background: Colors.white,
                borderColor: const Color(0xFFDEDEE2),
                textColor: const Color(0xFF5F5F64),
                onTap: () => Navigator.of(context).pop(false),
              ),
              SizedBox(height: healthDp(context, 10)),
              _DialogButton(
                label: widget.confirmText,
                background: _checked
                    ? const Color(0xFFF23F78)
                    : const Color(0xFFE9E9EC),
                borderColor: Colors.transparent,
                textColor: _checked ? Colors.white : const Color(0xFFA9A9AE),
                onTap: _checked ? () => Navigator.of(context).pop(true) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.background,
    required this.borderColor,
    required this.textColor,
    required this.onTap,
  });

  final String label;
  final Color background;
  final Color borderColor;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        side: BorderSide(width: 1, color: borderColor),
        borderRadius: BorderRadius.circular(healthDp(context, 14)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          height: healthDp(context, 44),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: healthSp(context, 14),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
                height: 1.5,
                letterSpacing: healthSp(context, -0.40),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
