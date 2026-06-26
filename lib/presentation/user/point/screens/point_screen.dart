import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/point_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/models/point/point_history_model.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../../common/widgets/centered_empty_state.dart';
import '../../../health/health_common/health_responsive_scale.dart';
import '../../../health/health_common/widgets/health_app_bar.dart';

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
  int _displayCount = 5;
  bool _isLoading = true;

  static const Color _pink = Color(0xFFFF5A8D);
  static const Color _border = Color(0x7FD2D2D2);
  static const Color _textMain = Color(0xFF1A1A1A);
  static const Color _textSub = Color(0xFF898686);
  static const Color _warnRed = Color(0xFFEF4444);
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
    
    try {
      final point = await PointService.getUserPoint(_currentUser!.id);
      setState(() {
        _currentPoint = point;
      });
    } catch (e) {}
  }

  Future<void> _loadPointHistory() async {
    if (_currentUser == null) return;
    
    try {
      final history = await PointService.getPointHistory(_currentUser!.id);
      setState(() {
        _pointHistory = history;
        _displayCount = 5;
        _updateDisplayedHistory();
      });
    } catch (e) {}
  }

  void _updateDisplayedHistory() {
    setState(() {
      _displayedHistory = _pointHistory.take(_displayCount).toList();
    });
  }

  void _loadMore() {
    setState(() {
      _displayCount += 5;
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
              titleFontSize: healthSp(context, 16),
              leadingIconSize: healthDp(context, 24),
              actions: [
                healthAppBarAction(
                  context: context,
                  icon: Icons.info_outline,
                  tooltip: '포인트 이용 안내',
                  iconColor: _textSub,
                  onPressed: _showPointUsageInfoSheet,
                ),
              ],
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
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: healthDp(context, 27),
          right: healthDp(context, 27),
          bottom: healthDp(context, 20),
          top: healthDp(context, 20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCurrentPointCard(),
            SizedBox(height: healthDp(context, 20)),
            if (_displayedHistory.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: healthDp(context, 40)),
                child: const CenteredEmptyState(
                  message: '포인트 내역이 없습니다.',
                ),
              )
            else ...[
              ..._displayedHistory.map(_buildHistoryCard),
              if (_displayedHistory.length < _pointHistory.length) ...[
                SizedBox(height: healthDp(context, 10)),
                _buildLoadMoreButton(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPointCard() {
    final pointText = PointService.formatPoint(_currentPoint ?? 0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: healthDp(context, 0),
        bottom: healthDp(context, 10),
      ),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(width: healthDp(context, 1), color: _border),
          borderRadius: BorderRadius.circular(healthDp(context, 7)),
        ),
      ),
      child: Column(
        children: [
          Opacity(
            opacity: 0.80,
            child: SizedBox(
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: healthDp(context, 106),
                    child: Center(
                      child: SvgPicture.asset(
                        AppAssets.pointIcon,
                        width: healthDp(context, 80),
                        height: healthDp(context, 80),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '포인트',
                style: TextStyle(
                  color: _textMain,
                  fontSize: healthSp(context, 14),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(width: healthDp(context, 2)),
              Text(
                pointText,
                style: TextStyle(
                  color: _pink,
                  fontSize: healthSp(context, 14),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showPointUsageInfoSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(healthDp(context, 16)),
        ),
      ),
      builder: (sheetContext) {
        final bottomPad = MediaQuery.paddingOf(sheetContext).bottom;
        final screenWidth = MediaQuery.sizeOf(sheetContext).width;

        return _dismissiblePointInfoSheetShell(
          context: sheetContext,
          child: SizedBox(
            width: screenWidth,
            child: _buildPointInfoSheetContent(sheetContext, bottomPad),
          ),
        );
      },
    );
  }

  /// 옵션 바텀업과 동일 — 배경(딤)은 barrier, 시트만 드래그·슬라이드
  Widget _dismissiblePointInfoSheetShell({
    required BuildContext context,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      behavior: HitTestBehavior.opaque,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: GestureDetector(
          onTap: () {},
          behavior: HitTestBehavior.deferToChild,
          child: child,
        ),
      ),
    );
  }

  Widget _buildPointInfoSheetContent(BuildContext context, double bottomPad) {
    final radius = healthDp(context, 16);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        healthDp(context, 27),
        healthDp(context, 16),
        healthDp(context, 27),
        healthDp(context, 24) + bottomPad,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 10,
            offset: Offset(0, 8),
            spreadRadius: -6,
          ),
          BoxShadow(
            color: Color(0x19000000),
            blurRadius: 25,
            offset: Offset(0, 20),
            spreadRadius: -5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: healthDp(context, 40),
              height: healthDp(context, 4),
              margin: EdgeInsets.only(bottom: healthDp(context, 16)),
              decoration: BoxDecoration(
                color: const Color(0xFFD9D9D9),
                borderRadius: BorderRadius.circular(healthDp(context, 2)),
              ),
            ),
          ),
          Text(
            '포인트 이용 안내',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _textMain,
              fontSize: healthSp(context, 16),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: healthDp(context, 16)),
          Text(
            '*100P = 100원 입니다.(1P = 1원)',
            style: TextStyle(
              color: _textMain,
              fontSize: healthSp(context, 12),
              fontWeight: FontWeight.w300,
              height: 1.5,
            ),
          ),
          SizedBox(height: healthDp(context, 8)),
          Text(
            '*2025년 8월 8일 이후 지급된 포인트는 지급일자 기준으로\n1년 후 자동소멸됩니다.',
            style: TextStyle(
              color: _textMain,
              fontSize: healthSp(context, 12),
              fontWeight: FontWeight.w300,
              height: 1.5,
            ),
          ),
          SizedBox(height: healthDp(context, 8)),
          Text(
            '*할인 적용 및 프로모션 페이지를 통한 결제 시\n포인트 사용이 불가합니다.(중복 할인 불가)',
            style: TextStyle(
              color: _warnRed,
              fontSize: healthSp(context, 12),
              fontWeight: FontWeight.w300,
              height: 1.5,
            ),
          ),
        ],
      ),
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
            SizedBox(height: healthDp(context, 8)),
            Container(height: healthDp(context, 1), color: _border),
            SizedBox(height: healthDp(context, 8)),
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
                    color: _pink,
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
            fontSize: healthSp(context, 16),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

