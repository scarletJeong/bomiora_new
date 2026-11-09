import 'package:flutter/material.dart';

import '../../../data/models/cart/cart_item_model.dart';
import '../../../data/services/cart_service.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../../health/health_common/widgets/health_app_bar.dart';
import '../widgets/cart_add_group_card.dart';
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
  int? _prescriptionCount;
  int? _generalCount;

  @override
  void initState() {
    super.initState();
    _selectedTabIndex = widget.initialTabIndex == 1 ? 1 : 0;
    _loadTabCounts();
  }

  Future<void> _loadTabCounts() async {
    final result = await CartService.getCart();
    if (!mounted || result['success'] != true) return;
    final items = CartService.parseCartItems(result['data']);
    final prescription = _lineCount(items, prescription: true);
    final general = _lineCount(items, prescription: false);
    if (!mounted) return;
    if (_prescriptionCount == prescription && _generalCount == general) return;
    setState(() {
      _prescriptionCount ??= prescription;
      _generalCount ??= general;
    });
  }

  int _lineCount(List<CartItem> items, {required bool prescription}) {
    return cartGroupsForTab(items, prescriptionTab: prescription)
        .fold<int>(0, (sum, group) => sum + group.allItems.length);
  }

  void _setPrescriptionCount(int count) {
    if (_prescriptionCount == count) return;
    setState(() => _prescriptionCount = count);
  }

  void _setGeneralCount(int count) {
    if (_generalCount == count) return;
    setState(() => _generalCount = count);
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
              Expanded(
                child: _buildTabLabel('비대면 진료', 0, _prescriptionCount),
              ),
              Expanded(child: _buildTabLabel('일반상품', 1, _generalCount)),
            ],
          ),
          SizedBox(height: healthDp(context, 20)),
        ],
      ),
    );
  }

  Widget _buildTabLabel(String label, int index, int? count) {
    final selected = _selectedTabIndex == index;
    final color =
        selected ? const Color(0xFFFF5A8D) : const Color(0xFF898686);
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: healthSp(context, 14),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            if (count != null) ...[
              SizedBox(width: healthDp(context, 4)),
              Text(
                '$count',
                style: TextStyle(
                  color: color,
                  fontSize: healthSp(context, 12),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ],
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
          ?             cart_prescription.CartScreen(
              key: const ValueKey('prescription-cart'),
              embedInParent: true,
              backToProductId: widget.backToProductId,
              scrollHeader: _buildTabBar(),
              onDisplayedCount: _setPrescriptionCount,
            )
          : cart_general.CartScreen(
              key: const ValueKey('general-cart'),
              embedInParent: true,
              backToProductId: widget.backToProductId,
              scrollHeader: _buildTabBar(),
              onDisplayedCount: _setGeneralCount,
            ),
    );
  }
}
