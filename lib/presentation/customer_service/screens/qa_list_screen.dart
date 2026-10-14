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

  double _pagePadH(BuildContext context) => healthDp(context, 20);

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
      final contacts = await QaService.getMyList(
        forceRefresh: fromPullRefresh,
      );
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
    return _selectedStatusTab == 0 ? '진행 중인 문의가 없습니다.' : '종료된 문의가 없습니다.';
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
    if (result is int && result > 0) {
      _loadContacts(preserveScroll: true);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QaDetailScreen(wrId: result),
        ),
      );
      if (mounted) _loadContacts(preserveScroll: true);
    } else if (result == true) {
      await _loadContacts();
    }
  }

  void _loadMore() {
    setState(() {
      final total = _filteredContacts.length;
      _visibleCount = (_visibleCount + _pageSize > total)
          ? total
          : _visibleCount + _pageSize;
    });
  }

  String _statusLabel(QaInquiry item) {
    if (item.isClosed) return '문의종료';
    if (item.latestAnswered) return '답변완료';
    return '답변대기';
  }

  String _firstQuestionTitle(QaInquiry item) {
    final body = item.displayQuestionText.trim().replaceAll('\n', ' ');
    if (body.isNotEmpty && !body.startsWith('[QA_CARD]')) return body;
    final fallback = item.listCardTitle.trim();
    if (fallback.isNotEmpty && fallback != '(내용 없음)') return fallback;
    return '(내용 없음)';
  }

  bool get _showPageEmptyState =>
      !_isLoading &&
      !_requiresLogin &&
      _errorMessage == null &&
      (_inquiries.isEmpty || _filteredContacts.isEmpty);

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

  String _listInquiryTypeLabel(QaInquiry item) {
    final key = item.inquiryTypeBadgeKey.trim();
    const labels = <String, String>{
      '상품문의': '상품 문의',
      '상품 문의': '상품 문의',
      '상품': '상품 문의',
      '예약/결제': '예약/결제 문의',
      '배송': '배송 문의',
      '배송 문의': '배송 문의',
      '배송문의': '배송 문의',
      '교환/반품': '교환/반품',
      '취소/환불': '취소/환불',
      '이벤트/쿠폰/회원': '이벤트/쿠폰/회원',
      '기타': '기타',
      '주문': '주문문의',
    };
    return labels[key] ?? (key.isNotEmpty ? key : '기타');
  }

  // 문의 카드
  Widget _buildContactItem(BuildContext context, QaInquiry item) {
    final typeLabel = _listInquiryTypeLabel(item);
    final content = _firstQuestionTitle(item);
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
        padding: EdgeInsets.all(healthDp(context, 16)),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(width: healthDp(context, 1), color: _border),
            borderRadius: BorderRadius.circular(r),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    typeLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _qaText(context, size: 12, color: _muted),
                  ),
                ),
                SizedBox(width: healthDp(context, 4)),
                _buildStatusBadge(context, label: status),
                SizedBox(width: healthDp(context, 4)),
                Icon(
                  Icons.chevron_right_rounded,
                  color: _muted,
                  size: healthDp(context, 16),
                ),
              ],
            ),
            SizedBox(height: healthDp(context, 6)),
            Padding(
              padding: EdgeInsets.only(right: healthDp(context, 20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    content.isNotEmpty ? content : '(내용 없음)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _qaText(
                      context,
                      size: 14,
                      color: _textInk,
                      letterSpacing: healthSp(context, -0.28),
                    ),
                  ),
                  SizedBox(height: healthDp(context, 8)),
                  Text(
                    DateDisplayFormatter.formatYmdFromString(latestDateRaw),
                    style: _qaText(context, size: 10, color: _muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, {required String label}) {
    final Color background;
    final Color foreground;
    if (label == '문의종료') {
      background = const Color(0xFFF9F9F9);
      foreground = const Color(0xFF999999);
    } else if (label == '답변완료') {
      background = const Color(0xFFE8F7EF);
      foreground = const Color(0xFF2E9E6B);
    } else {
      background = const Color(0xFFFFEAF1);
      foreground = _pink;
    }
    return Container(
      padding: EdgeInsets.all(healthDp(context, 4)),
      decoration: ShapeDecoration(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(healthDp(context, 4)),
        ),
      ),
      child: Text(
        label,
        style: _qaText(context, size: 12, color: foreground),
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
    final openCount = _inquiries.where((item) => !item.isClosed).length;
    final closedCount = _inquiries.where((item) => item.isClosed).length;

    Widget tab(String text, int count, int index) {
      final selected = _selectedStatusTab == index;
      final color = selected ? _pink : _muted;
      return InkWell(
        onTap: () => _onStatusTabChanged(index),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.only(bottom: healthDp(context, 10)),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                width: healthDp(context, 1),
                color: selected ? _pink : _loadMoreBorder,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                text,
                style: _qaText(
                  context,
                  size: 14,
                  color: color,
                  weight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (selected) ...[
                SizedBox(width: healthDp(context, 4)),
                Text(
                  '$count',
                  style: _qaText(
                    context,
                    size: 12,
                    color: color,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: tab('진행중인 문의', openCount, 0)),
        Expanded(child: tab('종료된 문의', closedCount, 1)),
      ],
    );
  }

  Widget _buildStickyHeaderContent() {
    return _buildStatusTabs();
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
          SizedBox(height: healthDp(context, 40)),
          CenteredEmptyState(
            fillAvailable: false,
            iconWidget: CenteredEmptyState.assetIcon(
              context,
              AppAssets.emptyQAIcon,
            ),
            message: '문의내역이 없습니다.',
          ),
        ],
      );
    }

    if (_inquiries.isEmpty || _filteredContacts.isEmpty) {
      return CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildListHeader()),
          const SliverFillRemaining(
            hasScrollBody: false,
            child: SizedBox.shrink(),
          ),
        ],
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
    final textScale = healthTextScaleByWidth(MediaQuery.sizeOf(context).width);

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
              leadingIconSize: healthDp(context, 16),
            ),
            child: ColoredBox(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        RefreshIndicator(
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
                        if (_showPageEmptyState)
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CenteredEmptyState(
                                iconWidget: CenteredEmptyState.assetIcon(
                                  context,
                                  AppAssets.emptyQAIcon,
                                ),
                                message: _emptyTabMessage,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!_requiresLogin)
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          healthDp(context, 20),
                          healthDp(context, 10),
                          healthDp(context, 20),
                          healthDp(context, 10),
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
                                borderRadius: BorderRadius.circular(
                                    healthDp(context, 10)),
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
