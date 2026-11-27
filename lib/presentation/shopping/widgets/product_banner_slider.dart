import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/logging/failure_log.dart';
import '../../../core/utils/image_url_helper.dart';
import '../../../data/models/home/banner_model.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/banner_service.dart';
import '../../common/widgets/app_network_image.dart';
import '../../common/widgets/app_toast_overlay.dart';
import '../../health/health_common/health_responsive_scale.dart';

/// 홈·상품 목록 공통 배너 높이 (375 기준).
const double kSharedBannerHeightBase = 210;

/// 이미지 준비 전 카테고리별 단색 플레이스홀더 (빨→주→노→초→파→남→보).
const List<Color> kProductListBannerRainbow = [
  Color(0xFFE53935), // 빨
  Color(0xFFFB8C00), // 주
  Color(0xFFFDD835), // 노
  Color(0xFF43A047), // 초
  Color(0xFF1E88E5), // 파
  Color(0xFF3949AB), // 남
  Color(0xFF8E24AA), // 보
];

/// 일반상품 — 단백질쉐이크(`a0`) 전용 / 그 외 공통
const Color kGeneralProteinShakeBannerColor = Color(0xFF1E88E5); // 파
const Color kGeneralDefaultBannerColor = Color(0xFF8E24AA); // 보

bool isProteinShakeCategoryId(String categoryId) {
  final id = categoryId.trim().toLowerCase();
  return id == 'a0';
}

/// 상품 목록 배너 색상.
/// - 비대면: 카테고리마다 다름 (탭 순서대로 무지개)
/// - 일반: 단백질쉐이크만 별도, 나머지는 공통 1색
Color resolveProductListBannerColor({
  required String? productKind,
  required String categoryId,
  int categoryIndex = 0,
}) {
  final isGeneral = (productKind ?? '').trim().toLowerCase() == 'general';
  if (isGeneral) {
    if (isProteinShakeCategoryId(categoryId)) {
      return kGeneralProteinShakeBannerColor;
    }
    return kGeneralDefaultBannerColor;
  }

  final i = categoryIndex < 0 ? 0 : categoryIndex;
  return kProductListBannerRainbow[i % kProductListBannerRainbow.length];
}

/// 상품 목록 상단 배너 — `placement=list` 이미지를 홈 배너와 같이 표시.
class ProductBannerSlider extends StatefulWidget {
  /// 375 기준 배너 높이 — [healthDp]로 스케일.
  final double heightBase;

  /// `general` | 그 외(처방·비대면)
  final String? productKind;

  /// 현재 선택 카테고리 `ca_id`
  final String categoryId;

  /// 비대면 탭 순서 인덱스 (빈 배너 색상 배정용)
  final int categoryIndex;

  /// 부모에서 프리패치한 Future (없으면 직접 조회)
  final Future<List<BannerModel>>? bannersFuture;

  const ProductBannerSlider({
    super.key,
    this.heightBase = kSharedBannerHeightBase,
    this.productKind,
    required this.categoryId,
    this.categoryIndex = 0,
    this.bannersFuture,
  });

  @override
  State<ProductBannerSlider> createState() => _ProductBannerSliderState();
}

class _ProductBannerSliderState extends State<ProductBannerSlider> {
  static const Duration _autoSlideInterval = Duration(seconds: 4);

  int _currentIndex = 0;
  int _pageCount = 1;
  int _bannerListenToken = 0;
  Timer? _autoSlideTimer;
  late PageController _pageController;
  late Future<List<BannerModel>> _bannersFuture;
  final Set<String> _loggedImageUrls = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _bannersFuture = widget.bannersFuture ??
        BannerService.fetchListBanners(
          productKind: widget.productKind,
          categoryId: widget.categoryId,
        );
    _listenBanners(_bannersFuture);
  }

  @override
  void didUpdateWidget(covariant ProductBannerSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.bannersFuture != null &&
        widget.bannersFuture != oldWidget.bannersFuture) {
      _bannersFuture = widget.bannersFuture!;
      _listenBanners(_bannersFuture);
      return;
    }
    if (widget.bannersFuture == null &&
        ((widget.productKind ?? '') != (oldWidget.productKind ?? '') ||
            widget.categoryId != oldWidget.categoryId)) {
      final next = BannerService.fetchListBanners(
        productKind: widget.productKind,
        categoryId: widget.categoryId,
      );
      _bannersFuture = next;
      _listenBanners(next);
    }
  }

  @override
  void dispose() {
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
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

  Color get _placeholderColor => resolveProductListBannerColor(
        productKind: widget.productKind,
        categoryId: widget.categoryId,
        categoryIndex: widget.categoryIndex,
      );

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
      code: 'product.list.banner',
      mbId: user?.id ?? '',
      reason: reason,
      detail: {
        'productKind': widget.productKind ?? '',
        'categoryId': widget.categoryId,
        ...detail,
      },
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
      _showBannerNotice('링크를 열 수 없습니다.');
      return;
    }

    final inApp = raw.startsWith('/') || _isInAppHost(uri.host);
    if (!inApp) {
      await _openExternalBanner(uri, raw);
      return;
    }

    final route = raw.startsWith('/') ? raw : _inAppRoute(uri);
    if (route == '/' || route.isEmpty) {
      await _logBanner('배너 링크에 이동할 화면이 없습니다.', {'url': raw});
      _showBannerNotice('이동할 화면이 없습니다.');
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
      _showBannerNotice('화면을 열 수 없습니다.');
    }
  }

  void _showBannerNotice(String message) {
    if (!mounted) return;
    AppToastOverlay.show(context, message);
  }

  Future<void> _openExternalBanner(Uri uri, String raw) async {
    var target = uri;
    if (!target.hasScheme) {
      target = Uri.tryParse('https://$raw') ?? uri;
    }
    final scheme = target.scheme.toLowerCase();
    if (scheme != 'http' && scheme != 'https') {
      await _logBanner('배너 링크를 브라우저로 열 수 없습니다.', {'url': raw});
      _showBannerNotice('링크를 열 수 없습니다.');
      return;
    }
    try {
      final opened = await launchUrl(
        target,
        mode: LaunchMode.externalApplication,
      );
      if (opened) return;
      await _logBanner('배너 링크를 브라우저로 열 수 없습니다.', {'url': raw});
      _showBannerNotice('링크를 열 수 없습니다.');
    } catch (e) {
      await _logBanner(
        '배너 링크를 브라우저로 열 수 없습니다.',
        {'url': raw, 'error': e.toString()},
      );
      _showBannerNotice('링크를 열 수 없습니다.');
    }
  }

  Widget _buildNoticePage(
    BuildContext context,
    double bannerH,
    String message,
  ) {
    return ColoredBox(
      color: const Color(0xFFF6F6F6),
      child: SizedBox(
        width: double.infinity,
        height: bannerH,
        child: Center(
          child: Text(
            message,
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

  Widget _buildColorPlaceholder(double bannerH) {
    return Container(
      height: bannerH,
      width: double.infinity,
      color: _placeholderColor,
    );
  }

  Widget _buildFallbackPage(BuildContext context, double bannerH) {
    return _buildNoticePage(context, bannerH, '이미지가 로드되지 않았습니다');
  }

  Widget _buildImagePage(
    BuildContext context,
    BannerModel banner,
    double bannerH,
  ) {
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
    final bannerH = healthDp(context, widget.heightBase);
    final indicatorBottom = healthDp(context, 10);
    final dotSize = healthDp(context, 8);
    final dotMarginH = healthDp(context, 4);

    return FutureBuilder<List<BannerModel>>(
      future: _bannersFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildColorPlaceholder(bannerH);
        }

        if (snapshot.hasError) {
          return _buildNoticePage(
            context,
            bannerH,
            '배너를 불러오지 못했습니다.',
          );
        }

        final banners = _visibleBanners(
          snapshot.data ?? const <BannerModel>[],
        );
        if (banners.isEmpty) {
          return _buildColorPlaceholder(bannerH);
        }

        final pageCount = banners.length;
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

        return SizedBox(
          height: bannerH,
          width: double.infinity,
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
                    return _buildImagePage(
                      context,
                      banners[index],
                      bannerH,
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
