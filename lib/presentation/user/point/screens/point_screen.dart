import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/point_service.dart';
import '../../../../data/models/user/user_model.dart';
import '../../../../data/models/point/point_history_model.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
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
  int _displayCount = 10; // 처음에 보여줄 개수
  bool _isLoading = true;

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
        _displayCount = 10; // 새로 로드할 때 초기화
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
      _displayCount += 10;
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
            color: Color(0xFF1A1A1A),
          ),
          child: MobileAppLayoutWrapper(
            backgroundColor: Colors.white,
            appBar: HealthAppBar(
              title: '포인트',
              titleFontSize: healthSp(context, 18),
              leadingIconSize: healthDp(context, 24),
            ),
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFFF5A8D),
                    ),
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
            SizedBox(height: healthDp(context, 10)),
            _buildRulesText(),
            SizedBox(height: healthDp(context, 20)),
            if (_displayedHistory.isEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: healthDp(context, 24)),
                child: Center(
                  child: Text(
                    '포인트 내역이 없습니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: healthSp(context, 14),
                      color: Colors.grey[600],
                      fontFamily: 'Gmarket Sans TTF',
                    ),
                  ),
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
      padding: const EdgeInsets.only(top: 5, bottom: 10),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: const BorderSide(width: 1, color: Color(0x7FD2D2D2)),
          borderRadius: BorderRadius.circular(7),
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
                  SvgPicture.asset(
                    AppAssets.pointIcon,
                    width: 80,
                    height: 80,
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
                  color: Color(0xFF1A1A1A),
                  fontSize: healthSp(context, 14),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 2),
              Text(
                pointText,
                style: TextStyle(
                  color: Color(0xFFFF5A8D),
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

  Widget _buildRulesText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '*100P = 100원 입니다.(1P = 1원)',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: healthSp(context, 12),
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '*2025년 8월 8일 이후 지급된 포인트는 지급일자 기준으로\n 1년 후 자동소멸됩니다.',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontSize: healthSp(context, 12),
            fontWeight: FontWeight.w300,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '*할인 적용 및 프로모션 페이지를 통한 결제 시 \n 포인트 사용이 불가합니다.(중복 할인 불가) ',
          style: TextStyle(
            color: Color(0xFFEF4444),
            fontSize: healthSp(context, 12),
            fontWeight: FontWeight.w300,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(PointHistory history) {
    final changeAmount = history.changeAmount;
    final sign = changeAmount >= 0 ? '+' : '-';
    final amountText = '${sign}${PointService.formatPoint(changeAmount.abs())}p';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: ShapeDecoration(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            side: const BorderSide(width: 1, color: Color(0x7FD2D2D2)),
            borderRadius: BorderRadius.circular(7),
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
                    color: Color(0xFF1A1A1A),
                    fontSize: healthSp(context, 12),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  '만료 : ${history.formattedExpireDate}',
                  style: TextStyle(
                    color: Color(0xFF898686),
                    fontSize: healthSp(context, 10),
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(height: 1, color: const Color(0x7FD2D2D2)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    history.content.isNotEmpty ? history.content : '포인트 내역',
                    style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontSize: healthSp(context, 12),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  amountText,
                  style: TextStyle(
                    color: Color(0xFFFF5A8D),
                    fontSize: healthSp(context, 14),
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
      height: 40,
      child: OutlinedButton(
        onPressed: _loadMore,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(width: 0.5, color: Color(0xFFD2D2D2)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Colors.white,
        ),
        child: Text(
          '더보기',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF898686),
            fontSize: healthSp(context, 16),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

