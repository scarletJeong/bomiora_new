import 'package:flutter/material.dart';

/// 상세 → 해당 게시판 목록.
/// 스택에 목록이 있으면 그곳으로 돌아가고, 메인에서 바로 들어온 경우에는 목록을 push 한다.
void popToBoardList(
  BuildContext context,
  String listRoute, {
  List<String> aliases = const [],
}) {
  final names = <String>{listRoute, ...aliases};
  var found = false;
  Navigator.of(context).popUntil((route) {
    final name = route.settings.name;
    if (name != null && names.contains(name)) {
      found = true;
      return true;
    }
    return route.isFirst;
  });
  if (!found && context.mounted) {
    Navigator.of(context).pushNamed(listRoute);
  }
}
