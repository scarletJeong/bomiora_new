import 'package:flutter/material.dart';
import 'qa_write_screen.dart';
import 'qa_detail_screen.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/centered_empty_state.dart';
import '../../common/widgets/scroll_reveal_top_overlay.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../../../core/constants/app_assets.dart';
import '../../../data/models/qa/qa_inquiry_model.dart';
import '../../../data/services/qa_service.dart';
import '../../../core/utils/date_formatter.dart';
import '../../common/widgets/app_toast_overlay.dart';

/// 1:1 문의 **화면(페이지)** — 앱바, 총 문의수, 목록.
class QaListScreen extends StatefulWidget {
  const QaListScreen({super.key});

  @override
  State<QaListScreen> createState() => QaListScreenState();
}

class QaListScreenState extends State<QaListScreen> {
  List<QaInquiry> _inquiries = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _requiresLogin = false;
  /// 0: 진행중인 문의, 1: 종료된 문의
  int _selectedStatusTab = 0;
  /// 목록에 표시할 최대 개수(더보기/5개 단위 확장).
  static const int _pageSize = 5;
  int _visibleCount = _pageSize;
  final ScrollController _scrollController = ScrollController();

  static const Color _border = Color(0x7FD2D2D2);
  static const Color _muted = Color(0xFF898686);
  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _textInk = Color(0xFF1A1A1E);
  static const Color _loadMoreBorder = Color(0xFFD2D2D2);

  double _pagePadH(BuildContext context) => healthDp(context, 27);

  TextStyle _qaText(
    BuildContext context, {
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w500,
    double? height,
    double? letterSpacing,
  }) =>
      TextStyle(
        color: color,
        fontSize: healthSp(context, size),
        fontFamily: 'Gmarket Sans TTF',
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
      );

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts({
    bool fromPullRefresh = false,
    bool preserveScroll = false,
  }) async {
    if (!fromPullRefresh && !preserveScroll) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _requiresLogin = false;
      });
    } else {
      setState(() {
        _errorMessage = null;
        _requiresLogin = false;
      });
    }

    try {
      final contacts = await QaService.getMyList();
      if (!mounted) return;
      setState(() {
        _inquiries = contacts;
        final total = _filteredContacts.length;
        if (preserveScroll) {
          if (total <= 0) {
            _visibleCount = 0;
          } else if (_visibleCount < _pageSize) {
            _visibleCount = total < _pageSize ? total : _pageSize;
          } else if (_visibleCount > total) {
            _visibleCount = total;
          }
        } else {
          _visibleCount = total < _pageSize ? total : _pageSize;
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      setState(() {
        if (message.contains('로그인')) {
          _requiresLogin = true;
          _errorMessage = null;
        } else {
          _errorMessage = '문의내역을 불러오는데 실패했습니다: $e';
        }
        _isLoading = false;
      });
    }
  }

  List<QaInquiry> get _filteredContacts {
    if (_selectedStatusTab == 0) {
      return _inquiries.where((c) => !c.isClosed).toList();
    }
    return _inquiries.where((c) => c.isClosed).toList();
  }

  void _onStatusTabChanged(int index) {
    if (_selectedStatusTab == index) return;
    setState(() {
      _selectedStatusTab = index;
      final total = _filteredContacts.length;
      _visibleCount = total < _pageSize ? total : _pageSize;
    });
  }

  String get _emptyTabMessage {
    if (_inquiries.isEmpty) return '문의내역이 없습니다.';
    return _selectedStatusTab == 0
        ? '진행 중인 문의가 없습니다.'
        : '종료된 문의가 없습니다.';
  }

  /// 탭 전환 등에 의해 외부에서 다시 불러올 때 호출합니다.
  Future<void> refresh() => _loadContacts();

  Future<void> _openContactForm() async {
    final result = await Navigator.push<Object>(
      context,
      MaterialPageRoute(
        builder: (context) => const QaWriteScreen(),
      ),
    );
    if (!mounted) return;
    if (result == true || result is int) {
      await _loadContacts();
    }
  }

  void _loadMore() {
    setState(() {
      final total = _filteredContacts.length;
      _visibleCount =
          (_visibleCount + _pageSize > total) ? total : _visibleCount + _pageSize;
    });
  }

  String _statusLabel(QaInquiry item) {
    if (item.isClosed) return '문의종료';
    if (item.latestAnswered) return '답변완료';
    return '답변대기';
  }

  String _firstQuestionTitle(QaInquiry item) {
    final body = item.displayQuestionText.trim().replaceAll('\n', ' ');
    if (body.isEmpty) return '(내용 없음)';
    return body.length > 15 ? '${body.substring(0, 15)}…' : body;
  }

  Widget _buildCountRow() {
    final count = _filteredContacts.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: healthDp(context, 1),
          color: _border,
        ),
        SizedBox(height: healthDp(context, 5)),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '총 문의수 ',
                style: _qaText(context, size: 12, color: _muted),
              ),
              TextSpan(
                text: '$count',
                style: _qaText(
                  context,
                  size: 12,
                  color: _pink,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: healthDp(context, 5)),
        Container(
          width: double.infinity,
          height: healthDp(context, 1),
          color: _border,
        ),
      ],
    );
  }

  Future<void> _deleteInquiry(QaInquiry item) async {
    try {
      final result = await QaService.delete(item.wrId);
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() {
          _inquiries.removeWhere((e) => e.wrId == item.wrId);
          final total = _filteredContacts.length;
          _visibleCount = total < _visibleCount ? total : _visibleCount;
        });
        AppToastOverlay.show(context, '문의가 삭제되었습니다.');
      } else {
        AppToastOverlay.show(
          context,
          result['message']?.toString() ?? '문의 삭제에 실패했습니다.',
        );
      }
    } catch (_) {
      if (!mounted) return;
      AppToastOverlay.show(context, '문의 삭제 중 오류가 발생했습니다.');
    }
  }

  /// 목록 카드용 — 기존 회색 배지 스타일, 문구만 문의 유형
  String _listInquiryTypeBadgeText(QaInquiry item) {
    final key = item.inquiryTypeBadgeKey.trim();
    const labels = <String, String>{
      '상품문의': '상품문의',
      '상품 문의': '상품문의',
      '상품': '상품문의',
      '예약/결제': '예약/결제',
      '배송': '배송문의',
      '배송 문의': '배송문의',
      '교환/반품': '교환/반품',
      '취소/환불': '취소/환불',
      '이벤트/쿠폰/회원': '이벤트/쿠폰/회원',
      '기타': '기타',
      '주문': '주문문의',
    };
    final label = labels[key] ?? (key.isNotEmpty ? key : '기타');
    return '[$label]';
  }

  // 문의 카드
  Widget _buildContactItem(BuildContext context, QaInquiry item) {
    final typeBadge = _listInquiryTypeBadgeText(item);
    final content = _firstQuestionTitle(item);
    final closed = item.isClosed;
    final status = _statusLabel(item);
    final latestDateRaw =
        item.wrLast.trim().isNotEmpty ? item.wrLast : item.wrDatetime;
    final r = healthDp(context, 16);

    return _SwipeDeleteQaCard(
      key: ValueKey(item.wrId),
      borderRadius: r,
      onDelete: () => _deleteInquiry(item),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => QaDetailScreen(wrId: item.wrId),
          ),
        ).then((_) {
          if (!mounted) return;
          _loadContacts(preserveScroll: true);
        });
      },
      child: Container(
          width: double.infinity,
          height: healthDp(context, 88),
          padding: EdgeInsets.fromLTRB(
            healthDp(context, 16),
            healthDp(context, 12),
            healthDp(context, 12),
            healthDp(context, 12),
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(r),
            border: Border.all(color: _border, width: healthDp(context, 1)),
            boxShadow: [
              BoxShadow(
                color: const Color(0x14000000),
                blurRadius: healthDp(context, 6),
                offset: Offset(0, healthDp(context, 2)),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: healthDp(context, 3),
                          vertical: healthDp(context, 1.5),
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(
                            healthDp(context, 3.5),
                          ),
                        ),
                        child: Text(
                          typeBadge,
                          style: TextStyle(
                            color: const Color(0xFF888888),
                            fontSize: healthSp(context, 10),
                            fontFamily: 'Gmarket Sans TTF',
                            fontWeight: FontWeight.w500,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: healthDp(context, 6)),
                    Text(
                      content.isNotEmpty ? content : '(내용 없음)',
                      style: _qaText(
                        context,
                        size: 14,
                        color: _textInk,
                        letterSpacing: healthSp(context, -1.26),
                        height: 1.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: healthDp(context, 6)),
                    Text(
                      DateDisplayFormatter.formatYmdFromString(latestDateRaw),
                      style: _qaText(
                        context,
                        size: 10,
                        color: _muted,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: healthDp(context, 8)),
              _buildStatusBadge(
                context,
                label: status,
                closed: closed,
              ),
              SizedBox(width: healthDp(context, 2)),
              Icon(
                Icons.chevron_right_rounded,
                color: _muted,
                size: healthDp(context, 20),
              ),
            ],
          ),
        ),
    );
  }

  Widget _buildStatusBadge(
    BuildContext context, {
    required String label,
    required bool closed,
  }) {
    final answered = label == '답변완료';
    final bg = closed
        ? const Color(0xFFE7E8E9)
        : answered
            ? Colors.white
            : const Color(0xFFFF5A8D);
    final fg = closed
        ? _muted
        : answered
            ? _pink
            : Colors.white;
    final border = answered
        ? Border.all(color: _pink, width: healthDp(context, 1))
        : null;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 7),
        vertical: healthDp(context, 3),
      ),
      decoration: BoxDecoration(
        color: bg,
        border: border,
        borderRadius: BorderRadius.circular(healthDp(context, 9999)),
      ),
      child: Text(
        label,
        style: _qaText(
          context,
          size: 10,
          color: fg,
          weight: FontWeight.w500,
          height: 1.2,
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return SizedBox(
      width: double.infinity,
      height: healthDp(context, 40),
      child: OutlinedButton(
        onPressed: _loadMore,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            width: healthDp(context, 0.5),
            color: _loadMoreBorder,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
          ),
          backgroundColor: Colors.white,
        ),
        child: Text(
          '더보기',
          textAlign: TextAlign.center,
          style: _qaText(context, size: 16, color: _muted),
        ),
      ),
    );
  }

  Widget _buildStatusTabs() {
    Widget tab(String text, int index) {
      final selected = _selectedStatusTab == index;
      return InkWell(
        onTap: () => _onStatusTabChanged(index),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: healthDp(context, 1),
                color: selected ? _pink : Colors.transparent,
              ),
            ),
          ),
          child: Text(
            text,
            style: _qaText(
              context,
              size: 14,
              color: selected ? _pink : const Color(0xFF898383),
              weight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      );
    }

    Widget divider() => Container(
          width: healthDp(context, 0.5),
          height: healthDp(context, 11),
          color: const Color(0xFFD2D2D2),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        tab('진행중인 문의', 0),
        SizedBox(width: healthDp(context, 60)),
        divider(),
        SizedBox(width: healthDp(context, 60)),
        tab('종료된 문의', 1),
      ],
    );
  }

  Widget _buildStickyHeaderContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildStatusTabs(),
        SizedBox(height: healthDp(context, 10)),
        _buildCountRow(),
      ],
    );
  }

  Widget _buildListHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: _pagePadH(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: healthDp(context, 5)),
          _buildStickyHeaderContent(),
          SizedBox(height: healthDp(context, 20)),
        ],
      ),
    );
  }

  Widget _buildListBody() {
    if (_isLoading) {
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (!_requiresLogin) _buildListHeader(),
          SizedBox(height: healthDp(context, 120)),
          const Center(child: CircularProgressIndicator(color: _pink)),
        ],
      );
    }

    if (_requiresLogin) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: _buildLoginMessage(),
            ),
          );
        },
      );
    }

    if (_errorMessage != null) {
      return ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          _buildListHeader(),
          SizedBox(height: healthDp(context, 80)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: _pagePadH(context)),
            child: Column(
              children: [
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: _qaText(context, size: 14, color: Colors.red),
                ),
                SizedBox(height: healthDp(context, 16)),
                ElevatedButton(
                  onPressed: _loadContacts,
                  child: const Text('다시 시도'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_inquiries.isEmpty || _filteredContacts.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                children: [
                  _buildListHeader(),
                  SizedBox(
                    height: (constraints.maxHeight - healthDp(context, 140))
                        .clamp(healthDp(context, 220), double.infinity),
                    child: Center(
                      child: CenteredEmptyState(
                        iconWidget: CenteredEmptyState.assetIcon(
                          context,
                          AppAssets.emptyQAIcon,
                        ),
                        message: _emptyTabMessage,
                      ),
                    ),
                  ),
                  SizedBox(height: healthDp(context, 40)),
                ],
              ),
            ),
          );
        },
      );
    }

    final total = _filteredContacts.length;
    final shown = _visibleCount > total ? total : _visibleCount;
    final hasMore = shown < total;

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: healthDp(context, 100)),
      itemCount: shown + (hasMore ? 1 : 0) + 1,
      separatorBuilder: (_, index) {
        if (index == 0) return const SizedBox.shrink();
        return SizedBox(height: healthDp(context, 12));
      },
      itemBuilder: (context, index) {
        if (index == 0) return _buildListHeader();
        final itemIndex = index - 1;
        final hPad = _pagePadH(context);
        if (itemIndex == shown && hasMore) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad),
            child: _buildLoadMoreButton(),
          );
        }
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: hPad),
          child: _buildContactItem(context, _filteredContacts[itemIndex]),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
    );
    final textScale =
        healthTextScaleByWidth(MediaQuery.sizeOf(context).width);

    return Theme(
      data: gmarketTheme,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(
            fontFamily: 'Gmarket Sans TTF',
            color: _textMain,
          ),
          child: MobileAppLayoutWrapper(
            backgroundColor: Colors.white,
            appBar: HealthAppBar(
              title: '1:1 문의',
              titleFontSize: healthSp(context, 16),
              leadingIconSize: healthDp(context, 24),
            ),
            child: ColoredBox(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      color: _pink,
                      displacement: healthDp(context, 40),
                      onRefresh: () => _loadContacts(fromPullRefresh: true),
                      child: ScrollRevealTopOverlay(
                        controller: _scrollController,
                        revealAfterOffset: healthDp(context, 44),
                        barPadding: EdgeInsets.fromLTRB(
                          _pagePadH(context),
                          healthDp(context, 8),
                          _pagePadH(context),
                          healthDp(context, 8),
                        ),
                        topBar: _buildStickyHeaderContent(),
                        scrollChild: _buildListBody(),
                      ),
                    ),
                  ),
                  if (!_requiresLogin && _selectedStatusTab == 0)
                    SafeArea(
                      top: false,
                      minimum: EdgeInsets.fromLTRB(
                        healthDp(context, 27),
                        healthDp(context, 0),
                        healthDp(context, 27),
                        healthDp(context, 5),
                      ),
                      child: GestureDetector(
                        onTap: _openContactForm,
                        child: Container(
                          width: double.infinity,
                          height: healthDp(context, 40),
                          padding: EdgeInsets.all(healthDp(context, 10)),
                          clipBehavior: Clip.antiAlias,
                          decoration: ShapeDecoration(
                            color: _pink,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(healthDp(context, 10)),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '1:1 문의하기',
                            style: _qaText(
                              context,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginMessage() {
    return CenteredEmptyState(
      iconWidget: CenteredEmptyState.assetIcon(
        context,
        AppAssets.emptyQAIcon,
      ),
      message: '로그인 후 이용 가능합니다.',
      trailing: CenteredEmptyState.loginButtonTrailing(
        context,
        onPressed: () async {
          await Navigator.pushNamed(context, '/login');
          if (!mounted) return;
          await _loadContacts();
        },
      ),
    );
  }
}

class _SwipeDeleteQaCard extends StatefulWidget {
  const _SwipeDeleteQaCard({
    super.key,
    required this.child,
    required this.onTap,
    required this.onDelete,
    required this.borderRadius,
  });

  final Widget child;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final double borderRadius;

  @override
  State<_SwipeDeleteQaCard> createState() => _SwipeDeleteQaCardState();
}

class _SwipeDeleteQaCardState extends State<_SwipeDeleteQaCard> {
  double _offsetX = 0;

  double _deleteWidth(BuildContext context) => healthDp(context, 72);

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    final max = _deleteWidth(context);
    setState(() {
      _offsetX = (_offsetX + details.delta.dx).clamp(-max, 0.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final max = _deleteWidth(context);
    final shouldOpen = _offsetX < -max * 0.35 ||
        (details.primaryVelocity != null && details.primaryVelocity! < -200);
    setState(() {
      _offsetX = shouldOpen ? -max : 0;
    });
  }

  void _close() {
    if (_offsetX == 0) return;
    setState(() => _offsetX = 0);
  }

  @override
  Widget build(BuildContext context) {
    final deleteW = _deleteWidth(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: deleteW,
                child: Material(
                  color: const Color(0xFFFF5A8D),
                  child: InkWell(
                    onTap: () {
                      _close();
                      widget.onDelete();
                    },
                    child: Center(
                      child: Text(
                        '삭제',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: healthSp(context, 14),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          GestureDetector(
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              transform: Matrix4.translationValues(_offsetX, 0, 0),
              child: GestureDetector(
                onTap: () {
                  if (_offsetX != 0) {
                    _close();
                    return;
                  }
                  widget.onTap();
                },
                child: widget.child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
