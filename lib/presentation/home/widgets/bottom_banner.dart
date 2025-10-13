import 'package:flutter/material.dart';

class BottomBanner extends StatelessWidget {
  const BottomBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      child: Image.asset(
        'assets/images/bottom_banner_m1.jpg',
        fit: BoxFit.cover,
      ),
    );
  }
}
