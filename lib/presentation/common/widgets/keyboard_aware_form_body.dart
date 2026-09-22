import 'package:flutter/material.dart';
 
/// 입력 화면 본문. 키보드가 올라오면 필드·하단 버튼이 가려지지 않게 스크롤한다.
class KeyboardAwareFormBody extends StatelessWidget {
  const KeyboardAwareFormBody({
    super.key,
    required this.form,
    required this.bottom,
    this.formPadding,
    this.bottomPadding,
  });

  final Widget form;
  final Widget bottom;
  final EdgeInsetsGeometry? formPadding;
  final EdgeInsetsGeometry? bottomPadding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: formPadding ?? EdgeInsets.zero,
                  child: form,
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: bottomPadding ?? EdgeInsets.zero,
                    child: bottom,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
