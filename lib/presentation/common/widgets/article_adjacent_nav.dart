import 'package:flutter/material.dart';

import '../../health/health_common/health_responsive_scale.dart';
import 'app_clickable.dart';

class ArticleAdjacentItem {
  final String title;
  final VoidCallback onTap;

  const ArticleAdjacentItem({
    required this.title,
    required this.onTap,
  });
}

/// 이벤트 상세와 같은 이전글/다음글 행. 공지·이벤트·건강콘텐츠 공통.
class ArticleAdjacentNav extends StatelessWidget {
  static const Color _kBorder = Color(0x7FD2D2D2);
  static const Color _kMuted = Color(0xFF898686);
  static const String _font = 'Gmarket Sans TTF';

  final ArticleAdjacentItem? previous;
  final ArticleAdjacentItem? next;

  const ArticleAdjacentNav({
    super.key,
    this.previous,
    this.next,
  });

  bool get hasItems => previous != null || next != null;

  @override
  Widget build(BuildContext context) {
    if (!hasItems) return const SizedBox.shrink();

    return ColoredBox(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (previous != null) ...[
            Container(height: healthDp(context, 1), color: _kBorder),
            _buildRow(
              context,
              label: '이전글',
              item: previous!,
              isPrev: true,
            ),
          ],
          if (next != null) ...[
            Container(height: healthDp(context, 1), color: _kBorder),
            _buildRow(
              context,
              label: '다음글',
              item: next!,
              isPrev: false,
            ),
          ],
          Container(height: healthDp(context, 1), color: _kBorder),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context, {
    required String label,
    required ArticleAdjacentItem item,
    required bool isPrev,
  }) {
    return AppClickable(
      onTap: item.onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: healthDp(context, 27),
          vertical: healthDp(context, 12),
        ),
        child: Row(
          children: [
            Icon(
              isPrev ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: healthDp(context, 20),
              color: _kMuted,
            ),
            Text(
              label,
              style: TextStyle(
                color: _kMuted,
                fontSize: healthSp(context, 14),
                fontFamily: _font,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(width: healthDp(context, 10)),
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: healthSp(context, 14),
                  fontFamily: _font,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 하단 고정. 스크롤이 없으면 처음부터 보이고, 있으면 맨 아래에 닿을 때 보인다.
class ArticleAdjacentNavOverlay extends StatefulWidget {
  final ScrollController controller;
  final ArticleAdjacentItem? previous;
  final ArticleAdjacentItem? next;

  const ArticleAdjacentNavOverlay({
    super.key,
    required this.controller,
    this.previous,
    this.next,
  });

  @override
  State<ArticleAdjacentNavOverlay> createState() =>
      _ArticleAdjacentNavOverlayState();
}

class _ArticleAdjacentNavOverlayState extends State<ArticleAdjacentNavOverlay> {
  static const double _bottomReachPx = 24;

  bool _visible = false;

  bool get _hasItems => widget.previous != null || widget.next != null;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncInitial();
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncInitial());
    });
  }

  @override
  void didUpdateWidget(covariant ArticleAdjacentNavOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
    if (oldWidget.previous != widget.previous ||
        oldWidget.next != widget.next) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _syncInitial());
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _syncInitial() {
    if (!mounted || !_hasItems) return;
    _setVisible(_shouldShow);
  }

  void _setVisible(bool next) {
    if (_visible == next || !mounted) return;
    setState(() => _visible = next);
  }

  bool get _shouldShow {
    if (!widget.controller.hasClients) return false;
    final position = widget.controller.position;
    if (!position.hasContentDimensions) return false;
    final max = position.maxScrollExtent;
    if (max <= _bottomReachPx) return true;
    return position.pixels >= max - _bottomReachPx;
  }

  void _onScroll() {
    if (!_hasItems) return;
    _setVisible(_shouldShow);
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasItems) return const SizedBox.shrink();

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: IgnorePointer(
        ignoring: !_visible,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          offset: _visible ? Offset.zero : const Offset(0, 1),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: _visible ? 1 : 0,
            child: Material(
              color: Colors.white,
              elevation: _visible ? 2 : 0,
              child: ArticleAdjacentNav(
                previous: widget.previous,
                next: widget.next,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
