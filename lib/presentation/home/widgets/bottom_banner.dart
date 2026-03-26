import 'package:flutter/material.dart';
import '../../../core/constants/app_assets.dart';

class BottomBanner extends StatelessWidget {
  const BottomBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 100,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFFFDF1F7),
              Color(0xFFFFE8F0),
            ],
          ),
        ),
        child: Center(
          child: Image.asset(
            AppAssets.bomioraLogo,
            height: 44,
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}
