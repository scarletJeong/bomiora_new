import 'package:flutter/material.dart';
import '../widget/contact_inquiry_type_filters.dart';
import 'contact_form_screen.dart';
import 'contact_detail_screen.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/centered_empty_state.dart';
import '../../common/widgets/scroll_reveal_top_overlay.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../../../data/models/contact/contact_model.dart';
import '../../../data/services/contact_service.dart';
import '../../../core/utils/date_formatter.dart';

/// 1:1 문의 **화면(페이지)** — 앱바, 총 문의수, 문의유형 필터, 목록.
class ContactListScreen extends StatefulWidget {
  const ContactListScreen({super.key});

  @override
  State<ContactListScreen> createState() => ContactListScreenState();
}

class ContactListScreenState extends State<ContactListScreen> {
  List<Contact> _contacts = [];
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

  TextStyle _contactText(
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

  Future<void> _loadContacts({bool fromPullRefresh = false}) async {
    if (!fromPullRefresh) {
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
      final contacts = await ContactService.getMyContacts();
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        final total = _filteredContacts.length;
        _visibleCount = total < _pageSize ? total : _pageSize;
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

  List<Contact> get _filteredContacts {
    if (_selectedStatusTab == 0) {
      return _contacts.where((c) => !c.isClosed).toList();
    }
    return _contacts.where((c) => c.isClosed).toList();
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
    if (_contacts.isEmpty) return '문의내역이 없습니다.';
    return _selectedStatusTab == 0
        ? '진행 중인 문의가 없습니다.'
        : '종료된 문의가 없습니다.';
  }

  /// 탭 전환 등에서 목록을 다시 불러올 때 호출합니다.
  Future<void> refresh() => _loadContacts();

  Future<void> _openContactForm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ContactFormScreen(),
      ),
    );
    if (result == true && mounted) _loadContacts();
  }

  void _loadMore() {
    setState(() {
      final total = _filteredContacts.length;
      _visibleCount =
          (_visibleCount + _pageSize > total) ? total : _visibleCount + _pageSize;
    });
  }

  String _statusLabel(Contact contact) {
    if (contact.isClosed) return '문의종료';
    if (contact.latestAnswered) return '답변완료';
    return '답변대기';
  }

  bool _shouldShowLatestBadge(Contact contact) {
    if (contact.isClosed) return false;
    return contact.followupCount > 0 && !contact.latestAnswered;
  }

  Widget _buildLatestBadge(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: healthDp(context, 8),
        vertical: healthDp(context, 2),
      ),
      decoration: BoxDecoration(
        color: _pink,
        borderRadius: BorderRadius.circular(healthDp(context, 9999)),
      ),
      child: Text(
        '최신',
        style: _contactText(
          context,
          size: 10,
          color: Colors.black,
          weight: FontWeight.w500,
          height: 1.5,
        ),
      ),
    );
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
                style: _contactText(context, size: 12, color: _muted),
              ),
              TextSpan(
                text: '$count',
                style: _contactText(
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

  // 문의 카드
  Widget _buildContactItem(BuildContext context, Contact contact) {
    final cardRadius = healthDp(context, 16);
    final displayTitle = contactDisplayTitle(contact.wrSubject);
    final typeLabel = contactPrimaryTypeLabel(
      wrSubject: contact.wrSubject,
      caName: contact.caName,
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ContactDetailScreen(wrId: contact.wrId),
            ),
          ).then((_) => _loadContacts());
        },
        borderRadius: BorderRadius.circular(cardRadius),
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.all(healthDp(context, 16)),
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: BorderSide(width: healthDp(context, 1), color: _border),
              borderRadius: BorderRadius.circular(cardRadius),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          DateDisplayFormatter.formatYmdFromString(
                            contact.wrDatetime,
                          ),
                          style: _contactText(
                            context,
                            size: 10,
                            color: _textInk,
                            height: 1,
                          ),
                        ),
                        if (typeLabel != null) ...[
                          SizedBox(width: healthDp(context, 6)),
                          contactInquiryTypeBadge(context, typeLabel),
                        ],
                      ],
                    ),
                    SizedBox(height: healthDp(context, 0.5)),
                    Text(
                      displayTitle,
                      style: _contactText(
                        context,
                        size: 14,
                        color: _textInk,
                        letterSpacing: -1.26,
                        height: 1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: healthDp(context, 2)),
                    Row(
                      children: [
                        Text(
                          _statusLabel(contact),
                          style: _contactText(
                            context,
                            size: 12,
                            color: _muted,
                            letterSpacing: -1.08,
                          ),
                        ),
                        if (_shouldShowLatestBadge(contact)) ...[
                          SizedBox(width: healthDp(context, 6)),
                          _buildLatestBadge(context),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.black,
                size: healthDp(context, 20),
              ),
            ],
          ),
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
          style: _contactText(context, size: 16, color: _muted),
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
            style: _contactText(
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
        SizedBox(width: healthDp(context, 40)),
        divider(),
        SizedBox(width: healthDp(context, 40)),
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
          SizedBox(height: healthDp(context, 20)),
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
                  style: _contactText(context, size: 14, color: Colors.red),
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

    if (_contacts.isEmpty || _filteredContacts.isEmpty) {
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
                    height: (constraints.maxHeight -
                            healthDp(context, 200))
                        .clamp(healthDp(context, 120), double.infinity),
                  ),
                  CenteredEmptyState(
                    icon: Icons.inbox_outlined,
                    message: _emptyTabMessage,
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
                      scrollChild: RefreshIndicator(
                        color: _pink,
                        onRefresh: () => _loadContacts(fromPullRefresh: true),
                        child: _buildListBody(),
                      ),
                    ),
                  ),
                  if (!_requiresLogin && _selectedStatusTab == 0)
                    SafeArea(
                      top: false,
                      minimum: EdgeInsets.fromLTRB(
                        _pagePadH(context),
                        healthDp(context, 8),
                        _pagePadH(context),
                        healthDp(context, 12),
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
                            style: _contactText(
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
    return const CenteredEmptyState(
      icon: Icons.inbox_outlined,
      message: '로그인 후 이용 가능합니다.',
    );
  }
}
