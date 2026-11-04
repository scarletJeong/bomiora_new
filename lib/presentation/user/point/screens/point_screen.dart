import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/point_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/models/point/point_history_model.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/centered_empty_state.dart';
import '../../../common/widgets/load_failure_notice.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';
import '../widgets/point_info_bottomup.dart';

class PointScreen extends StatefulWidget {
  const PointScreen({super.key});

  @override
  State<PointScreen> createState() => _PointScreenState();
}

class _PointScreenState extends State<PointScreen> {
  UserModel? _currentUser;
  int? _currentPoint;
  List<PointHistory> _pointHistory = [];
  List<PointHistory> _displayedHistory = [];
  static const int _initialDisplayCount = 7;
  static const int _loadMoreStep = 5;
  int _displayCount = _initialDisplayCount;
  int _selectedHistoryTab = 0;
  bool _isLoading = true;
  bool _pointFailed = false;
  bool _pointReloading = false;
  bool _historyFailed = false;
  bool _historyReloading = false;

  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _border = Color(0x7FD2D2D2);
  static const Color _textMain = Color(0xFF1A1A1E);
  static const Color _textSub = Color(0xFF898686);
  static const Color _loadMoreBorder = Color(0xFFD2D2D2);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await AuthService.getUser();
      if (user != null) {
        setState(() {
          _currentUser = user;
        });

        // 포인트 및 내역 병렬 조회
        await Future.wait([
          _loadCurrentPoint(),
          _loadPointHistory(),
        ]);
      }
    } catch (e) {
      // 스낵바 제거: 쇼핑/인증 외 화면 정책
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCurrentPoint() async {
    if (_currentUser == null) return;
    if (mounted) {
      setState(() => _pointReloading = true);
    }

    try {
      final point = await PointService.getUserPoint(_currentUser!.id);
      if (!mounted) return;
      setState(() {
        _currentPoint = point;
        _pointFailed = point == null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _currentPoint = null;
        _pointFailed = true;
      });
    } finally {
      if (mounted) {
        setState(() => _pointReloading = false);
      }
    }
  }

  Future<void> _loadPointHistory() async {
    if (_currentUser == null) return;
    if (mounted) {
      setState(() => _historyReloading = true);
    }

    try {
      final history = await PointService.getPointHistory(_currentUser!.id);
      if (!mounted) return;
      setState(() {
        _pointHistory = history;
        _historyFailed = false;
        _displayCount = _initialDisplayCount;
        _displayedHistory = _filteredHistory.take(_displayCount).toList();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _pointHistory = [];
        _displayedHistory = [];
        _historyFailed = true;
      });
    } finally {
      if (mounted) {
        setState(() => _historyReloading = false);
      }
    }
  }

  List<PointHistory> get _filteredHistory {
    if (_selectedHistoryTab == 1) {
      return _pointHistory.where((h) => h.changeAmount >= 0).toList();
    }
    if (_selectedHistoryTab == 2) {
      return _pointHistory.where((h) => h.changeAmount < 0).toList();
    }
    return _pointHistory;
  }

  void _updateDisplayedHistory() {
    setState(() {
      _displayedHistory = _filteredHistory.take(_displayCount).toList();
    });
  }

  void _onHistoryTabSelected(int index) {
    if (_selectedHistoryTab == index) return;
    setState(() {
      _selectedHistoryTab = index;
      _displayCount = _initialDisplayCount;
      _displayedHistory = _filteredHistory.take(_displayCount).toList();
    });
  }

  void _loadMore() {
    setState(() {
      _displayCount += _loadMoreStep;
      _updateDisplayedHistory();
    });
  }

  @override
  Widget build(BuildContext context) {
    final baseTheme = Theme.of(context);
    final gmarketTheme = baseTheme.copyWith(
      textTheme: baseTheme.textTheme.apply(fontFamily: 'Gmarket Sans TTF'),
      primaryTextTheme:
          baseTheme.primaryTextTheme.apply(fontFamily: 'Gmarket Sans TTF'),
    );
    final textScale =
        healthTextScaleByWidth(MediaQuery.sizeOf(context).width);

    return Theme(
      data: gmarketTheme,
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: DefaultTextStyle.merge(
          style: const TextStyle(
            fontFamily: 'Gmarket Sans TTF',
            color: _textMain,
          ),
          child: MobileAppLayoutWrapper(
            backgroundColor: Colors.white,
            appBar: HealthAppBar(
              title: '포인트',
              leadingIconSize: healthDp(context, 24),
            ),
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: _pink),
                  )
                : _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_currentUser == null) {
      return CenteredEmptyState(
        iconWidget: CenteredEmptyState.assetIcon(
          context,
          AppAssets.emptyPointIcon,
        ),
        message: '로그인 후 이용 가능합니다.',
        trailing: CenteredEmptyState.loginButtonTrailing(
          context,
          onPressed: () async {
            await Navigator.pushNamed(context, '/login');
            if (!mounted) return;
            await _loadData();
          },
        ),
      );
    }
    final showHistoryFailure = _historyFailed;
    final showEmpty = !showHistoryFailure && _displayedHistory.isEmpty;
    return Stack(
      fit: StackFit.expand,
      children: [
        Padding(
      //padding: EdgeInsets.all(healthDp(context, 20)),
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 20), vertical: healthDp(context, 10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildAvailablePointSection(),
          SizedBox(height: healthDp(context, 20)),
          _buildHistoryTabs(),
          if (showEmpty)
            const Expanded(child: SizedBox.shrink())
          else
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(top: healthDp(context, 24)),
                children: [
                  ..._displayedHistory.map(_buildHistoryCard),
                  if (_displayedHistory.length < _filteredHistory.length) ...[
                    SizedBox(height: healthDp(context, 20)),
                    _buildLoadMoreButton(),
                  ],
                ],
              ),
            ),
        ],
      ),
        ),
        if (showHistoryFailure)
          PageCenteredEmptyOverlay(
            child: _historyReloading
                ? const CircularProgressIndicator(color: _pink)
                : LoadFailureNotice(
                    message: '포인트 내역을 불러오지 못했습니다.',
                    onRetry: _loadPointHistory,
                  ),
          ),
        if (showEmpty)
          PageCenteredEmptyOverlay(
            child: CenteredEmptyState(
              iconWidget: CenteredEmptyState.assetIcon(
                context,
                AppAssets.emptyPointIcon,
              ),
              message: '포인트 내역이 없습니다.',
              trailing: [
                      Text(
                        '첫 구매를 하거나 리뷰를 남기면\n포인트가 쌓여요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color(0xFF898686),
                          fontSize: healthSp(context, 12),
                          fontFamily: 'Gmarket Sans TTF',
                          fontWeight: FontWeight.w300,
                        ),
                      ),
                    ],
            ),
          ),
      ],
    );
  }

  Widget _buildAvailablePointSection() {
    final pointText = _pointFailed
        ? ''
        : '${PointService.formatPoint(_currentPoint)} P';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '사용 가능한 포인트',
                style: TextStyle(
                  color: _textMain,
                  fontSize: healthSp(context, 14),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: healthDp(context, 4)),
              GestureDetector(
                onTap: () => showPointInfoBottomUp(context),
                behavior: HitTestBehavior.opaque,
                child: SvgPicture.asset(
                  AppAssets.guideIcon,
                  width: healthDp(context, 16),
                  height: healthDp(context, 16),
                ),
              ),
            ],
          ),
          SizedBox(height: healthDp(context, 8)),
          if (_pointReloading && !_isLoading)
            SizedBox(
              width: healthDp(context, 20),
              height: healthDp(context, 20),
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: _pink,
              ),
            )
          else if (_pointFailed)
            LoadFailureNotice(
              message: '포인트를 불러오지 못했습니다.',
              onRetry: _loadCurrentPoint,
            )
          else
            Text(
              pointText,
              style: TextStyle(
                color: _pink,
                fontSize: healthSp(context, 19),
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryTabs() {
    Widget tab(int index, String label) {
      final selected = _selectedHistoryTab == index;
      return Expanded(
        child: GestureDetector(
          onTap: () => _onHistoryTabSelected(index),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: EdgeInsets.only(bottom: healthDp(context, 10)),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  width: healthDp(context, 1),
                  color: selected ? _pink : Colors.transparent,
                ),
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                color: selected ? _pink : _textSub,
                fontSize: healthSp(context, 14),
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(0, '전체'),
        tab(1, '적립'),
        tab(2, '사용'),
      ],
    );
  }

  Widget _buildHistoryCard(PointHistory history) {
    final changeAmount = history.changeAmount;
    final sign = changeAmount >= 0 ? '+' : '-';
    final amountText = '${sign}${PointService.formatPoint(changeAmount.abs())}p';

    return Padding(
      padding: EdgeInsets.only(bottom: healthDp(context, 10)),
      child: Container(
        padding: EdgeInsets.all(healthDp(context, 15)),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: BorderSide(width: healthDp(context, 1), color: _border),
            borderRadius: BorderRadius.circular(healthDp(context, 7)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  history.formattedDate,
                  style: TextStyle(
                    color: _textMain,
                    fontSize: healthSp(context, 12),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '만료 : ${history.formattedExpireDate}',
                  style: TextStyle(
                    color: _textSub,
                    fontSize: healthSp(context, 10),
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
            SizedBox(height: healthDp(context, 10)),
            Container(height: healthDp(context, 1), color: _border),
            SizedBox(height: healthDp(context, 10)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    history.content.isNotEmpty ? history.content : '포인트 내역',
                    style: TextStyle(
                      color: _textMain,
                      fontSize: healthSp(context, 12),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(width: healthDp(context, 10)),
                Text(
                  amountText,
                  style: TextStyle(
                    color: changeAmount >= 0 ? _pink : _textMain,
                    fontSize: healthSp(context, 12),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadMoreButton() {
    return SizedBox(
      width: double.infinity,
      height: healthDp(context, 40),
      child: OutlinedButton(
        onPressed: _loadMore,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            width: healthDp(context, 0.5),
            color: _loadMoreBorder,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
          ),
          backgroundColor: Colors.white,
        ),
        child: Text(
          '더보기',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _textSub,
            fontSize: healthSp(context, 14),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

