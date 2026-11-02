/// 목록 조회 결과. 실패에는 글을 넣지 않고, 0건은 성공일 때만 온다.
class ListLoad<T> {
  const ListLoad.success(this.items, {int? total})
      : failed = false,
        total = total ?? items.length;

  ListLoad.failure()
      : items = List<T>.empty(),
        failed = true,
        total = 0;

  final List<T> items;
  final bool failed;
  final int total;

  bool get isEmptySuccess => !failed && items.isEmpty;
}

/// 화면에 붙인 목록. 실패해도 이미 보이던 글은 유지한다.
class AppliedListLoad<T> {
  const AppliedListLoad({
    required this.items,
    required this.total,
    required this.showFailure,
    required this.failureBelow,
  });

  final List<T> items;
  final int total;

  /// 실패 안내를 띄운다. 글이 없으면 목록 자리, 있으면 목록 위.
  final bool showFailure;

  /// 더 보기가 실패한 경우. 안내를 목록 아래에 둔다.
  final bool failureBelow;

  static AppliedListLoad<T> merge<T>({
    required ListLoad<T> incoming,
    required List<T> currentItems,
    required int currentTotal,
    required bool replace,
  }) {
    if (incoming.failed) {
      final keep = List<T>.from(currentItems);
      final below = !replace && keep.isNotEmpty;
      return AppliedListLoad(
        items: keep,
        total: currentTotal,
        showFailure: true,
        failureBelow: below,
      );
    }
    if (replace) {
      return AppliedListLoad(
        items: List<T>.from(incoming.items),
        total: incoming.total,
        showFailure: false,
        failureBelow: false,
      );
    }
    return AppliedListLoad(
      items: <T>[...currentItems, ...incoming.items],
      total: incoming.total,
      showFailure: false,
      failureBelow: false,
    );
  }
}
