import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/constants/app_assets.dart';

/// 공통으로 쓰는 하단 핑크 탭 바 (Figma)
class FooterBar extends StatelessWidget {
  const FooterBar({super.key});

  static const Color _pink = Color(0xFFFF5A8D);

  Widget _sep() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        '|',
        style: TextStyle(
          color: Color(0xCCFFFFFF),
          fontSize: 10,
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w300,
          height: 1,
        ),
      ),
    );
  }

  void _go(BuildContext context, String routeName) {
    final current = ModalRoute.of(context)?.settings.name;
    if (current == routeName) return;
    // 하단바 탭 이동 후에도 "뒤로가기"가 동작해야 하므로
    // 네비게이션 스택을 비우지 않고 push로 이동한다.
    Navigator.pushNamed(context, routeName);
  }

  Widget _item({
    required BuildContext context,
    required String label,
    required String iconAsset,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  iconAsset,
                  width: 18,
                  height: 18,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 6,
                    fontFamily: 'Gmarket Sans TTF',
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 53,
      padding: const EdgeInsets.symmetric(horizontal: 36),
      clipBehavior: Clip.antiAlias,
      decoration: const ShapeDecoration(
        color: _pink,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(15),
            topRight: Radius.circular(15),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _item(
            context: context,
            label: 'HOME',
            iconAsset: AppAssets.footerIcon1,
            onTap: () => _go(context, '/home'),
          ),
          _sep(),
          _item(
            context: context,
            label: '건강대시보드',
            iconAsset: AppAssets.footerIcon2,
            onTap: () => _go(context, '/health'),
          ),
          _sep(),
          _item(
            context: context,
            label: '비대면 진료',
            iconAsset: AppAssets.footerIcon3,
            onTap: null, // 요청대로 일단 유지
          ),
          _sep(),
          _item(
            context: context,
            label: '문진표',
            iconAsset: AppAssets.footerIcon4,
            onTap: () => _go(context, '/profile'),
          ),
          _sep(),
          _item(
            context: context,
            label: 'MY PAGE',
            iconAsset: AppAssets.footerIcon5,
            onTap: () => _go(context, '/my_page'),
          ),
        ],
      ),
    );
  }
}
