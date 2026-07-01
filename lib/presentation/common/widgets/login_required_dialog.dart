import 'package:flutter/material.dart';

import '../../health/health_common/health_responsive_scale.dart';

Future<bool> showLoginRequiredDialog(
  BuildContext context, {
  String message = '로그인 후 이용할 수 있습니다.',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      final dialogW = healthDp(dialogContext, 272);
      final radius = healthDp(dialogContext, 20);
      final padH = healthDp(dialogContext, 20);
      final titleFs = healthSp(dialogContext, 20);
      final bodyFs = healthSp(dialogContext, 14);
      final buttonFs = healthSp(dialogContext, 16);
      final buttonH = healthDp(dialogContext, 50);

      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: dialogW,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(radius)),
          ),
          clipBehavior: Clip.antiAlias,
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(padH, padH, padH, healthDp(dialogContext, 8)),
                  child: Text(
                    '로그인 안내',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: const Color(0xFF1A1A1A),
                      fontSize: titleFs,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(padH, 0, padH, padH),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      color: const Color(0xFF898686),
                      fontSize: bodyFs,
                      fontWeight: FontWeight.w500,
                      height: 1.57,
                    ),
                  ),
                ),
                SizedBox(
                  height: buttonH,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Material(
                          color: const Color(0xFFF7F7F7),
                          child: InkWell(
                            onTap: () => Navigator.of(dialogContext).pop(false),
                            child: Center(
                              child: Text(
                                '취소',
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  color: const Color(0xFF898686),
                                  fontSize: buttonFs,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Material(
                          color: const Color(0xFFFF5A8D),
                          child: InkWell(
                            onTap: () => Navigator.of(dialogContext).pop(true),
                            child: Center(
                              child: Text(
                                '확인',
                                textScaler: TextScaler.noScaling,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: buttonFs,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  if (result == true && context.mounted) {
    final returnTo = ModalRoute.of(context)?.settings.name;
    Navigator.pushNamed(
      context,
      '/login',
      arguments: {
        if (returnTo != null && returnTo.isNotEmpty) 'returnTo': returnTo,
      },
    );
    return true;
  }

  return false;
}
