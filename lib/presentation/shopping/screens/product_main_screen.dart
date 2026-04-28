import 'package:flutter/material.dart';

import '../../common/widgets/app_bar_menu.dart';
import '../../common/widgets/appbar_menutap.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/app_footer.dart';
import '../../common/widgets/navi_bar.dart';
import '../widgets/product_main/product_main_sections.dart';

class ProductMainScreen extends StatelessWidget {
  const ProductMainScreen({super.key});

  static const _sectionGap = SizedBox(height: 24);
  static const _quoteToCheckpointGap = SizedBox(height: 25);

  @override
  Widget build(BuildContext context) {
    return MobileAppLayoutWrapper(
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: Builder(
            builder: (ctx) => AppBarMenu(
              onMenuPressed: () {
                if (!ctx.mounted) return;
                Scaffold.of(ctx).openDrawer();
              },
            ),
          ),
        ),
        drawer: AppBarMenuTapDrawer(
          onHealthDashboardTap: () {
            if (!context.mounted) return;
            Navigator.pop(context);
            if (!context.mounted) return;
            Navigator.pushNamed(context, '/health');
          },
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: SingleChildScrollView(
            clipBehavior: Clip.none,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ProductMainQuoteSection(),
                _quoteToCheckpointGap,
                const ProductMainCheckpointSection(),
                _sectionGap,
                const ProductMainTrustSection(),
                const ProductMainPhotoBioSection(),
                const AppFooter(),
              ],
            ),
          ),
        ),
        bottomNavigationBar: const FooterBar(),
      ),
    );
  }
}
