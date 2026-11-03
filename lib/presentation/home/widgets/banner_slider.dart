import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/logging/failure_log.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/home/banner_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/banner_service.dart';
import '../../common/widgets/app_network_image.dart';
import '../../health/health_common/health_responsive_scale.dart';

class BannerSlider extends StatefulWidget {
  const BannerSlider({
    super.key,
    this.bannersFuture,
    this.onPrimaryImageSettled,
  });

  /// 홈에서 우선 프리패치한 Future를 넘기면 중복 요청을 피함
  final Future<List<BannerModel>>? bannersFuture;

  /// 첫 배너 표시 준비 시 1회
  final VoidCallback? onPrimaryImageSettled;

  @override
  State<BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<BannerSlider> {
  static const Duration _autoSlideInterval = Duration(seconds: 4);

  int _currentIndex = 0;
  int _pageCount = 1;
  int _bannerListenToken = 0;
  Timer? _autoSlideTimer;
  late PageController _pageController;
  late Future<List<BannerModel>> _bannersFuture;
  bool _primarySettledNotified = false;
  final Set<String> _loggedImageUrls = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _bannersFuture =
        widget.bannersFuture ?? BannerService.fetchMobileBanners();
    _listenBanners(_bannersFuture);
  }

  void _notifyPrimarySettled() {
    if (_primarySettledNotified) return;
    _primarySettledNotified = true;
    widget.onPrimaryImageSettled?.call();
  }

  @override
  void didUpdateWidget(covariant BannerSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bannersFuture != null &&
        widget.bannersFuture != oldWidget.bannersFuture) {
      _bannersFuture = widget.bannersFuture!;
      _listenBanners(_bannersFuture);
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    final next = BannerService.fetchMobileBanners();
    setState(() {
      _bannersFuture = next;
    });
    _listenBanners(next);
  }

  void _listenBanners(Future<List<BannerModel>> future) {
    final token = ++_bannerListenToken;
    future.then((banners) {
      if (!mounted || token != _bannerListenToken) return;
      final visible = _visibleBanners(banners);
      if (visible.isEmpty) {
        unawaited(
          _logBanner(
            banners.isEmpty
                ? '배너 목록이 비어 있습니다.'
                : '이미지 주소가 있는 배너가 없습니다.',
            {'received': banners.length},
          ),
        );
      }
      _syncAutoSlide(visible.isEmpty ? 1 : visible.length);
    }, onError: (Object error, StackTrace _) {
      if (!mounted || token != _bannerListenToken) return;
      unawaited(
        _logBanner(
          '배너 목록을 불러오지 못했습니다.',
          {'error': error.toString()},
        ),
      );
      _syncAutoSlide(1);
    });
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _syncAutoSlide(int pageCount) {
    if (_pageCount == pageCount &&
        (_autoSlideTimer != null) == (pageCount > 1)) {
      return;
    }
    _pageCount = pageCount;
    _autoSlideTimer?.cancel();
    _autoSlideTimer = null;
    if (pageCount <= 1) return;
    _autoSlideTimer = Timer.periodic(_autoSlideInterval, (_) {
      if (!mounted || !_pageController.hasClients || _pageCount <= 1) return;
      final next = (_currentIndex + 1) % _pageCount;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeInOut,
      );
    });
  }

  List<BannerModel> _visibleBanners(List<BannerModel> apiBanners) {
    return apiBanners
        .where(
          (b) => ImageUrlHelper.resolveBannerImageUrl(b.imageUrl).isNotEmpty,
        )
        .toList();
  }

  bool _isInAppHost(String host) {
    final h = host.toLowerCase();
    if (h.isEmpty) return true;
    const hosts = {
      'bomiora.net',
      'www.bomiora.net',
      'bomiora.kr',
      'www.bomiora.kr',
      'bomiora0.mycafe24.com',
      'localhost',
      '127.0.0.1',
    };
    if (hosts.contains(h)) return true;
    final current = Uri.base.host.toLowerCase();
    return current.isNotEmpty && h == current;
  }

  String _inAppRoute(Uri uri) {
    var path = uri.path.trim();
    if (path.isEmpty) return '/';
    if (!path.startsWith('/')) path = '/$path';
    if (uri.hasQuery) path = '$path?${uri.query}';
    return path;
  }

  Future<void> _logBanner(
    String reason,
    Map<String, Object?> detail,
  ) async {
    final user = await AuthService.getUser();
    await FailureLog.record(
      code: 'home.banner',
      mbId: user?.id ?? '',
      reason: reason,
      detail: detail,
    );
  }

  void _logImageFailure(String url, Object error) {
    if (!_loggedImageUrls.add(url)) return;
    unawaited(
      _logBanner(
        '배너 이미지를 불러오지 못했습니다.',
        {'url': url, 'error': error.toString()},
      ),
    );
  }

  Future<void> _onTapBanner(BannerModel banner) async {
    final raw = banner.linkUrl.trim();
    if (raw.isEmpty) return;

    final uri = Uri.tryParse(raw);
    if (uri == null) {
      await _logBanner('배너 링크 형식이 올바르지 않습니다.', {'url': raw});
      return;
    }

    final inApp = raw.startsWith('/') || _isInAppHost(uri.host);
    if (!inApp) {
      await _logBanner('배너 링크가 앱 화면이 아닙니다.', {'url': raw});
      return;
    }

    final route = raw.startsWith('/') ? raw : _inAppRoute(uri);
    if (route == '/' || route.isEmpty) {
      await _logBanner('배너 링크에 이동할 화면이 없습니다.', {'url': raw});
      return;
    }
    if (!context.mounted) return;
    try {
      await Navigator.pushNamed(context, route);
    } catch (e) {
      await _logBanner(
        '등록된 화면이 없습니다.',
        {'url': raw, 'route': route, 'error': e.toString()},
      );
    }
  }

  Widget _buildFallbackPage(BuildContext context, double bannerH) {
    return ColoredBox(
      color: const Color(0xFFF6F6F6),
      child: SizedBox(
        width: double.infinity,
        height: bannerH,
        child: Center(
          child: Text(
            '이미지가 로드되지 않았습니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFF898686),
              fontSize: healthSp(context, 14),
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImagePage(
    BuildContext context,
    BannerModel banner,
    double bannerH, {
    VoidCallback? onSettled,
  }) {
    final imageUrl = ImageUrlHelper.resolveBannerImageUrl(banner.imageUrl);
    final bannerW = MediaQuery.sizeOf(context).width;
    final image = imageUrl.isEmpty
        ? _buildFallbackPage(context, bannerH)
        : AppNetworkImage(
            url: imageUrl,
            fit: BoxFit.fill,
            width: bannerW,
            height: bannerH,
            decodeWidthLogical: bannerW,
            decodeHeightLogical: bannerH,
            preferHtmlElementOnWeb: false,
            onSettled: onSettled,
            errorBuilder: (_, error, __) {
              _logImageFailure(imageUrl, error);
              return _buildFallbackPage(context, bannerH);
            },
          );

    if (banner.linkUrl.trim().isEmpty) return image;
    return GestureDetector(
      onTap: () => _onTapBanner(banner),
      child: image,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bannerH = healthDp(context, 220);
    final borderW = healthDp(context, 1);
    final indicatorBottom = healthDp(context, 10);
    final dotSize = healthDp(context, 8);
    final dotMarginH = healthDp(context, 4);

    return FutureBuilder<List<BannerModel>>(
      future: _bannersFuture,
      builder: (context, snapshot) {
        final banners = _visibleBanners(
          snapshot.data ?? const <BannerModel>[],
        );
        final pageCount = banners.isEmpty ? 1 : banners.length;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          _notifyPrimarySettled();
        });

        if (_currentIndex >= pageCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _currentIndex = 0);
            if (_pageController.hasClients) {
              _pageController.jumpToPage(0);
            }
          });
        }

        final hasMultiple = pageCount > 1;

        return Container(
          height: bannerH,
          width: double.infinity,
          color: Colors.white,
          foregroundDecoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: const Color(0xFFFF5A8D),
                width: borderW,
              ),
            ),
          ),
          child: Stack(
            children: [
              ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(
                  dragDevices: const {
                    PointerDeviceKind.touch,
                    PointerDeviceKind.mouse,
                    PointerDeviceKind.trackpad,
                    PointerDeviceKind.stylus,
                    PointerDeviceKind.unknown,
                  },
                ),
                child: PageView.builder(
                  controller: _pageController,
                  physics: hasMultiple
                      ? null
                      : const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  itemCount: pageCount,
                  itemBuilder: (context, index) {
                    if (banners.isEmpty) {
                      return _buildFallbackPage(context, bannerH);
                    }
                    return _buildImagePage(
                      context,
                      banners[index],
                      bannerH,
                      onSettled: index == 0 ? _notifyPrimarySettled : null,
                    );
                  },
                ),
              ),
              if (hasMultiple)
                Positioned(
                  bottom: indicatorBottom,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(pageCount, (index) {
                      return GestureDetector(
                        onTap: () => _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        ),
                        child: Container(
                          width: dotSize,
                          height: dotSize,
                          margin: EdgeInsets.symmetric(horizontal: dotMarginH),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _currentIndex == index
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
