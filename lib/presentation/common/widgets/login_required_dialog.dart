import 'package:flutter/material.dart';

Future<bool> showLoginRequiredDialog(
  BuildContext context, {
  String message = '로그인 후 이용할 수 있습니다.',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 272,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
          clipBehavior: Clip.antiAlias,
          child: DefaultTextStyle.merge(
            style: const TextStyle(fontFamily: 'Gmarket Sans TTF'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Text(
                    '로그인 안내',
                    style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF898686),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.57,
                    ),
                  ),
                ),
                SizedBox(
                  height: 50,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Material(
                          color: const Color(0xFFF7F7F7),
                          child: InkWell(
                            onTap: () => Navigator.of(dialogContext).pop(false),
                            child: const Center(
                              child: Text(
                                '취소',
                                style: TextStyle(
                                  color: Color(0xFF898686),
                                  fontSize: 16,
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
                            child: const Center(
                              child: Text(
                                '확인',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
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
