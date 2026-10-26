import 'package:flutter/material.dart';
 
/// 입력 화면 본문.
/// [pinBottom]이 켜지면 취소·등록 버튼은 스크롤 밖에 두고 화면 하단에 고정한다.
class KeyboardAwareFormBody extends StatelessWidget {
  const KeyboardAwareFormBody({
    super.key,
    required this.form,
    required this.bottom,
    this.formPadding,
    this.bottomPadding,
    this.pinBottom = false,
  });

  final Widget form;
  final Widget bottom;
  final EdgeInsetsGeometry? formPadding;
  final EdgeInsetsGeometry? bottomPadding;
  final bool pinBottom;

  @override
  Widget build(BuildContext context) {
    final bottomBar = SafeArea(
      top: false,
      child: Padding(
        padding: bottomPadding ?? EdgeInsets.zero,
        child: bottom,
      ),
    );

    if (pinBottom) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Padding(
                padding: formPadding ?? EdgeInsets.zero,
                child: form,
              ),
            ),
          ),
          bottomBar,
        ],
      );
    }

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
                bottomBar,
              ],
            ),
          ),
        );
      },
    );
  }
}
