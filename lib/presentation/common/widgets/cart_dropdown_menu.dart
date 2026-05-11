import 'package:flutter/material.dart';

import '../../health/health_common/health_responsive_scale.dart';

/// 장바구니 분기(진료담기 / 구매담기) 드롭다운 폭 — 라벨이 한 줄로 보이도록 여유 있게.
double cartDropdownWidth(BuildContext context) => healthDp(context, 60);

class CartDropdownMenuPanel extends StatelessWidget {
  final VoidCallback onPrescriptionTap;
  final VoidCallback onShoppingTap;

  const CartDropdownMenuPanel({
    super.key,
    required this.onPrescriptionTap,
    required this.onShoppingTap,
  });

  @override
  Widget build(BuildContext context) {
    final w = cartDropdownWidth(context);
    return Container(
      width: w,
      padding: EdgeInsets.all(healthDp(context, 10)),
      decoration: ShapeDecoration(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(healthDp(context, 10)),
        ),
        shadows: const [
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 4,
            offset: Offset(0, 0),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CartDropdownMenuItem(
            label: '진료담기',
            onTap: onPrescriptionTap,
          ),
          SizedBox(height: healthDp(context, 5)),
          CartDropdownMenuItem(
            label: '구매담기',
            onTap: onShoppingTap,
          ),
        ],
      ),
    );
  }
}

class CartDropdownMenuItem extends StatefulWidget {
  final String label;
  final VoidCallback onTap;

  const CartDropdownMenuItem({
    super.key,
    required this.label,
    required this.onTap,
  });

  @override
  State<CartDropdownMenuItem> createState() => _CartDropdownMenuItemState();
}

class _CartDropdownMenuItemState extends State<CartDropdownMenuItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(6),
        hoverColor: Colors.transparent,
        splashColor: const Color(0xFFFF5A8D).withValues(alpha: 0.12),
        highlightColor: const Color(0xFFFF5A8D).withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Center(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: TextStyle(
                color: _hover ? const Color(0xFFFF5A8D) : Colors.black,
                fontSize: healthSp(context, 10),
                fontFamily: 'Gmarket Sans TTF',
                fontWeight: FontWeight.w300,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
