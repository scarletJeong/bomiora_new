import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';

/// AppBar 햄버거 메뉴에서 공통으로 사용하는 Drawer
class AppBarMenuTapDrawer extends StatelessWidget {
  final VoidCallback onHealthDashboardTap;

  const AppBarMenuTapDrawer({
    super.key,
    required this.onHealthDashboardTap,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFFFDF1F7),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  AppAssets.bomioraLogo,
                  height: 40,
                  color: Colors.white,
                ),
                const SizedBox(height: 8),
                const Text(
                  '보미오라 다이어트 쇼핑몰',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
              children: [
                _MenuGridItem(
                  icon: Icons.home,
                  label: '홈',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                ),
                _MenuGridItem(
                  icon: Icons.assignment,
                  label: '건강프로필',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/profile');
                  },
                ),
                _MenuGridItem(
                  icon: Icons.local_shipping,
                  label: '주문배송',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/order');
                  },
                ),
                _MenuGridItem(
                  icon: Icons.shopping_cart,
                  label: '장바구니',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                _MenuGridItem(
                  icon: Icons.card_giftcard,
                  label: '쿠폰',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/coupon');
                  },
                ),
                _MenuGridItem(
                  icon: Icons.stars,
                  label: '마일리지',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/point');
                  },
                ),
                _MenuGridItem(
                  icon: Icons.person,
                  label: 'Mypage',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/my_page');
                  },
                ),
                _MenuGridItem(
                  icon: Icons.headset_mic,
                  label: '고객센터',
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            title: const Text('건강대시보드'),
            onTap: onHealthDashboardTap,
          ),
          const Divider(),
          ExpansionTile(
            title: const Text('비대면 치료'),
            children: [
              ListTile(
                title: const Text('다이어트'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/product-list',
                    arguments: {
                      'categoryId': '10',
                      'categoryName': '다이어트',
                      'productKind': 'prescription',
                    },
                  );
                },
              ),
              ListTile(
                title: const Text('디톡스'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/product-list',
                    arguments: {
                      'categoryId': '20',
                      'categoryName': '디톡스',
                      'productKind': 'prescription',
                    },
                  );
                },
              ),
              ListTile(
                title: const Text('심신안정'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/product-list',
                    arguments: {
                      'categoryId': '80',
                      'categoryName': '심신안정',
                      'productKind': 'prescription',
                    },
                  );
                },
              ),
              ListTile(
                title: const Text('건강/면역'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(
                    context,
                    '/product-list',
                    arguments: {
                      'categoryId': '50',
                      'categoryName': '건강/면역',
                      'productKind': 'prescription',
                    },
                  );
                },
              ),
            ],
          ),
          const ListTile(
            title: Text('헬스케어 스토어'),
          ),
          const ListTile(
            title: Text('커뮤니티'),
          ),
          const ListTile(
            title: Text('챌린저'),
          ),
          const ListTile(
            title: Text('전문가 매칭'),
          ),
          const ListTile(
            title: Text('건강콘텐츠'),
          ),
        ],
      ),
    );
  }
}

class _MenuGridItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _MenuGridItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 32,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
