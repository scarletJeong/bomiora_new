import 'package:flutter/material.dart';

import '../../common/widgets/app_bar_menu.dart';
import '../../common/widgets/appbar_menutap.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
import '../../common/widgets/app_footer.dart';
import '../../common/widgets/navi_bar.dart';
import '../../health/health_common/health_responsive_scale.dart';
import '../widgets/product_main/product_main_sections.dart';

class ProductMainScreen extends StatefulWidget {
  const ProductMainScreen({super.key});

  @override
  State<ProductMainScreen> createState() => _ProductMainScreenState();
}

class _ProductMainScreenState extends State<ProductMainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final sectionGap = SizedBox(height: healthDp(context, 24));
    final quoteToCheckpointGap = SizedBox(height: healthDp(context, 25));

    return MobileAppLayoutWrapper(
      scaffoldKey: _scaffoldKey,
      appBar: AppBarMenu(
        onMenuPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      drawer: AppBarMenuTapDrawer(
        onHealthDashboardTap: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/health');
        },
      ),
      bottomNavigationBar: const FooterBar(),
      child: SafeArea(
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
    );
  }
}
