import 'package:flutter/material.dart';

import '../../common/widgets/app_bar_menu.dart';
import '../../common/widgets/appbar_menutap.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/app_footer.dart';
import '../../common/widgets/navi_bar.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../widgets/product_main/product_main_sections.dart';

class ProductMainScreen extends StatelessWidget {
  const ProductMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sectionGap = SizedBox(height: healthDp(context, 24));
    final quoteToCheckpointGap = SizedBox(height: healthDp(context, 25));

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
                quoteToCheckpointGap,
                const ProductMainCheckpointSection(),
                sectionGap,
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
