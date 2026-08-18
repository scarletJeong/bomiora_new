import 'package:flutter/material.dart';

import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import 'cart_general_screen.dart' as cart_general;
import 'cart_screen.dart' as cart_prescription;

/// 비대면 구매 이력이 있는 회원용 통합 장바구니.
/// 탭: 비대면진료 / 일반상품 (본문과 함께 스크롤)
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

  Widget _buildTabBar() {
    final radius = healthDp(context, 20);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        healthDp(context, 27),
        healthDp(context, 12),
        healthDp(context, 27),
        healthDp(context, 8),
      ),
      child: Container(
        width: double.infinity,
        height: healthDp(context, 35),
        decoration: ShapeDecoration(
          color: const Color(0xFFF9F9F9),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
        child: Row(
          children: [
            Expanded(child: _buildTabLabel('비대면 진료', 0, radius)),
            Expanded(child: _buildTabLabel('일반상품', 1, radius)),
          ],
        ),
      ),
    );
  }

  Widget _buildTabLabel(String label, int index, double radius) {
    final selected = _selectedTabIndex == index;
    return InkWell(
      onTap: () => _onTabSelected(index),
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        height: double.infinity,
        decoration: ShapeDecoration(
          color: selected ? Colors.white : Colors.transparent,
          shape: RoundedRectangleBorder(
            side: selected
                ? const BorderSide(width: 0.5, color: Color(0x7F898686))
                : BorderSide.none,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected
                ? const Color(0xFF1A1A1E)
                : const Color(0xFF898686),
            fontSize: healthSp(context, 13),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
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
              scrollHeader: _buildTabBar(),
            ),
            cart_general.CartScreen(
              embedInParent: true,
              backToProductId: widget.backToProductId,
              scrollHeader: _buildTabBar(),
            ),
          ],
        ),
      ),
    );
  }
}
