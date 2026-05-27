import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
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
  static const _kSamsung = '삼성 헬스';
  static const _kApple = '애플 건강 (HealthKit)';
  static const _kGoogle = '구글 핏';

  final Map<String, bool> _connectionState = {
    _kApple: false,
    _kSamsung: false,
    _kGoogle: false,
  };

  String? _selectedServiceName;

  bool get _isIOS => defaultTargetPlatform == TargetPlatform.iOS;
  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;
  bool _isSyncing = false;
  int? _syncedSteps;
  int? _syncedHeartRate;

  Future<void> _onConnectBarPressed() async {
    if (_selectedServiceName == null) {
      return;
    }
    await _toggleConnection(_selectedServiceName!);
  }

  Future<void> _toggleConnection(String serviceName) async {
    final isSupported = _isSupportedOnCurrentDevice(serviceName);
    if (!isSupported) {
      return;
    }

    final isConnected = _connectionState[serviceName] ?? false;
    if (isConnected) {
      setState(() {
        _connectionState[serviceName] = false;
      });
      return;
    }

    setState(() => _isSyncing = true);
    final result = await HealthSyncService.connectAndFetchToday();
    if (!mounted) return;

    setState(() {
      _isSyncing = false;
      _connectionState[serviceName] = result.success;
      if (result.success) {
        _syncedSteps = result.steps;
        _syncedHeartRate = result.heartRate;
      }
    });
  }

  bool _isSupportedOnCurrentDevice(String serviceName) {
    if (serviceName.contains('애플')) return _isIOS;
    if (serviceName.contains('삼성') || serviceName.contains('구글')) {
      return _isAndroid;
    }
    return true;
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
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            healthDp(context, 27),
            healthDp(context, 5),
            healthDp(context, 27),
            healthDp(context, 0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '사용 중인 건강 어플을 선택 후 연동해주세요.',
                style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 14,
                  fontFamily: 'Gmarket Sans TTF',
                  fontWeight: FontWeight.w300,
                ),
              ),
              SizedBox(height: healthDp(context, 40)),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: healthDp(context, 20),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: _buildProviderBlock(
                              serviceName: _kSamsung,
                              label: '삼성 헬스',
                              child: _buildFullConnectMark(
                                AppAssets.healthConnectSamsung,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: healthDp(context, 20)),
                        Expanded(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: _buildProviderBlock(
                              serviceName: _kGoogle,
                              label: 'Google Fit',
                              child: _buildGoogleConnectMark(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: healthDp(context, 20)),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.topCenter,
                            child: _buildProviderBlock(
                              serviceName: _kApple,
                              label: '애플 건강',
                              child: _buildFullConnectMark(
                                AppAssets.healthConnectApple,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: healthDp(context, 20)),
                        const Expanded(child: SizedBox()),
                      ],
                    ),
                  ],
                ),
              ),
              if (_syncedSteps != null || _syncedHeartRate != null) ...[
                SizedBox(height: healthDp(context, 32)),
                _buildSyncedSummary(),
              ],
              SizedBox(height: healthDp(context, 50)),
              _buildConnectButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConnectButton() {
    return SizedBox(
      width: double.infinity,
      height: healthDp(context, 38),
      child: FilledButton(
        onPressed: _isSyncing ? null : _onConnectBarPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFF5A8D),
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              const Color(0xFFFF5A8D).withValues(alpha: 0.5),
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
            fontSize: 16,
            fontFamily: 'Gmarket Sans TTF',
            fontWeight: FontWeight.w500,
            height: 1,
          ),
        ),
      ),
    );
  }

  Widget _buildProviderBlock({
    required String serviceName,
    required String label,
    required Widget child,
  }) {
    final connected = _connectionState[serviceName] ?? false;
    final supported = _isSupportedOnCurrentDevice(serviceName);

    return GestureDetector(
      onTap: supported
          ? () => setState(() => _selectedServiceName = serviceName)
          : null,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          SizedBox(height: healthDp(context, 10)),
          Text(
            connected ? '$label · 연동됨' : label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF898383),
              fontSize: 12,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// 삼성·애플 — SVG 전체(375 기준 100×100)를 카드로 사용.
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

  /// 구글 — 벡터 SVG, radius 10 (375 기준).
  Widget _buildGoogleConnectMark() {
    final size = healthDp(context, 100);
    final radius = healthDp(context, 10);
    return SizedBox(
      width: size,
      height: size,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(
            color: const Color(0xFFE0E0E0),
            width: healthDp(context, 1.55),
          ),
        ),
        padding: EdgeInsets.all(healthDp(context, 14)),
        child: SvgPicture.asset(
          AppAssets.healthConnectGoogle,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildSyncedSummary() {
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
            '동기화 미리보기',
            style: TextStyle(
              fontSize: 13,
              fontFamily: 'Gmarket Sans TTF',
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '걸음수: ${_syncedSteps?.toString() ?? '-'}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF555555)),
          ),
          Text(
            '심박수: ${_syncedHeartRate != null ? '$_syncedHeartRate bpm' : '-'}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF555555)),
          ),
        ],
      ),
    );
  }
}
