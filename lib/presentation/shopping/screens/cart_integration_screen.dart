import 'package:flutter/material.dart';

import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import 'cart_general_screen.dart' as cart_general;
import 'cart_screen.dart' as cart_prescription;

/// 비대면 구매 이력이 있는 회원용 통합 장바구니.
/// 탭: 비대면진료 / 일반상품 (스크롤과 함께 이동, 상단 고정 아님)
class CartIntegrationScreen extends StatefulWidget {
  final int initialTabIndex;
  final String? backToProductId;

  const CartIntegrationScreen({
    super.key,
    this.initialTabIndex = 0,
    this.backToProductId,
  });

  @override
  State<CartIntegrationScreen> createState() => _CartIntegrationScreenState();
}

class _CartIntegrationScreenState extends State<CartIntegrationScreen> {
  late int _selectedTabIndex;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex == 1 ? 1 : 0;
  }

  void _handleBackNavigation() {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  void _onTabSelected(int index) {
    if (_selectedTabIndex == index) return;
    setState(() => _selectedTabIndex = index);
  }

  Widget _buildScrollTabBar() {
    return SizedBox(
      width: double.infinity,
      height: healthDp(context, 46.5),
      child: Row(
        children: [
          Expanded(child: _buildTabLabel('비대면진료', 0)),
          Expanded(child: _buildTabLabel('일반상품', 1)),
        ],
      ),
    );
  }

  Widget _buildTabLabel(String label, int index) {
    final selected = _selectedTabIndex == index;
    return InkWell(
      onTap: () => _onTabSelected(index),
      child: SizedBox(
        height: healthDp(context, 46.5),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected
                    ? const Color(0xFF1A1A1E)
                    : const Color(0xFF6A7282),
                fontSize: healthSp(context, 15),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w500,
                height: 1.50,
                letterSpacing: -0.23,
              ),
            ),
            SizedBox(height: healthDp(context, 6)),
            Container(
              height: healthDp(context, 2),
              width: healthDp(context, 72),
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFFFF5A8D)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(healthDp(context, 1)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: HealthAppBar(
          title: '장바구니',
          centerTitle: false,
          onBack: _handleBackNavigation,
          actions: const [],
        ),
        body: IndexedStack(
          index: _selectedTabIndex,
          children: [
            cart_prescription.CartScreen(
              embedInParent: true,
              backToProductId: widget.backToProductId,
              scrollHeader: _buildScrollTabBar(),
            ),
            cart_general.CartScreen(
              embedInParent: true,
              backToProductId: widget.backToProductId,
              scrollHeader: _buildScrollTabBar(),
            ),
          ],
        ),
      ),
    );
  }
}
