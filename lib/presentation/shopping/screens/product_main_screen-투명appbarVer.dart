import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../common/widgets/appbar_menutap.dart';
import '../../common/widgets/mobile_layout_wrapper.dart';
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
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
          leading: Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.menu, color: Colors.black),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          ),
        ),
        drawer: AppBarMenuTapDrawer(
          onHealthDashboardTap: () {
            Navigator.pop(context);
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
