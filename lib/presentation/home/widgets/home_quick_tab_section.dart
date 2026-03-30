import 'package:flutter/material.dart';

class HomeQuickTabSection extends StatelessWidget {
  const HomeQuickTabSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFFF5A8D),
            width: 1,
          ),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: const [
          Expanded(
            child: _QuickTabItem(
              icon: Icons.videocam_outlined,
              label: '비대면 진료',
            ),
          ),
          _QuickDivider(),
          Expanded(
            child: _QuickTabItem(
              icon: Icons.assignment_outlined,
              label: '문진표',
            ),
          ),
          _QuickDivider(),
          Expanded(
            child: _QuickTabItem(
              icon: Icons.bar_chart_outlined,
              label: '건강대시보드',
            ),
          ),
          _QuickDivider(),
          Expanded(
            child: _QuickTabItem(
              icon: Icons.shopping_bag_outlined,
              label: '스토어',
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickTabItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _QuickTabItem({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Align(
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 22,
                  color: const Color(0xFF8E8E8E),
                ),
              ),
              const Positioned(
                right: 1,
                top: 3,
                child: Icon(
                  Icons.circle,
                  size: 5,
                  color: Color(0xFFFF5A8D),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF666666),
            fontSize: 10,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _QuickDivider extends StatelessWidget {
  const _QuickDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 26,
      color: const Color(0xFFE5E5E5),
    );
  }
}
