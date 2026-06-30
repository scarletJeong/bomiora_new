import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../core/constants/app_assets.dart';
import '../../../common/widgets/mobile_layout_wrapper.dart';
import '../../health_common/widgets/health_app_bar.dart';
import '../../health_common/health_responsive_scale.dart';
import '../../../../data/services/health_sync_service.dart';

class HealthConnectScreen extends StatefulWidget {
  const HealthConnectScreen({super.key});

  @override
  State<HealthConnectScreen> createState() => _HealthConnectScreenState();
}

class _HealthConnectScreenState extends State<HealthConnectScreen> {
  bool get _isWeb => kIsWeb;
  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;
  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;
  bool get _isSupportedPlatform => _isIOS || _isAndroid;
  bool get _canConnect => _isSupportedPlatform && !_isSyncing;

  bool _isConnected = false;
  bool _isSyncing = false;
  HealthSyncSnapshot? _snapshot;

  String get _providerLabel => _isIOS ? '애플 건강' : '삼성 헬스';

  String get _guideText {
    if (_isIOS) {
      return '애플 건강(HealthKit)과 연동해 주세요.';
    }
    if (_isAndroid) {
      return '삼성 헬스를 Health Connect와 연결한 뒤\n연동해 주세요.';
    }
    if (_isWeb) {
      return '건강 앱 연동은 모바일 앱에서만 이용할 수 있습니다.\n앱을 이용해 주세요.';
    }
    return '이 기기에서는 건강 앱 연동을 지원하지 않습니다.';
  }

  Future<void> _onConnectBarPressed() async {
    if (!_isSupportedPlatform) return;
    await _toggleConnection();
  }

  Future<void> _toggleConnection() async {
    if (_isConnected) {
      setState(() => _isConnected = false);
      return;
    }

    setState(() => _isSyncing = true);
    final result = await HealthSyncService.connectAndFetchToday();
    if (!mounted) return;

    setState(() {
      _isSyncing = false;
      _isConnected = result.success;
      if (result.success) {
        _snapshot = result.snapshot;
      }
    });

    if (!result.success && result.message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    } else if (result.success && result.message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final textScale = healthTextScaleByWidth(MediaQuery.of(context).size.width);
    return MobileAppLayoutWrapper(
      backgroundColor: Colors.white,
      appBar: const HealthAppBar(title: '연동하기'),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  healthDp(context, 27),
                  healthDp(context, 5),
                  healthDp(context, 27),
                  healthDp(context, 16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _guideText,
                      style: const TextStyle(
                        color: Color(0xFF1A1A1A),
                        fontSize: 14,
                        fontFamily: 'Gmarket Sans TTF',
                        fontWeight: FontWeight.w300,
                        height: 1.45,
                      ),
                    ),
                    SizedBox(height: healthDp(context, 40)),
                    if (_isSupportedPlatform) ...[
                      Center(child: _buildProviderBlock()),
                      if (_snapshot != null) ...[
                        SizedBox(height: healthDp(context, 32)),
                        _buildSyncedSummary(_snapshot!),
                      ],
                    ] else
                      _buildUnsupportedNotice(),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  healthDp(context, 27),
                  healthDp(context, 8),
                  healthDp(context, 27),
                  healthDp(context, 16),
                ),
                child: _buildConnectButton(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectButton() {
    return SizedBox(
      width: double.infinity,
      height: healthDp(context, 38),
      child: ElevatedButton(
        onPressed: _canConnect ? _onConnectBarPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF5A8D),
          disabledBackgroundColor:
              const Color(0xFFFF5A8D).withOpacity(0.4),
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: healthDp(context, 10)),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(healthDp(context, 10)),
          ),
        ),
        child: Text(
          _isSyncing ? '연동 중…' : '연동하기',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildProviderBlock() {
    final assetPath = _isIOS
        ? AppAssets.healthConnectApple
        : AppAssets.healthConnectSamsung;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildFullConnectMark(assetPath),
        SizedBox(height: healthDp(context, 10)),
        Text(
          _isConnected ? '$_providerLabel · 연동됨' : _providerLabel,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF898383),
            fontSize: 12,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildUnsupportedNotice() {
    final message = _isWeb
        ? '웹에서는 건강 앱과 직접 연동할 수 없습니다.\n스마트폰에서 보미오라 앱을 설치한 뒤 연동해 주세요.'
        : '건강 앱 연동은 iPhone(애플 건강)과 Android(Health Connect)에서만 이용할 수 있습니다.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9ECF1)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF555555),
          height: 1.45,
        ),
      ),
    );
  }

  Widget _buildFullConnectMark(String assetPath) {
    final size = healthDp(context, 100);
    return SizedBox(
      width: size,
      height: size,
      child: SvgPicture.asset(
        assetPath,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _buildSyncedSummary(HealthSyncSnapshot data) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9ECF1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '동기화 미리보기 (오늘)',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _buildSectionTitle('활동'),
          _buildLine(
            '걸음수',
            data.activity.steps?.toString() ?? '-',
          ),
          _buildLine(
            '이동거리',
            data.activity.distanceKm != null
                ? '${data.activity.distanceKm} km'
                : '-',
          ),
          _buildLine(
            '활동시간',
            data.activity.activeMinutes != null
                ? '${data.activity.activeMinutes}분'
                : '-',
          ),
          _buildLine(
            '칼로리 소모',
            data.activity.caloriesKcal != null
                ? '${data.activity.caloriesKcal} kcal'
                : '-',
          ),
          _buildSectionTitle('심박수'),
          _buildLine(
            '최근 심박',
            data.latestHeartRate != null ? '${data.latestHeartRate} bpm' : '-',
          ),
          _buildSectionTitle('운동'),
          if (data.workouts.isEmpty)
            _buildLine('기록', '-')
          else
            ...data.workouts.take(3).map(_buildWorkoutLine),
          if (data.workouts.length > 3)
            _buildMuted('외 ${data.workouts.length - 3}건'),
          _buildSectionTitle('체성분'),
          _buildLine(
            '체중',
            data.body?.weightKg != null ? '${data.body!.weightKg} kg' : '-',
          ),
          _buildLine(
            'BMI',
            data.body?.bmi != null ? data.body!.bmi!.toStringAsFixed(1) : '-',
          ),
          _buildSectionTitle('혈압'),
          _buildLine(
            '수축기/이완기',
            data.bloodPressure?.systolic != null ||
                    data.bloodPressure?.diastolic != null
                ? '${data.bloodPressure?.systolic ?? '-'} / ${data.bloodPressure?.diastolic ?? '-'} mmHg'
                : '-',
          ),
          _buildSectionTitle('혈당'),
          _buildLine(
            '측정값',
            data.bloodGlucose?.valueMgDl != null
                ? '${data.bloodGlucose!.valueMgDl} mg/dL'
                : '-',
          ),
          _buildLine(
            '측정 시간',
            _formatTime(data.bloodGlucose?.measuredAt),
          ),
          _buildSectionTitle('식이'),
          if (data.nutrition.isEmpty)
            _buildLine('식사 기록', '-')
          else ...[
            _buildLine(
              '섭취 칼로리 합계',
              '${_sumNutritionCalories(data.nutrition).toStringAsFixed(0)} kcal',
            ),
            ...data.nutrition.take(3).map(_buildNutritionLine),
            if (data.nutrition.length > 3)
              _buildMuted('외 ${data.nutrition.length - 3}건'),
          ],
          _buildSectionTitle('월경/여성건강'),
          if (data.menstruation.isEmpty)
            _buildLine('생리주기', '-')
          else
            ...data.menstruation.take(3).map(_buildMenstruationLine),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          fontFamily: 'Gmarket Sans TTF',
          fontWeight: FontWeight.w700,
          color: Color(0xFF333333),
        ),
      ),
    );
  }

  Widget _buildLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        '$label: $value',
        style: const TextStyle(fontSize: 12, color: Color(0xFF555555)),
      ),
    );
  }

  Widget _buildMuted(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: const TextStyle(fontSize: 11, color: Color(0xFF999999)),
      ),
    );
  }

  Widget _buildWorkoutLine(HealthWorkoutSnapshot w) {
    final hr = w.avgHeartRate != null && w.maxHeartRate != null
        ? '평균 ${w.avgHeartRate} / 최대 ${w.maxHeartRate} bpm'
        : '-';
    final speed = w.speedKmh != null ? '${w.speedKmh} km/h' : '-';
    final kcal = w.caloriesKcal != null ? '${w.caloriesKcal!.round()} kcal' : '-';
    return _buildLine(
      w.typeLabel,
      '${w.durationMinutes}분 · $hr · $speed · $kcal',
    );
  }

  Widget _buildNutritionLine(HealthNutritionSnapshot n) {
    final name = n.mealName ?? n.mealType ?? '식사';
    final nutrients = <String>[];
    if (n.proteinG != null) nutrients.add('단백질 ${n.proteinG!.toStringAsFixed(0)}g');
    if (n.fatG != null) nutrients.add('지방 ${n.fatG!.toStringAsFixed(0)}g');
    if (n.carbsG != null) nutrients.add('탄수 ${n.carbsG!.toStringAsFixed(0)}g');
    final extra = nutrients.isEmpty ? '' : ' · ${nutrients.join(', ')}';
    return _buildLine(
      name,
      '${n.caloriesKcal?.round() ?? '-'} kcal$extra',
    );
  }

  Widget _buildMenstruationLine(HealthMenstruationSnapshot m) {
    final flow = m.flowLabel != null ? ' · ${m.flowLabel}' : '';
    return _buildLine('기록', '${_formatTime(m.date)}$flow');
  }

  double _sumNutritionCalories(List<HealthNutritionSnapshot> items) {
    return items.fold<double>(
      0,
      (sum, n) => sum + (n.caloriesKcal ?? 0),
    );
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '-';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.month}/${dt.day} $h:$m';
  }
}
