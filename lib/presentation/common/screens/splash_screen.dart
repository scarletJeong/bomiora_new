import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/home/banner_model.dart';
import '../../../data/models/product/product_model.dart';
import '../../../data/repositories/product/product_repository.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/banner_service.dart';
import '../../../data/services/fcm_service_stub.dart'
    if (dart.library.io) '../../../data/services/fcm_service.dart';
import '../../home/screens/home_screen.dart';
import '../../shopping/widgets/product_banner_slider.dart'
    show kSharedBannerHeightBase;
import '../../health/health_common/health_responsive_scale.dart';
import '../widgets/app_network_image.dart';
import '../widgets/mobile_layout_wrapper.dart';

/// 앱 시작·로그인 후 홈 진입 시 표시하는 스플래시.
/// 메인 배너·신상품 이미지가 화면에 준비된 뒤에만 스플래시를 닫는다.
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
  /// 네트워크 장애 시 무한 대기 방지
  static const Duration _safetyTimeout = Duration(seconds: 15);

  bool _showSplash = true;
  Widget? _homeChild;
  final Completer<void> _aboveFoldReady = Completer<void>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      await _prepareAndRevealHome().timeout(_safetyTimeout);
    } catch (e) {
      debugPrint('[Splash] bootstrap ended: $e');
      if (!_aboveFoldReady.isCompleted) {
        _aboveFoldReady.complete();
      }
    }

    if (!mounted) return;

    // 타임아웃 등으로 홈이 아직 없으면 폴백 진입
    if (_homeChild == null) {
      setState(() {
        _homeChild = MobileAppLayoutWrapper(
          child: HomeScreen(initialIndex: widget.homeTabIndex),
        );
      });
    }

    // 한 프레임 더 기다려 첫 paint가 스플래시 아래에 그려지게 함
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    setState(() => _showSplash = false);
  }

  Future<void> _prepareAndRevealHome() async {
    Future<void>? sessionFuture;
    if (widget.checkSession) {
      sessionFuture = _ensureSession();
    }

    Future<List<BannerModel>>? bannersFuture;
    Future<List<Product>>? productsFuture;

    if (widget.prefetchHome) {
      bannersFuture = BannerService.fetchMobileBanners();
      productsFuture = ProductRepository.getNewProducts(limit: 4);
      await Future.wait<void>([
        if (sessionFuture != null) sessionFuture,
        _prefetchHomeContent(bannersFuture, productsFuture),
      ]);
    } else if (sessionFuture != null) {
      await sessionFuture;
    }

    if (!mounted) return;

    setState(() {
      _homeChild = MobileAppLayoutWrapper(
        child: HomeScreen(
          initialIndex: widget.homeTabIndex,
          bannersFuture: bannersFuture,
          newProductsFuture: productsFuture,
          onAboveFoldImagesReady: () {
            if (!_aboveFoldReady.isCompleted) {
              _aboveFoldReady.complete();
            }
          },
        ),
      );
    });

    // 홈이 마운트되어 실제 위젯 로드 콜백이 올 때까지 대기
    await _aboveFoldReady.future;
  }

  Future<void> _ensureSession() async {
    var loggedIn = await AuthService.isLoggedIn();
    if (!loggedIn) return;
    final active = await AuthService.isSessionActive();
    if (!active) {
      await AuthService.logout();
      return;
    }
    // 세션 API에서 오늘 첫접속 100P가 지급됐을 수 있음 → FCM 토큰 재등록으로 푸시 보완
    try {
      await FCMService().registerTokenWithServer();
    } catch (_) {}
  }

  Future<void> _prefetchHomeContent(
    Future<List<BannerModel>> bannersFuture,
    Future<List<Product>> productsFuture,
  ) async {
    if (!mounted) return;

    final results = await Future.wait<Object>([
      bannersFuture,
      productsFuture,
    ]);

    if (!mounted) return;

    final banners = results[0] as List<BannerModel>;
    final products = results[1] as List<Product>;
    if (!mounted) return;

    final bannerH = healthDp(context, kSharedBannerHeightBase);
    final layoutW = MediaQuery.sizeOf(context).width;
    final scale = healthTextScaleByWidth(layoutW);
    final productImageW = 150 * scale;
    final productImageH = 170 * scale;

    final jobs = <Future<void>>[];

    for (final b in banners) {
      final url = ImageUrlHelper.resolveSiteAssetUrl(b.imageUrl);
      if (url.isEmpty) continue;
      // BannerSlider의 AppNetworkImage와 동일 키
      jobs.add(
        AppNetworkImage.precacheUrl(
          context,
          url,
          width: double.infinity,
          height: bannerH,
          decodeHeightLogical: bannerH,
        ),
      );
    }

    for (final p in products) {
      final url = p.displayImageUrl.trim();
      if (url.isEmpty) continue;
      // ProductSection 카드와 동일 키
      jobs.add(
        AppNetworkImage.precacheUrl(
          context,
          url,
          width: productImageW,
          height: productImageH,
          decodeWidthLogical: productImageW,
          decodeHeightLogical: productImageH,
        ),
      );
    }

    if (jobs.isNotEmpty) {
      await Future.wait(jobs);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_homeChild != null) _homeChild!,
        if (_showSplash)
          const Positioned.fill(
            child: IgnorePointer(
              child: SplashView(),
            ),
          ),
      ],
    );
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
