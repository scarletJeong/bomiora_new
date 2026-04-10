import 'package:flutter/material.dart';

import '../../../data/models/user/user_model.dart';
import '../../../data/services/auth_service.dart';
import '../../shopping/utils/get_product.dart';
import 'confirm_dialog.dart';

/// AppBar 햄버거 메뉴에서 공통으로 사용하는 Drawer (Figma 사이드 메뉴 스타일)
class AppBarMenuTapDrawer extends StatefulWidget {
  final VoidCallback onHealthDashboardTap;

  const AppBarMenuTapDrawer({
    super.key,
    required this.onHealthDashboardTap,
  });

  @override
  State<AppBarMenuTapDrawer> createState() => _AppBarMenuTapDrawerState();
}

class _AppBarMenuTapDrawerState extends State<AppBarMenuTapDrawer> {
  static const String _fontFamily = 'Gmarket Sans TTF';

  static const Color _inkTitle = Color(0xFF1A1A1A);
  static const Color _inkMuted = Color(0xFF898686);
  static const Color _divider = Color(0x7FD2D2D2);
  static const Color _logoutBorder = Color(0xFFD2D2D2);
  static const Color _brandPink = Color(0xFFFF5A8D);

  UserModel? _user;
  bool _isTelemedicineExpanded = true;

  @override
  void initState() {
    super.initState();
    _refreshUser();
  }

  Future<void> _refreshUser() async {
    final u = await AuthService.getUser();
    if (mounted) setState(() => _user = u);
  }

  String get _greetingName {
    final u = _user;
    if (u == null) return '회원';
    final n = (u.nickname != null && u.nickname!.trim().isNotEmpty)
        ? u.nickname!.trim()
        : u.name.trim();
    return n.isEmpty ? '회원' : n;
  }

  Future<void> _onLogoutPressed(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: '로그아웃',
      message: '정말 로그아웃하시겠습니까?',
      confirmText: '로그아웃',
    );

    if (confirmed) {
      await AuthService.logout();
      if (context.mounted) {
        Navigator.pop(context);
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }

  void _popAndPushNamed(BuildContext context, String route,
      {Object? arguments}) {
    Navigator.pop(context);
    Navigator.pushNamed(context, route, arguments: arguments);
  }

  Widget _buildShortcutGrid(BuildContext context) {
    Widget cell(_DrawerShortcutData d) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: _DrawerShortcut(
            icon: d.icon,
            label: d.label,
            onTap: d.onTap,
          ),
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cell(_DrawerShortcutData(
              icon: Icons.home_outlined,
              label: '홈',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/home');
              },
            )),
            cell(_DrawerShortcutData(
              icon: Icons.assignment_outlined,
              label: '문진표',
              onTap: () => _popAndPushNamed(context, '/profile'),
            )),
            cell(_DrawerShortcutData(
              icon: Icons.local_shipping_outlined,
              label: '주문배송',
              onTap: () => _popAndPushNamed(context, '/order'),
            )),
            cell(_DrawerShortcutData(
              icon: Icons.shopping_cart_outlined,
              label: '장바구니',
              onTap: () => _popAndPushNamed(context, '/cart'),
            )),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            cell(_DrawerShortcutData(
              icon: Icons.confirmation_number_outlined,
              label: '쿠폰',
              onTap: () => _popAndPushNamed(context, '/coupon'),
            )),
            cell(_DrawerShortcutData(
              icon: Icons.stars_outlined,
              label: '포인트',
              onTap: () => _popAndPushNamed(context, '/point'),
            )),
            cell(_DrawerShortcutData(
              icon: Icons.person_outline,
              label: '마이페이지',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/my_page');
              },
            )),
            cell(_DrawerShortcutData(
              icon: Icons.headset_mic_outlined,
              label: '카카오톡 상담',
              onTap: () {},
            )),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        drawerTheme: DrawerThemeData(
          width: 322,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
          ),
          scrimColor: Colors.black.withValues(alpha: 0.20),
        ),
      ),
      child: Drawer(
        backgroundColor: Colors.white,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildShortcutGrid(context),
              const SizedBox(height: 20),
              const Divider(height: 1, thickness: 1, color: _divider),
              const SizedBox(height: 10),
              _SectionRow(
                title: '건강 대시보드',
                onTap: () {
                  Navigator.pop(context);
                  widget.onHealthDashboardTap();
                },
              ),
              Theme(
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: Column(
                  children: [
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () =>
                                    _popAndPushNamed(context, '/product-main'),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    '비대면 치료',
                                    style: TextStyle(
                                      color: _inkTitle,
                                      fontSize: 16,
                                      fontFamily: _fontFamily,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: -1.44,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _isTelemedicineExpanded =
                                      !_isTelemedicineExpanded;
                                });
                              },
                              icon: Icon(
                                _isTelemedicineExpanded
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: _inkTitle,
                              ),
                            ),
                          ],
                        ),
                        AnimatedCrossFade(
                          firstChild: Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _ExpansionSubmenuWithRail(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ...productPrescriptionCategoryList.map(
                                    (item) => _SubLink(
                                      label: item.label.replaceAll('환', ''),
                                      onTap: () => _popAndPushNamed(
                                        context,
                                        '/product/',
                                        arguments: {
                                          'categoryId': item.categoryId,
                                          'categoryName': item.label,
                                          'productKind': 'prescription',
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          secondChild: const SizedBox.shrink(),
                          crossFadeState: _isTelemedicineExpanded
                              ? CrossFadeState.showFirst
                              : CrossFadeState.showSecond,
                          duration: const Duration(milliseconds: 180),
                        ),
                      ],
                    ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      initiallyExpanded: false,
                      iconColor: _inkTitle,
                      collapsedIconColor: _inkTitle,
                      title: const Text(
                        '헬스케어 스토어',
                        style: TextStyle(
                          color: _inkTitle,
                          fontSize: 16,
                          fontFamily: _fontFamily,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -1.44,
                        ),
                      ),
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      children: [
                        _ExpansionSubmenuWithRail(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: productGeneralCategoryList
                                .map(
                                  (item) => _SubLink(
                                    label: item.label,
                                    onTap: () => _popAndPushNamed(
                                      context,
                                      '/product-general/',
                                      arguments: {
                                        'categoryId': item.categoryId,
                                        'categoryName': item.label,
                                        'productKind': 'general',
                                      },
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ],
                    ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      initiallyExpanded: false,
                      iconColor: _inkTitle,
                      collapsedIconColor: _inkTitle,
                      title: const Text(
                        '건강 콘텐츠',
                        style: TextStyle(
                          color: _inkTitle,
                          fontSize: 16,
                          fontFamily: _fontFamily,
                          fontWeight: FontWeight.w500,
                          letterSpacing: -1.44,
                        ),
                      ),
                      childrenPadding: const EdgeInsets.only(bottom: 8),
                      children: [
                        _ExpansionSubmenuWithRail(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SubLink(label: '건강상식', onTap: () {}),
                              _SubLink(label: '운동가이드', onTap: () {}),
                              _SubLink(label: '추천식단', onTap: () {}),
                              _SubLink(label: '질환관리', onTap: () {}),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, thickness: 1, color: _divider),
              const SizedBox(height: 16),
              const Text(
                '최근에 본 상품',
                style: TextStyle(
                  color: _inkMuted,
                  fontSize: 12,
                  fontFamily: _fontFamily,
                  fontWeight: FontWeight.w500,
                  height: 1.32,
                ),
              ),
              const SizedBox(height: 12),
              _RecentProductsGrid(
                onTapProduct: () {
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    if (_user == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '로그인을 하세요.',
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'Gmarket Sans TTF',
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _DrawerSettingsIcon(),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/login');
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: _brandPink,
                    foregroundColor: Colors.white,
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    '로그인',
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(
                      context,
                      '/kcp-cert',
                      arguments: const {'flow': 'signup'},
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: _brandPink,
                    side: const BorderSide(color: _brandPink, width: 1),
                    padding:
                        const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    minimumSize: const Size(0, 36),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: const Text(
                    '회원가입',
                    style: TextStyle(
                      fontFamily: _fontFamily,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: const TextStyle(
                    fontSize: 16,
                    fontFamily: _fontFamily,
                    color: Colors.black,
                  ),
                  children: [
                    TextSpan(
                      text: '$_greetingName 님 ',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const TextSpan(
                      text: '안녕하세요.',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ),
            const _DrawerSettingsIcon(),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => _onLogoutPressed(context),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(84, 32),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            side: const BorderSide(color: _logoutBorder, width: 1),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            foregroundColor: const Color(0xFF898686),
          ),
          child: const Text(
            '로그아웃',
            style: TextStyle(
              fontSize: 10,
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

/// 표시만 하며 탭해도 동작 없음
class _DrawerSettingsIcon extends StatelessWidget {
  const _DrawerSettingsIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 30,
      height: 30,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xFFF3F3F3),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        child: Center(
          child: Icon(
            Icons.settings_outlined,
            size: 18,
            color: Color(0xFF898686),
          ),
        ),
      ),
    );
  }
}

/// 펼친 하위 메뉴 왼쪽에 이어지는 세로 라인
class _ExpansionSubmenuWithRail extends StatelessWidget {
  final Widget child;

  const _ExpansionSubmenuWithRail({required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          left: BorderSide(color: Color(0xFFD2D2D2), width: 1.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: child,
      ),
    );
  }
}

class _DrawerShortcutData {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerShortcutData({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

/// 4×2 그리드 셀: 마우스 호버·손가락 누름 시 아이콘·글자 #FF5A8D
class _DrawerShortcut extends StatefulWidget {
  static const String _fontFamily = 'Gmarket Sans TTF';
  static const Color _muted = Color(0xFF898686);
  static const Color _hoverPink = Color(0xFFFF5A8D);

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerShortcut({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  State<_DrawerShortcut> createState() => _DrawerShortcutState();
}

class _DrawerShortcutState extends State<_DrawerShortcut> {
  bool _hover = false;
  bool _pressed = false;

  bool get _highlight => _hover || _pressed;

  @override
  Widget build(BuildContext context) {
    final color =
        _highlight ? _DrawerShortcut._hoverPink : _DrawerShortcut._muted;
    final labelStyle = TextStyle(
      color: color,
      fontSize: 9.5,
      fontFamily: _DrawerShortcut._fontFamily,
      fontWeight: _highlight ? FontWeight.w700 : FontWeight.w500,
      height: 1.35,
    );

    final isPoint = widget.label == '포인트';
    return Material(
      color: Colors.transparent,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => setState(() => _pressed = true),
          onPointerUp: (_) => setState(() => _pressed = false),
          onPointerCancel: (_) => setState(() => _pressed = false),
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(12),
            splashColor: _DrawerShortcut._hoverPink.withValues(alpha: 0.18),
            highlightColor: _DrawerShortcut._hoverPink.withValues(alpha: 0.08),
            hoverColor: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x19000000),
                          blurRadius: 4,
                          offset: Offset(0, 0),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: isPoint
                        ? Text(
                            'P',
                            style: TextStyle(
                              color: color,
                              fontSize: 16,
                              fontFamily: _DrawerShortcut._fontFamily,
                              fontWeight: FontWeight.w700,
                            ),
                          )
                        : Icon(
                            widget.icon,
                            size: 22,
                            color: color,
                          ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.label,
                    style: labelStyle,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  static const String _fontFamily = 'Gmarket Sans TTF';

  final String title;
  final VoidCallback onTap;

  const _SectionRow({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 16,
                  fontFamily: _fontFamily,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -1.44,
                ),
              ),
            ),
            Transform.rotate(
              angle: -1.5708,
              child: const Icon(Icons.keyboard_arrow_down,
                  size: 20, color: Color(0xFF1A1A1A)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubLink extends StatelessWidget {
  static const String _fontFamily = 'Gmarket Sans TTF';

  final String label;
  final VoidCallback onTap;

  const _SubLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF898686),
              fontSize: 14,
              fontFamily: _fontFamily,
              fontWeight: FontWeight.w500,
              letterSpacing: -1.26,
            ),
          ),
        ),
      ),
    );
  }
}

/// 디자인 시안용 정적 카드 그리드 (추후 최근 본 상품 API 연동 시 교체)
class _RecentProductsGrid extends StatelessWidget {
  final VoidCallback onTapProduct;

  const _RecentProductsGrid({required this.onTapProduct});

  @override
  Widget build(BuildContext context) {
    const radius = 5.12;
    const borderColor = Color(0x7FD2D2D2);

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _RecentProductCard(
                title: '4, 5, 6단계 보미 다이어트환',
                price: '178,000원',
                onTap: onTapProduct,
                radius: radius,
                borderColor: borderColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _RecentProductCard(
                title: '보미 디톡스환 Plus',
                price: '68,000원',
                onTap: onTapProduct,
                radius: radius,
                borderColor: borderColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _RecentProductCard(
                title: '4, 5, 6단계 보미 다이어트환',
                price: '178,000원',
                onTap: onTapProduct,
                radius: radius,
                borderColor: borderColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _RecentProductCard(
                title: '보미 디톡스환 Plus',
                price: '68,000원',
                onTap: onTapProduct,
                radius: radius,
                borderColor: borderColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RecentProductCard extends StatelessWidget {
  static const String _fontFamily = 'Gmarket Sans TTF';

  final String title;
  final String price;
  final VoidCallback onTap;
  final double radius;
  final Color borderColor;

  const _RecentProductCard({
    required this.title,
    required this.price,
    required this.onTap,
    required this.radius,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(radius),
                    topRight: Radius.circular(radius),
                  ),
                  child: Container(
                    height: 100,
                    color: const Color(0xFFE8E8E8),
                    alignment: Alignment.center,
                    child: Icon(Icons.image_outlined,
                        color: Colors.grey.shade500, size: 32),
                  ),
                ),
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.favorite_border,
                        size: 12, color: Color(0xFF898686)),
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: borderColor, width: 0.51),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(radius),
                  bottomRight: Radius.circular(radius),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '보미오라한의원',
                    style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 8,
                      fontFamily: _fontFamily,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: 10,
                      fontFamily: _fontFamily,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.90,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Text(
                        '0%',
                        style: TextStyle(
                          color: Color(0xFFFF5A8D),
                          fontSize: 8,
                          fontFamily: _fontFamily,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        price,
                        style: const TextStyle(
                          color: Color(0xFF1A1A1A),
                          fontSize: 8,
                          fontFamily: _fontFamily,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
