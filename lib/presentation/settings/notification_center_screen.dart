import 'package:flutter/material.dart';
import '../common/widgets/mobile_layout_wrapper.dart';
import '../common/widgets/app_bar.dart';
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

  @override
  Widget build(BuildContext context) {
    final items = _filteredItems;
    return DefaultTextStyle.merge(
      style: const TextStyle(fontFamily: _font),
      child: MobileAppLayoutWrapper(
        appBar: HealthAppBar(
          title: '알림센터',
          centerTitle: true,
          actions: [
            IconButton(
              tooltip: '알림 설정',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationSettingsScreen(),
                ),
              ),
              icon: const Icon(
                Icons.settings_outlined,
                color: _kMuted,
                size: 22,
              ),
            ),
          ],
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(27, 24, 27, 24),
          children: [
            _buildTabSelector(),
            const SizedBox(height: 14),
            if (items.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 36),
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(width: 0.5, color: _kBorder),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  '표시할 알림이 없습니다.',
                  style: TextStyle(
                    color: _kMuted,
                    fontSize: 14,
                    fontFamily: _font,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else
              ...items.map(_buildNotificationCard),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    return Container(
      decoration: ShapeDecoration(
        color: const Color(0xFFF9F9F9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTabButton(
              label: '전체',
              selected: _selectedTab == 0,
              onTap: () => setState(() => _selectedTab = 0),
            ),
          ),
          Expanded(
            child: _buildTabButton(
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

  Widget _buildTabButton({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    int? count,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: selected
            ? ShapeDecoration(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  side: const BorderSide(width: 0.5, color: Color(0x7F898686)),
                  borderRadius: BorderRadius.circular(20),
                ),
              )
            : null,
        alignment: Alignment.center,
        child: count == null
            ? Text(
                label,
                style: TextStyle(
                  color: selected ? _kText : _kMuted,
                  fontSize: 16,
                  fontFamily: _font,
                  fontWeight: selected ? FontWeight.w500 : FontWeight.w500,
                ),
              )
            : Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: label,
                      style: TextStyle(
                        color: selected ? _kText : _kMuted,
                        fontSize: 16,
                        fontFamily: _font,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    TextSpan(
                      text: '$count',
                      style: const TextStyle(
                        color: _kPink,
                        fontSize: 16,
                        fontFamily: _font,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildNotificationCard(_NotificationItem item) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 0.5, color: _kBorder),
          borderRadius: BorderRadius.circular(10),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
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
                        style: const TextStyle(
                          color: _kMuted,
                          fontSize: 12,
                          fontFamily: _font,
                          fontWeight: FontWeight.w300,
                          letterSpacing: -1.08,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          if (item.isUnread) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const ShapeDecoration(
                                color: _kPink,
                                shape: OvalBorder(),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Text(
                            item.category,
                            style: const TextStyle(
                              color: _kText,
                              fontSize: 16,
                              fontFamily: _font,
                              fontWeight: FontWeight.w500,
                              letterSpacing: -1.44,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _removeItem(item),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close, size: 18, color: _kMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              height: 1,
              color: const Color(0x7FD2D2D2),
            ),
            const SizedBox(height: 10),
            if (item.description == null)
              Text(
                item.title,
                style: const TextStyle(
                  color: _kText,
                  fontSize: 12,
                  fontFamily: _font,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -1.08,
                ),
              )
            else
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: _kText,
                      fontSize: 12,
                      fontFamily: _font,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -1.08,
                    ),
                  ),
                  Text(
                    item.description!,
                    style: const TextStyle(
                      color: _kMuted,
                      fontSize: 12,
                      fontFamily: _font,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -1.08,
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
