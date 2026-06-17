import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/constants/app_assets.dart';
import '../common/widgets/mobile_layout_wrapper.dart';
import '../health/health_common/widgets/health_app_bar.dart';
import 'notification_settings_screen.dart';
import '../health/health_common/health_responsive_scale.dart';

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

  int _selectedTab = 0; // 0: 전체, 1: 안읽음
  late final List<_NotificationItem> _items = [
    _NotificationItem(
      date: '2026. 03. 31',
      category: '공지사항',
      title: '2026년 5월 11일 시스템 서버 작업 일정 안내',
      isUnread: true,
    ),
    _NotificationItem(
      date: '2026. 03. 30',
      category: '결제완료',
      title: '보미 다이어트(신제품 프로모션, 9종 처방)',
      description: '결제가 완료되었습니다.',
      isUnread: true,
    ),
    _NotificationItem(
      date: '2026. 03. 27',
      category: '주문취소',
      title: '보미 다이어트(신제품 프로모션, 9종 처방)',
      description: '주문이 취소되었습니다.',
      isUnread: true,
    ),
    _NotificationItem(
      date: '2026. 03. 25',
      category: '포인트 적립',
      title: '30,000포인트',
      description: '적립되었습니다.',
      isUnread: true,
    ),
    _NotificationItem(
      date: '2026. 03. 24',
      category: '배송시작',
      title: '보미 다이어트(신제품 프로모션, 9종 처방)',
      description: '배송이 시작되었습니다.',
      isUnread: false,
    ),
  ];

  List<_NotificationItem> get _filteredItems {
    if (_selectedTab == 1) {
      return _items.where((item) => item.isUnread).toList();
    }
    return _items;
  }

  int get _unreadCount => _items.where((item) => item.isUnread).length;

  void _openNotificationSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const NotificationSettingsScreen(),
      ),
    );
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
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            healthDp(context, 27),
            healthDp(context, 20),
            healthDp(context, 27),
            healthDp(context, 20),
          ),
          children: [
            _buildTabSelector(context),
            SizedBox(height: healthDp(context, 14)),
            if (items.isEmpty)
              Container(
                padding: EdgeInsets.symmetric(vertical: healthDp(context, 36)),
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  shape: RoundedRectangleBorder(
                    side: BorderSide(
                      width: healthDp(context, 0.5),
                      color: _kBorder,
                    ),
                    borderRadius: BorderRadius.circular(healthDp(context, 10)),
                  ),
                ),
                child: Text(
                  '표시할 알림이 없습니다.',
                  style: TextStyle(
                    color: _kMuted,
                    fontSize: healthSp(context, 14),
                    fontFamily: _font,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else
              ...items.map((item) => _buildNotificationCard(context, item)),
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

  Widget _buildNotificationCard(BuildContext context, _NotificationItem item) {
    return Container(
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
                        item.date,
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
                          if (item.isUnread) ...[
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
                  borderRadius: BorderRadius.circular(healthDp(context, 16)),
                  onTap: () => _removeItem(item),
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
            if (item.description == null)
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
    );
  }

  void _removeItem(_NotificationItem target) {
    setState(() {
      _items.remove(target);
    });
  }
}

class _NotificationItem {
  _NotificationItem({
    required this.date,
    required this.category,
    required this.title,
    this.description,
    required this.isUnread,
  });

  final String date;
  final String category;
  final String title;
  final String? description;
  bool isUnread;
}
