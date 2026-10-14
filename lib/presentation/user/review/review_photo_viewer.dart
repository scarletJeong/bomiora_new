import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../health/health_common/health_responsive_scale.dart';

/// 리뷰 사진 크게 보기. 좌우로 넘기고, 넘기기 안내는 처음 한 번만 잠깐 보여 준다.
class ReviewPhotoViewer extends StatefulWidget {
  const ReviewPhotoViewer({
    super.key,
    required this.urls,
    this.initialIndex = 0,
  });

  final List<String> urls;
  final int initialIndex;

  static const _hintKey = 'review_photo_swipe_hint_shown';

  static Future<void> open(
    BuildContext context, {
    required List<String> urls,
    int initialIndex = 0,
  }) {
    if (urls.isEmpty) return Future.value();
    final index = initialIndex.clamp(0, urls.length - 1);
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.transparent,
        pageBuilder: (_, __, ___) => ReviewPhotoViewer(
          urls: urls,
          initialIndex: index,
        ),
      ),
    );
  }

  @override
  State<ReviewPhotoViewer> createState() => _ReviewPhotoViewerState();
}

class _ReviewPhotoViewerState extends State<ReviewPhotoViewer> {
  static const _font = 'Gmarket Sans TTF';

  late final PageController _pageController;
  late int _index;
  bool _showHint = false;
  double _hintOpacity = 1;
  Timer? _hintTimer;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.urls.length - 1);
    _pageController = PageController(initialPage: _index);
    _prepareHint();
  }

  Future<void> _prepareHint() async {
    if (widget.urls.length < 2) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted || prefs.getBool(ReviewPhotoViewer._hintKey) == true) return;
    setState(() => _showHint = true);
    _hintTimer = Timer(const Duration(milliseconds: 1800), () async {
      if (!mounted) return;
      setState(() => _hintOpacity = 0);
      await prefs.setBool(ReviewPhotoViewer._hintKey, true);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (mounted) setState(() => _showHint = false);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.urls.length) return;
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.urls.length;
    final thumb = healthDp(context, 52);
    return Material(
      color: Colors.black.withValues(alpha: 0.90),
      child: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: healthDp(context, 44),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: SizedBox(
                        width: healthDp(context, 44),
                        height: healthDp(context, 44),
                        child: Icon(
                          Icons.close,
                          color: Colors.white,
                          size: healthDp(context, 24),
                        ),
                      ),
                    ),
                  ),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${_index + 1}',
                          style: const TextStyle(color: Colors.white),
                        ),
                        TextSpan(
                          text: ' / $total',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.50),
                          ),
                        ),
                      ],
                    ),
                    style: TextStyle(
                      fontFamily: _font,
                      fontSize: healthSp(context, 14),
                      fontWeight: FontWeight.w500,
                      height: 1.29,
                      letterSpacing: healthSp(context, -1.26),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: total,
                    onPageChanged: (value) => setState(() => _index = value),
                    itemBuilder: (context, index) {
                      return Image.network(
                        widget.urls[index],
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Color(0xFF2A2A2A),
                          child: Center(
                            child: Icon(
                              Icons.image_outlined,
                              color: Colors.white54,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            AnimatedOpacity(
              opacity: _showHint ? _hintOpacity : 0,
              duration: const Duration(milliseconds: 400),
              child: Padding(
                padding: EdgeInsets.only(bottom: healthDp(context, 16)),
                child: Text(
                  '좌우로 넘겨보세요',
                  style: TextStyle(
                    fontFamily: _font,
                    color: Colors.white.withValues(alpha: 0.50),
                    fontSize: healthSp(context, 12),
                    fontWeight: FontWeight.w500,
                    height: 1.33,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(bottom: healthDp(context, 24)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < total; i++) ...[
                    if (i > 0) SizedBox(width: healthDp(context, 8)),
                    GestureDetector(
                      onTap: () => _goTo(i),
                      child: Container(
                        width: thumb,
                        height: thumb,
                        decoration: ShapeDecoration(
                          shape: RoundedRectangleBorder(
                            side: i == _index
                                ? BorderSide(
                                    width: healthDp(context, 2),
                                    strokeAlign: BorderSide.strokeAlignOutside,
                                    color: Colors.white,
                                  )
                                : BorderSide.none,
                            borderRadius:
                                BorderRadius.circular(healthDp(context, 8)),
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius:
                              BorderRadius.circular(healthDp(context, 8)),
                          child: Image.network(
                            widget.urls[i],
                            width: thumb,
                            height: thumb,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const ColoredBox(color: Color(0xFF2A2A2A)),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
