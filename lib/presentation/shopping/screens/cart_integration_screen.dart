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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: healthDp(context, 5)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildTabLabel('비대면 진료', 0)),
              Expanded(child: _buildTabLabel('일반상품', 1)),
            ],
          ),
          SizedBox(height: healthDp(context, 20)),
        ],
      ),
    );
  }

  Widget _buildTabLabel(String label, int index) {
    final selected = _selectedTabIndex == index;
    return InkWell(
      onTap: () => _onTabSelected(index),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.only(bottom: healthDp(context, 10)),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              width: healthDp(context, 1),
              color: selected
                  ? const Color(0xFFFF5A8D)
                  : const Color(0xFFD2D2D2),
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected
                ? const Color(0xFFFF5A8D)
                : const Color(0xFF898686),
            fontSize: healthSp(context, 14),
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.white,
      appBar: HealthAppBar(
        title: '장바구니',
        onBack: _handleBackNavigation,
        actions: const [],
      ),
      child: _selectedTabIndex == 0
          ? cart_prescription.CartScreen(
              key: const ValueKey('prescription-cart'),
              embedInParent: true,
              backToProductId: widget.backToProductId,
              scrollHeader: _buildTabBar(),
            )
          : cart_general.CartScreen(
              key: const ValueKey('general-cart'),
              embedInParent: true,
              backToProductId: widget.backToProductId,
              scrollHeader: _buildTabBar(),
            ),
    );
  }
}
