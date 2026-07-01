import 'package:flutter/material.dart';
import '../widget/contact_inquiry_type_filters.dart';
import 'contact_form_screen.dart';
import 'contact_detail_screen.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/centered_empty_state.dart';
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
  int _contactCount = 0;
  /// 목록에 표시할 최대 개수(더보기/8개 단위 확장).
  int _visibleCount = 8;

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
        _contactCount = contacts.length;
        _visibleCount = contacts.length < 8 ? contacts.length : 8;
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
        _contactCount = 0;
      });
    }
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
      final total = _contacts.length;
      _visibleCount =
          (_visibleCount + 8 > total) ? total : _visibleCount + 8;
    });
  }

  String _statusLabel(Contact contact) {
    if (contact.followupCount > 0 && !contact.latestAnswered) return '재문의';
    if (contact.latestAnswered) return '답변완료';
    return '접수완료';
  }

  Widget _buildCountRow() {
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
                text: '$_contactCount',
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
                    SizedBox(height: healthDp(context, 0.5)),
                    Text(
                      contact.wrSubject.isEmpty
                          ? '(제목 없음)'
                          : contact.wrSubject,
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
                    Text(
                      _statusLabel(contact),
                      style: _contactText(
                        context,
                        size: 12,
                        color: _muted,
                        letterSpacing: -1.08,
                      ),
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

  Widget _buildListBody() {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: healthDp(context, 120)),
          const Center(child: CircularProgressIndicator(color: _pink)),
        ],
      );
    }

    if (_requiresLogin) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: healthDp(context, 80)),
          _buildLoginMessage(),
        ],
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
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

    if (_contacts.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: const CenteredEmptyState(
                fillAvailable: true,
                icon: Icons.inbox_outlined,
                message: '문의내역이 없습니다.',
              ),
            ),
          );
        },
      );
    }

    final total = _contacts.length;
    final shown = _visibleCount > total ? total : _visibleCount;
    final hasMore = shown < total;

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        _pagePadH(context),
        0,
        _pagePadH(context),
        healthDp(context, 100),
      ),
      itemCount: shown + (hasMore ? 1 : 0),
      separatorBuilder: (_, __) => SizedBox(height: healthDp(context, 12)),
      itemBuilder: (context, index) {
        if (index == shown && hasMore) {
          return _buildLoadMoreButton();
        }
        return _buildContactItem(context, _contacts[index]);
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
                  if (!_requiresLogin)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: _pagePadH(context)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(height: healthDp(context, 20)),
                          _buildCountRow(),
                          SizedBox(height: healthDp(context, 20)),
                          const ContactInquiryTypeFilters(),
                          SizedBox(height: healthDp(context, 20)),
                        ],
                      ),
                    ),
                  Expanded(
                    child: RefreshIndicator(
                      color: _pink,
                      onRefresh: () => _loadContacts(fromPullRefresh: true),
                      child: _buildListBody(),
                    ),
                  ),
                  if (!_requiresLogin)
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
