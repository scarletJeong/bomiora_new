import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/constants/app_assets.dart';
import '../../data/models/notification/app_notification_model.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/notification_inbox_service.dart';
import '../common/widgets/centered_empty_state.dart';
import '../common/widgets/mobile_layout_wrapper.dart';
import '../health/health_common/health_responsive_scale.dart';
import '../health/health_common/widgets/health_app_bar.dart';
import 'notification_settings_screen.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  static const String _font = 'Gmarket Sans TTF';
  static const Color _kBorder = Color(0xFFD2D2D2);
  static const Color _kText = Color(0xFF1A1A1A);
  static const Color _kMuted = Color(0xFF898686);
  static const Color _kPink = Color(0xFFFF5A8D);

  int _selectedTab = 0;
  bool _isLoading = true;
  bool _isLoggedIn = false;
  List<AppNotificationItem> _items = [];

  @override
  void initState() {
    super.initState();
    NotificationInboxService.revision.addListener(_onInboxChanged);
    _loadNotifications();
  }

  @override
  void dispose() {
    NotificationInboxService.revision.removeListener(_onInboxChanged);
    super.dispose();
  }

  void _onInboxChanged() {
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final loggedIn = await AuthService.isLoggedIn();
    if (!mounted) return;

    if (!loggedIn) {
      setState(() {
        _isLoggedIn = false;
        _items = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    final items = await NotificationInboxService.fetchList(limit: 50);
    if (!mounted) return;
    setState(() {
      _isLoggedIn = true;
      _items = items;
      _isLoading = false;
    });
  }

  List<AppNotificationItem> get _filteredItems {
    if (_selectedTab == 1) {
      return _items.where((item) => !item.isRead).toList();
    }
    return _items;
  }

  int get _unreadCount => _items.where((item) => !item.isRead).length;

  void _openNotificationSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationSettingsScreen(),
      ),
    );
  }

  Future<void> _markAsRead(AppNotificationItem item) async {
    if (item.isRead) return;
    await NotificationInboxService.markAsRead(item.id);
    if (!mounted) return;
    setState(() {
      _items = _items
          .map((e) => e.id == item.id ? e.copyWith(isRead: true) : e)
          .toList();
    });
  }

  void _openNotification(AppNotificationItem item) {
    _markAsRead(item);
    final type = item.type?.toLowerCase() ?? '';
    final linkId = item.linkId ?? '';

    switch (type) {
      case 'contact':
      case 'inquiry':
      case 'qna':
        final wrId = int.tryParse(linkId);
        if (wrId != null && wrId > 0) {
          Navigator.pushNamed(
            context,
            '/qna-detail',
            arguments: {'wrId': wrId},
          );
        } else {
          Navigator.pushNamed(context, '/qna');
        }
        break;
      case 'login':
        Navigator.pushNamed(context, '/my_page');
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;

    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: _font),
      child: MobileAppLayoutWrapper(
        appBar: HealthAppBar(
          title: '알림센터',
          centerTitle: false,
          actions: [
            Padding(
              padding: EdgeInsets.only(right: healthDp(context, 27)),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _openNotificationSettings,
                  borderRadius: BorderRadius.circular(healthDp(context, 8)),
                  splashFactory: NoSplash.splashFactory,
                  hoverColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  child: SizedBox(
                    width: healthDp(context, 30),
                    height: healthDp(context, 30),
                    child: Center(
                      child: SvgPicture.asset(
                        AppAssets.settingsIcon,
                        width: healthDp(context, 22),
                        height: healthDp(context, 22),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        child: _isLoading
            ? Center(
                child: SizedBox(
                  width: healthDp(context, 32),
                  height: healthDp(context, 32),
                  child: const CircularProgressIndicator(color: _kPink),
                ),
              )
            : !_isLoggedIn
                ? LayoutBuilder(
                    builder: (context, constraints) {
                      return SizedBox(
                        height: constraints.maxHeight,
                        child: const CenteredEmptyState(
                          fillAvailable: true,
                          icon: Icons.notifications_none_outlined,
                          message: '로그인 후 알림을 확인할 수 있습니다.',
                        ),
                      );
                    },
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          healthDp(context, 27),
                          healthDp(context, 20),
                          healthDp(context, 27),
                          0,
                        ),
                        child: _buildTabSelector(context),
                      ),
                      SizedBox(height: healthDp(context, 14)),
                      Expanded(
                        child: RefreshIndicator(
                          color: _kPink,
                          onRefresh: _loadNotifications,
                          child: items.isEmpty
                              ? LayoutBuilder(
                                  builder: (context, constraints) {
                                    return SingleChildScrollView(
                                      physics:
                                          const AlwaysScrollableScrollPhysics(),
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          minHeight: constraints.maxHeight,
                                        ),
                                        child: const CenteredEmptyState(
                                          fillAvailable: true,
                                          icon: Icons.notifications_none_outlined,
                                          message: '표시할 알림이 없습니다.',
                                        ),
                                      ),
                                    );
                                  },
                                )
                              : ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: EdgeInsets.fromLTRB(
                                    healthDp(context, 27),
                                    0,
                                    healthDp(context, 27),
                                    healthDp(context, 20),
                                  ),
                                  children: items
                                      .map(
                                        (item) => _buildNotificationCard(
                                          context,
                                          item,
                                        ),
                                      )
                                      .toList(),
                                ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildTabSelector(BuildContext context) {
    return Container(
      height: healthDp(context, 36),
      decoration: ShapeDecoration(
        color: const Color(0xFFF9F9F9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(healthDp(context, 20)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              context,
              label: '전체',
              selected: _selectedTab == 0,
              onTap: () => setState(() => _selectedTab = 0),
            ),
          ),
          Expanded(
            child: _buildTabButton(
              context,
              label: '안읽음',
              selected: _selectedTab == 1,
              count: _unreadCount,
              onTap: () => setState(() => _selectedTab = 1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
    int? count,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(healthDp(context, 20)),
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: selected
            ? ShapeDecoration(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  side: BorderSide(
                    width: healthDp(context, 0.5),
                    color: const Color(0x7F898686),
                  ),
                  borderRadius: BorderRadius.circular(healthDp(context, 20)),
                ),
              )
            : null,
        child: count == null
            ? Text(
                label,
                style: TextStyle(
                  color: selected ? _kText : _kMuted,
                  fontSize: healthSp(context, 16),
                  fontFamily: _font,
                  fontWeight: FontWeight.w500,
                  height: 1,
                ),
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                ),
              )
            : Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: label,
                      style: TextStyle(
                        color: selected ? _kText : _kMuted,
                        fontSize: healthSp(context, 14),
                        fontFamily: _font,
                        fontWeight: FontWeight.w500,
                        height: 1,
                      ),
                    ),
                    TextSpan(
                      text: '$count',
                      style: TextStyle(
                        color: _kPink,
                        fontSize: healthSp(context, 14),
                        fontFamily: _font,
                        fontWeight: FontWeight.w700,
                        height: 1,
                      ),
                    ),
                  ],
                ),
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                ),
              ),
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context, AppNotificationItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openNotification(item),
        borderRadius: BorderRadius.circular(healthDp(context, 10)),
        child: Container(
          margin: EdgeInsets.only(bottom: healthDp(context, 10)),
          padding: EdgeInsets.symmetric(horizontal: healthDp(context, 15)),
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: healthDp(context, 0.5),
                color: _kBorder,
              ),
              borderRadius: BorderRadius.circular(healthDp(context, 10)),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: healthDp(context, 10)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.formattedDate,
                            style: TextStyle(
                              color: _kMuted,
                              fontSize: healthSp(context, 10),
                              fontFamily: _font,
                              fontWeight: FontWeight.w300,
                              letterSpacing: healthSp(context, -0.9),
                            ),
                          ),
                          SizedBox(height: healthDp(context, 6)),
                          Row(
                            children: [
                              if (!item.isRead) ...[
                                Container(
                                  width: healthDp(context, 8),
                                  height: healthDp(context, 8),
                                  decoration: const ShapeDecoration(
                                    color: _kPink,
                                    shape: OvalBorder(),
                                  ),
                                ),
                                SizedBox(width: healthDp(context, 4)),
                              ],
                              Text(
                                item.category,
                                style: TextStyle(
                                  color: _kText,
                                  fontSize: healthSp(context, 14),
                                  fontFamily: _font,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: healthSp(context, -1.26),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      borderRadius:
                          BorderRadius.circular(healthDp(context, 16)),
                      onTap: () => _markAsRead(item),
                      child: Padding(
                        padding: EdgeInsets.all(healthDp(context, 2)),
                        child: Icon(
                          Icons.close,
                          size: healthDp(context, 16),
                          color: _kMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: healthDp(context, 5)),
                Container(
                  width: double.infinity,
                  height: healthDp(context, 1),
                  color: const Color(0x7FD2D2D2),
                ),
                SizedBox(height: healthDp(context, 10)),
                if (item.description == null || item.description!.isEmpty)
                  Text(
                    item.title,
                    style: TextStyle(
                      color: _kText,
                      fontSize: healthSp(context, 12),
                      fontFamily: _font,
                      fontWeight: FontWeight.w500,
                      letterSpacing: healthSp(context, -1.08),
                    ),
                  )
                else
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: healthDp(context, 5),
                    children: [
                      Text(
                        item.title,
                        style: TextStyle(
                          color: _kText,
                          fontSize: healthSp(context, 12),
                          fontFamily: _font,
                          fontWeight: FontWeight.w500,
                          letterSpacing: healthSp(context, -1.08),
                        ),
                      ),
                      Text(
                        item.description!,
                        style: TextStyle(
                          color: _kMuted,
                          fontSize: healthSp(context, 12),
                          fontFamily: _font,
                          fontWeight: FontWeight.w500,
                          letterSpacing: healthSp(context, -1.08),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
