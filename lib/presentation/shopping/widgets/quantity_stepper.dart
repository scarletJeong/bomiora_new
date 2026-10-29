import 'package:flutter/material.dart';

import '../../health/health_common/health_responsive_scale.dart';

/// 수량 조절. 바텀시트·장바구니에서 같은 크기를 쓴다.
///
/// 375 기준: 바깥 여백 4, 모서리 20, 버튼 간격 10, 버튼 28, 테두리 0.5, 숫자 14.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
  });

  final int quantity;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;

  static const Color _ink = Color(0xFF1A1A1E);
  static const Color _border = Color(0x7FD2D2D2);
  static const Color _pink = Color(0xFFFF5A8D);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(healthDp(context, 4)),
      decoration: ShapeDecoration(
        color: const Color(0xFFF6F6F6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(healthDp(context, 20)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: healthDp(context, 10),
        children: [
          _roundButton(context, Icons.remove, onDecrease),
          SizedBox(
            width: healthDp(context, 22),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '$quantity',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _ink,
                  fontSize: healthSp(context, 14),
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          _roundButton(context, Icons.add, onIncrease),
        ],
      ),
    );
  }

  Widget _roundButton(
    BuildContext context,
    IconData icon,
    VoidCallback? onTap,
  ) {
    final size = healthDp(context, 28);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: healthDp(context, 0.5),
                color: _border,
              ),
              borderRadius: BorderRadius.circular(healthDp(context, 50)),
            ),
          ),
          child: Icon(
            icon,
            size: healthDp(context, 10),
            color: onTap == null ? const Color(0xFFD2D2D2) : _pink,
          ),
        ),
      ),
    );
  }
}
