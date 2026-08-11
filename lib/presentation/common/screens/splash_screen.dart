import 'package:flutter/material.dart';

import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/home/banner_model.dart';
import '../../../data/models/product/product_model.dart';
import '../../../data/repositories/product/product_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/banner_service.dart';
import '../../home/screens/home_screen.dart';
import '../../shopping/widgets/product_banner_slider.dart'
    show kSharedBannerHeightBase;
import '../../health/health_common/health_responsive_scale.dart';
import '../widgets/mobile_layout_wrapper.dart';

/// 앱 시작·로그인 후 홈 진입 시 표시하는 스플래시.
/// 메인 배너·신상품 이미지가 준비된 뒤에만 홈으로 전환한다.
class SplashScreen extends StatefulWidget {
  const SplashScreen({
    super.key,
    this.checkSession = true,
    this.prefetchHome = true,
    this.homeTabIndex = 0,
  });

  /// true면 로그인/세션 유효성 검사 (앱 콜드스타트용)
  final bool checkSession;

  /// true면 홈 배너·신상품 API + 이미지 프리캐시
  final bool prefetchHome;

  final int homeTabIndex;

  static const String assetPath = 'assets/img/splashScreen.png';

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /// 네트워크 장애 시 무한 대기 방지 (이미지가 끝나면 그 전에 홈으로 감)
  static const Duration _safetyTimeout = Duration(seconds: 12);

  Widget? _readyChild;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      await _prepareApp().timeout(_safetyTimeout);
    } catch (e) {
      debugPrint('[Splash] bootstrap ended: $e');
    }

    if (!mounted) return;
    setState(() {
      _readyChild = MobileAppLayoutWrapper(
        child: HomeScreen(initialIndex: widget.homeTabIndex),
      );
    });
  }

  Future<void> _prepareApp() async {
    // 세션 확인과 메인 이미지 준비를 병렬로 — 전환은 둘 다 끝난 뒤
    await Future.wait<void>([
      if (widget.checkSession) _ensureSession(),
      if (widget.prefetchHome) _prefetchHomeContent(),
    ]);
  }

  Future<void> _ensureSession() async {
    var loggedIn = await AuthService.isLoggedIn();
    if (!loggedIn) return;
    final active = await AuthService.isSessionActive();
    if (!active) {
      await AuthService.logout();
    }
  }

  Future<void> _prefetchHomeContent() async {
    if (!mounted) return;

    final dpr = MediaQuery.devicePixelRatioOf(context);
    final screenW = MediaQuery.sizeOf(context).width;
    final bannerH = healthDp(context, kSharedBannerHeightBase);
    final bannerCacheW = (screenW * dpr).round().clamp(64, 1200);
    final bannerCacheH = (bannerH * dpr).round().clamp(64, 1200);
    final productCacheW = ((screenW / 2) * dpr).round().clamp(64, 1200);

    final results = await Future.wait<Object>([
      BannerService.fetchMobileBanners(),
      ProductRepository.getNewProducts(limit: 4),
    ]);

    if (!mounted) return;

    final banners = results[0] as List<BannerModel>;
    final products = results[1] as List<Product>;
    final ctx = context;

    final jobs = <Future<void>>[];

    for (final b in banners) {
      final url = ImageUrlHelper.resolveSiteAssetUrl(b.imageUrl);
      if (url.isEmpty) continue;
      jobs.add(
        _precacheSized(
          ctx,
          url,
          cacheWidth: bannerCacheW,
          cacheHeight: bannerCacheH,
        ),
      );
    }

    for (final p in products) {
      final url = p.displayImageUrl;
      if (url.isEmpty) continue;
      jobs.add(
        _precacheSized(ctx, url, cacheWidth: productCacheW),
      );
    }

    // 메인 이미지가 모두 준비될 때까지 대기한 뒤 홈으로 전환
    if (jobs.isNotEmpty) {
      await Future.wait(jobs);
    }
  }

  Future<void> _precacheSized(
    BuildContext context,
    String url, {
    required int cacheWidth,
    int? cacheHeight,
  }) async {
    try {
      final provider = ResizeImage(
        NetworkImage(url),
        width: cacheWidth,
        height: cacheHeight,
        allowUpscaling: false,
      );
      await precacheImage(provider, context);
    } catch (e) {
      debugPrint('[Splash] image cache fail: $url → $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_readyChild != null) {
      return _readyChild!;
    }
    return const SplashView();
  }
}

/// 스플래시 정적 UI
class SplashView extends StatelessWidget {
  const SplashView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox.expand(
        child: Image.asset(
          SplashScreen.assetPath,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}
